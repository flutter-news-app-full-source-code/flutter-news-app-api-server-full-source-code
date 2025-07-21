import 'dart:async';

import 'package:ht_api/src/config/environment_config.dart';
import 'package:ht_api/src/rbac/permission_service.dart';
import 'package:ht_api/src/rbac/permissions.dart';
import 'package:ht_api/src/services/auth_token_service.dart';
import 'package:ht_api/src/services/verification_code_storage_service.dart';
import 'package:ht_data_repository/ht_data_repository.dart';
import 'package:ht_email_repository/ht_email_repository.dart';
import 'package:ht_shared/ht_shared.dart';
import 'package:logging/logging.dart';
import 'package:mongo_dart/mongo_dart.dart';

/// {@template auth_service}
/// Service responsible for orchestrating authentication logic on the backend.
///
/// It coordinates interactions between user data storage, token generation,
/// verification code management, and email sending.
/// {@endtemplate}
class AuthService {
  /// {@macro auth_service}
  const AuthService({
    required HtDataRepository<User> userRepository,
    required AuthTokenService authTokenService,
    required VerificationCodeStorageService verificationCodeStorageService,
    required HtEmailRepository emailRepository,
    required HtDataRepository<UserAppSettings> userAppSettingsRepository,
    required HtDataRepository<UserContentPreferences>
    userContentPreferencesRepository,
    required PermissionService permissionService,
    required Logger log,
  }) : _userRepository = userRepository,
       _authTokenService = authTokenService,
       _verificationCodeStorageService = verificationCodeStorageService,
       _permissionService = permissionService,
       _emailRepository = emailRepository,
       _userAppSettingsRepository = userAppSettingsRepository,
       _userContentPreferencesRepository = userContentPreferencesRepository,
       _log = log;

  final HtDataRepository<User> _userRepository;
  final AuthTokenService _authTokenService;
  final VerificationCodeStorageService _verificationCodeStorageService;
  final HtEmailRepository _emailRepository;
  final HtDataRepository<UserAppSettings> _userAppSettingsRepository;
  final HtDataRepository<UserContentPreferences>
  _userContentPreferencesRepository;
  final PermissionService _permissionService;
  final Logger _log;

  /// Initiates the email sign-in process.
  ///
  /// This method is context-aware based on the [isDashboardLogin] flag.
  ///
  /// - For the user-facing app (`isDashboardLogin: false`), it generates and
  ///   sends a verification code to the given [email] without pre-validation,
  ///   supporting a unified sign-in/sign-up flow.
  /// - For the dashboard (`isDashboardLogin: true`), it performs a strict
  ///   login-only check. It verifies that a user with the given [email] exists
  ///   and has either the 'admin' or 'publisher' role *before* sending a code.
  ///
  /// - [email]: The email address to send the code to.
  /// - [isDashboardLogin]: A flag to indicate if this is a login attempt from
  ///   the dashboard, which enforces stricter checks.
  ///
  /// Throws [UnauthorizedException] if `isDashboardLogin` is true and the user
  /// does not exist.
  /// Throws [ForbiddenException] if `isDashboardLogin` is true and the user
  /// exists but lacks the required roles.
  Future<void> initiateEmailSignIn(
    String email, {
    bool isDashboardLogin = false,
  }) async {
    try {
      // For dashboard login, first validate the user exists and has permissions.
      if (isDashboardLogin) {
        final user = await _findUserByEmail(email);

        // For dashboard login, the user must exist AND have permission.
        // If either condition fails, throw the appropriate exception.
        if (user == null) {
          _log.warning('Dashboard login failed: User $email not found.');
          throw const UnauthorizedException(
            'This email address is not registered for dashboard access.',
          );
        } else if (!_permissionService.hasPermission(
          user,
          Permissions.dashboardLogin,
        )) {
          _log.warning(
            'Dashboard login failed: User ${user.id} lacks required permission (${Permissions.dashboardLogin}).',
          );
          throw const ForbiddenException(
            'Your account does not have the required permissions to sign in.',
          );
        }

        _log.info('Dashboard user ${user.id} verified successfully.');
      }

      // Generate and store the code for standard sign-in
      final code = await _verificationCodeStorageService
          .generateAndStoreSignInCode(email);

      // Send the code via email
      await _emailRepository.sendOtpEmail(
        senderEmail: EnvironmentConfig.defaultSenderEmail,
        recipientEmail: email,
        templateId: EnvironmentConfig.otpTemplateId,
        otpCode: code,
      );
      _log.info('Initiated email sign-in for $email, code sent.');
    } on HtHttpException {
      // Propagate known exceptions from dependencies or from this method's logic.
      // This ensures that specific errors like ForbiddenException are not
      // masked as a generic server error.
      rethrow;
    } catch (e, s) {
      // Catch unexpected errors during orchestration.
      _log.severe('Error during initiateEmailSignIn for $email: $e', e, s);
      throw const OperationFailedException(
        'Failed to initiate email sign-in process.',
      );
    }
  }

  /// Completes the email sign-in process by verifying the code.
  ///
  /// This method is context-aware and handles multiple scenarios:
  ///
  /// - **Guest Sign-In:** If an authenticated `guestUser` (from
  ///   [authenticatedUser]) performs this action, the service checks if a
  ///   permanent account with the verified [email] already exists.
  ///   - If it exists, the user is signed into that account, the old guest
  ///     token is invalidated, and the temporary guest account is deleted.
  ///   - If it does not exist, the guest account is converted into a new
  ///     permanent `standardUser`, and the old guest token is invalidated.
  ///
  /// - **Dashboard Login:** If [isDashboardLogin] is true, it performs a
  ///   strict login for an existing user with dashboard permissions.
  ///
  /// - **Standard Sign-In/Sign-Up:** If no authenticated user is present, it
  ///   either logs in an existing user with the given [email] or creates a
  ///   new `standardUser`.
  ///
  /// Returns the authenticated [User] and a new authentication token.
  ///
  /// Throws [InvalidInputException] if the code is invalid or expired.
  Future<({User user, String token})> completeEmailSignIn(
    String email,
    String code, {
    required bool isDashboardLogin,
    User? authenticatedUser,
    String? currentToken,
  }) async {
    // 1. Validate the verification code.
    final isValidCode =
        await _verificationCodeStorageService.validateSignInCode(email, code);
    if (!isValidCode) {
      throw const InvalidInputException('Invalid or expired verification code.');
    }

    // After successful validation, clear the code from storage.
    try {
      await _verificationCodeStorageService.clearSignInCode(email);
    } catch (e) {
      _log.warning(
        'Warning: Failed to clear sign-in code for $email after validation: $e',
      );
    }

    // 2. If this is a guest flow, invalidate the old anonymous token.
    // This is a fire-and-forget operation; we don't want to block the
    // login if invalidation fails, but we should log any errors.
    if (authenticatedUser != null &&
        authenticatedUser.appRole == AppUserRole.guestUser &&
        currentToken != null) {
      unawaited(
        _authTokenService.invalidateToken(currentToken).catchError((e, s) {
          _log.warning(
            'Failed to invalidate old anonymous token for user ${authenticatedUser.id}.',
            e,
            s is StackTrace ? s : null,
          );
        }),
      );
    }

    // 3. Check if the sign-in is initiated from an authenticated guest session.
    if (authenticatedUser != null &&
        authenticatedUser.appRole == AppUserRole.guestUser) {
      _log.info(
        'Guest user ${authenticatedUser.id} is attempting to sign in with email $email.',
      );

      // Check if an account with the target email already exists.
      final existingUser = await _findUserByEmail(email);

      if (existingUser != null) {
        // --- Scenario A: Sign-in to an existing account ---
        // The user wants to log into their existing account, abandoning the
        // guest session.
        _log.info(
          'Existing account found for email $email (ID: ${existingUser.id}). '
          'Signing in and abandoning guest session ${authenticatedUser.id}.',
        );

        // Delete the now-orphaned anonymous user account and its data.
        // This is a fire-and-forget operation; we don't want to block the
        // login if cleanup fails, but we should log any errors.
        unawaited(
          deleteAccount(userId: authenticatedUser.id).catchError((e, s) {
            _log.severe(
              'Failed to clean up orphaned anonymous user ${authenticatedUser.id} after sign-in.',
              e,
              s is StackTrace ? s : null,
            );
          }),
        );

        // Generate a new token for the existing permanent user.
        final token = await _authTokenService.generateToken(existingUser);
        _log.info('Generated new token for existing user ${existingUser.id}.');
        return (user: existingUser, token: token);
      } else {
        // --- Scenario B: Convert guest to a new permanent account ---
        // No account exists with this email, so proceed with conversion.
        _log.info(
          'No existing account for $email. Converting guest user ${authenticatedUser.id} to a new permanent account.',
        );
        return _convertGuestUserToPermanent(
          guestUser: authenticatedUser,
          verifiedEmail: email,
        );
      }
    }

    // 4. If not a guest flow, proceed with standard or dashboard login.
    User user;
    try {
      // Attempt to find user by email
      final existingUser = await _findUserByEmail(email);
      if (existingUser != null) {
        user = existingUser;
        // If this is a dashboard login, re-verify the user's dashboard role.
        // This closes the loophole where a non-admin user could request a code
        // via the app flow and then use it to log into the dashboard.
        if (isDashboardLogin) {
          if (!_permissionService.hasPermission(
            user,
            Permissions.dashboardLogin,
          )) {
            _log.warning(
              'Dashboard login failed: User ${user.id} lacks required '
              'permission during code verification.',
            );
            throw const ForbiddenException(
              'Your account does not have the required permissions to sign in.',
            );
          }
          _log.info('Dashboard user ${user.id} re-verified successfully.');
        }
      } else {
        // User not found.
        if (isDashboardLogin) {
          // This should not happen if the request-code flow is correct.
          // It's a safeguard.
          _log.severe(
            'Error: Dashboard login verification failed for non-existent user $email.',
          );
          throw const UnauthorizedException('User account does not exist.');
        }

        // Create a new user for the standard app flow.
        _log.info('User not found for $email, creating new user.');

        // All new users created via the public API get the standard role.
        // Admin users must be provisioned out-of-band (e.g., via fixtures).
        user = User(
          id: ObjectId().oid,
          email: email,
          appRole: AppUserRole.standardUser,
          dashboardRole: DashboardUserRole.none,
          createdAt: DateTime.now(),
          feedActionStatus: Map.fromEntries(
            FeedActionType.values.map(
              (type) => MapEntry(
                type,
                const UserFeedActionStatus(isCompleted: false),
              ),
            ),
          ),
        );
        user = await _userRepository.create(item: user);
        _log.info('Created new user: ${user.id} with appRole: ${user.appRole}');

        // Ensure default documents are created for the new user.
        await _ensureUserDataExists(user);
      }
    } on HtHttpException {
      // Propagate known exceptions from dependencies or from this method's logic.
      // This ensures that specific errors like ForbiddenException are not
      // masked as a generic server error.
      rethrow;
    } catch (e, s) {
      _log.severe(
        'Unexpected error during user lookup/creation for $email: $e',
        e,
        s,
      );
      throw const OperationFailedException('Failed to process user account.');
    }

    // 4. Generate authentication token
    try {
      final token = await _authTokenService.generateToken(user);
      _log.info('Generated token for user ${user.id}');
      return (user: user, token: token);
    } catch (e) {
      _log.severe('Error generating token for user ${user.id}: $e');
      throw const OperationFailedException(
        'Failed to generate authentication token.',
      );
    }
  }

  /// Performs anonymous sign-in.
  ///
  /// Creates a new anonymous user record and generates an auth token.
  /// Returns the anonymous User and the generated token.
  /// Throws [OperationFailedException] if user creation or token generation fails.
  Future<({User user, String token})> performAnonymousSignIn() async {
    // 1. Create anonymous user
    User user;
    try {
      final newId = ObjectId().oid;
      user = User(
        id: newId,
        // Use a unique placeholder email for anonymous users to satisfy the
        // non-nullable email constraint.
        email: '$newId@anonymous.com',
        appRole: AppUserRole.guestUser,
        dashboardRole: DashboardUserRole.none,
        createdAt: DateTime.now(),
        feedActionStatus: Map.fromEntries(
          FeedActionType.values.map(
            (type) =>
                MapEntry(type, const UserFeedActionStatus(isCompleted: false)),
          ),
        ),
      );
      user = await _userRepository.create(item: user);
      _log.info('Created anonymous user: ${user.id}');

      // Ensure default documents are created for the new anonymous user.
      await _ensureUserDataExists(user);
    } on HtHttpException catch (e) {
      _log.severe('Error creating anonymous user: $e');
      throw const OperationFailedException('Failed to create anonymous user.');
    } catch (e) {
      _log.severe('Unexpected error during anonymous user creation: $e');
      throw const OperationFailedException(
        'Failed to process anonymous sign-in.',
      );
    }

    // 2. Generate token
    try {
      final token = await _authTokenService.generateToken(user);
      _log.info('Generated token for anonymous user ${user.id}');
      return (user: user, token: token);
    } catch (e) {
      _log.severe('Error generating token for anonymous user ${user.id}: $e');
      throw const OperationFailedException(
        'Failed to generate authentication token.',
      );
    }
  }

  /// Performs server-side sign-out actions.
  ///
  /// Currently, this method logs the sign-out attempt. True server-side
  /// token invalidation (e.g., blacklisting a JWT) is not implemented
  /// in the underlying [AuthTokenService] and would require adding that
  /// capability (e.g., an `invalidateToken` method and a blacklist store).
  ///
  /// The primary client-side action (clearing the local token) is handled
  /// separately by the client application.
  ///
  /// Performs server-side sign-out actions, including token invalidation.
  ///
  /// Invalidates the provided authentication [token] using the
  /// [AuthTokenService].
  ///
  /// The primary client-side action (clearing the local token) is handled
  /// separately by the client application.
  ///
  /// Throws [OperationFailedException] if token invalidation fails.
  Future<void> performSignOut({
    required String userId,
    required String token,
  }) async {
    _log.info(
      'Received request for server-side sign-out actions '
      'for user $userId.',
    );

    try {
      // Invalidate the token using the AuthTokenService
      await _authTokenService.invalidateToken(token);
      _log.info('Token invalidation logic executed for user $userId.');
    } on HtHttpException catch (_) {
      // Propagate known exceptions from the token service
      rethrow;
    } catch (e) {
      // Catch unexpected errors during token invalidation
      _log.severe('Error during token invalidation for user $userId: $e');
      throw const OperationFailedException(
        'Failed server-side sign-out: Token invalidation failed.',
      );
    }

    _log.info('Server-side sign-out actions complete for user $userId.');
  }

  /// Initiates the process of linking an [emailToLink] to an existing
  /// authenticated [anonymousUser]'s account.
  ///

  /// Deletes a user account and associated authentication data.
  ///
  /// This includes deleting the user record from the repository and clearing
  /// any pending verification codes.
  ///
  /// Throws [NotFoundException] if the user does not exist.
  /// Throws [OperationFailedException] for other errors during deletion or cleanup.
  Future<void> deleteAccount({required String userId}) async {
    try {
      // Fetch the user first to get their email if needed for cleanup
      final userToDelete = await _userRepository.read(id: userId);
      _log.info('Found user ${userToDelete.id} for deletion.');

      // 1. Explicitly delete associated user data. Unlike relational databases
      // with CASCADE constraints, MongoDB requires manual deletion of related
      // documents in different collections.
      await _userAppSettingsRepository.delete(id: userId, userId: userId);
      _log.info('Deleted UserAppSettings for user ${userToDelete.id}.');

      await _userContentPreferencesRepository.delete(
        id: userId,
        userId: userId,
      );
      _log.info('Deleted UserContentPreferences for user ${userToDelete.id}.');

      // 2. Delete the main user record. This also implicitly invalidates
      // tokens that rely on user lookup, as the user will no longer exist.
      await _userRepository.delete(id: userId);
      _log.info('User ${userToDelete.id} deleted from repository.');

      // 3. Clear any pending sign-in codes for the user's email.
      try {
        await _verificationCodeStorageService.clearSignInCode(
          userToDelete.email,
        );
        _log.info('Cleared sign-in code for email ${userToDelete.email}.');
      } catch (e) {
        _log.warning(
          'Warning: Failed to clear sign-in code for email ${userToDelete.email}: $e',
        );
      }

      _log.info('Account deletion process completed for user $userId.');
    } on NotFoundException {
      // Propagate NotFoundException if user doesn't exist
      rethrow;
    } on HtHttpException catch (_) {
      // Propagate other known exceptions from dependencies
      rethrow;
    } catch (e) {
      // Catch unexpected errors during orchestration
      _log.severe('Error during deleteAccount for user $userId: $e');
      throw OperationFailedException('Failed to delete user account: $e');
    }
  }

  /// Finds a user by their email address.
  ///
  /// Returns the [User] if found, otherwise `null`.
  /// Re-throws any [HtHttpException] from the repository.
  Future<User?> _findUserByEmail(String email) async {
    try {
      final response = await _userRepository.readAll(filter: {'email': email});
      if (response.items.isNotEmpty) {
        return response.items.first;
      }
      return null;
    } on HtHttpException {
      rethrow;
    }
  }

  /// Ensures that the essential user-specific documents (settings, preferences)
  /// exist for a given user, creating them with default values if they are missing.
  ///
  /// This method is crucial for maintaining data integrity, especially for users
  /// who might have been created before these documents were part of the standard
  /// user creation process.
  Future<void> _ensureUserDataExists(User user) async {
    // Check for UserAppSettings
    try {
      await _userAppSettingsRepository.read(id: user.id, userId: user.id);
    } on NotFoundException {
      _log.info(
        'UserAppSettings not found for user ${user.id}. Creating with defaults.',
      );
      final defaultAppSettings = UserAppSettings(
        id: user.id,
        displaySettings: const DisplaySettings(
          baseTheme: AppBaseTheme.system,
          accentTheme: AppAccentTheme.defaultBlue,
          fontFamily: 'SystemDefault',
          textScaleFactor: AppTextScaleFactor.medium,
          fontWeight: AppFontWeight.regular,
        ),
        language: 'en',
        feedPreferences: const FeedDisplayPreferences(
          headlineDensity: HeadlineDensity.standard,
          headlineImageStyle: HeadlineImageStyle.largeThumbnail,
          showSourceInHeadlineFeed: true,
          showPublishDateInHeadlineFeed: true,
        ),
      );
      await _userAppSettingsRepository.create(
        item: defaultAppSettings,
        userId: user.id,
      );
    }

    // Check for UserContentPreferences
    try {
      await _userContentPreferencesRepository.read(
        id: user.id,
        userId: user.id,
      );
    } on NotFoundException {
      _log.info(
        'UserContentPreferences not found for user ${user.id}. Creating with defaults.',
      );
      final defaultUserPreferences = UserContentPreferences(
        id: user.id,
        followedCountries: const [],
        followedSources: const [],
        followedTopics: const [],
        savedHeadlines: const [],
      );
      await _userContentPreferencesRepository.create(
        item: defaultUserPreferences,
        userId: user.id,
      );
    }
  }

  /// Converts a guest user to a new permanent standard user.
  ///
  /// This helper method encapsulates the logic for updating the user's
  /// record with a verified email and upgrading their role. It assumes that
  /// the target email is not already in use by another account.
  Future<({User user, String token})> _convertGuestUserToPermanent({
    required User guestUser,
    required String verifiedEmail,
  }) async {
    // The check for an existing user with the verifiedEmail is now handled
    // by the calling method, `completeEmailSignIn`. This method now only
    // handles the conversion itself.

    // 1. Update the guest user's details to make them permanent.
    final updatedUser = guestUser.copyWith(
      email: verifiedEmail,
      appRole: AppUserRole.standardUser,
    );

    final permanentUser = await _userRepository.update(
      id: updatedUser.id,
      item: updatedUser,
    );
    _log.info(
      'User ${permanentUser.id} successfully converted to permanent account with email $verifiedEmail.',
    );

    // 2. Generate a new token for the now-permanent user.
    final newToken = await _authTokenService.generateToken(permanentUser);
    _log.info('Generated new token for converted user ${permanentUser.id}');

    // Note: Invalidation of the old anonymous token is handled implicitly.
    // The client will receive the new token and stop using the old one.
    // The old token will eventually expire. For immediate invalidation,
    // the old token would need to be passed into this flow and blacklisted.

    return (user: permanentUser, token: newToken);
  }
}
