import 'package:ht_api/src/services/auth_token_service.dart';
import 'package:ht_api/src/services/verification_code_storage_service.dart';
import 'package:ht_data_repository/ht_data_repository.dart';
import 'package:ht_email_repository/ht_email_repository.dart';
import 'package:ht_shared/ht_shared.dart';
import 'package:uuid/uuid.dart';

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
    required Uuid uuidGenerator,
  }) : _userRepository = userRepository,
       _authTokenService = authTokenService,
       _verificationCodeStorageService = verificationCodeStorageService,
       _emailRepository = emailRepository,
       _userAppSettingsRepository = userAppSettingsRepository,
       _userContentPreferencesRepository = userContentPreferencesRepository,
       _uuid = uuidGenerator;

  final HtDataRepository<User> _userRepository;
  final AuthTokenService _authTokenService;
  final VerificationCodeStorageService _verificationCodeStorageService;
  final HtEmailRepository _emailRepository;
  final HtDataRepository<UserAppSettings> _userAppSettingsRepository;
  final HtDataRepository<UserContentPreferences>
  _userContentPreferencesRepository;
  final Uuid _uuid;

  /// Initiates the email sign-in process.
  ///
  /// Generates a verification code, stores it, and sends it via email.
  /// Throws [InvalidInputException] for invalid email format (via email client).
  /// Throws [OperationFailedException] if code generation/storage/email fails.
  Future<void> initiateEmailSignIn(String email) async {
    try {
      // Generate and store the code for standard sign-in
      final code = await _verificationCodeStorageService
          .generateAndStoreSignInCode(email);

      // Send the code via email
      await _emailRepository.sendOtpEmail(recipientEmail: email, otpCode: code);
      print('Initiated email sign-in for $email, code sent.');
    } on HtHttpException {
      // Propagate known exceptions from dependencies
      rethrow;
    } catch (e) {
      // Catch unexpected errors during orchestration
      print('Error during initiateEmailSignIn for $email: $e');
      throw const OperationFailedException(
        'Failed to initiate email sign-in process.',
      );
    }
  }

  /// Completes the email sign-in process by verifying the code.
  ///
  /// If the code is valid, finds or creates the user, generates an auth token.
  /// Returns the authenticated User and the generated token.
  /// Throws [InvalidInputException] if the code is invalid or expired.
  /// Throws [AuthenticationException] for specific code mismatch.
  /// Throws [OperationFailedException] for user lookup/creation or token errors.
  Future<({User user, String token})> completeEmailSignIn(
    String email,
    String code,
    // User? currentAuthUser, // Parameter for potential future linking logic
  ) async {
    // 1. Validate the code for standard sign-in
    final isValidCode = await _verificationCodeStorageService
        .validateSignInCode(email, code);
    if (!isValidCode) {
      throw const InvalidInputException(
        'Invalid or expired verification code.',
      );
    }

    // After successful code validation, clear the sign-in code
    try {
      await _verificationCodeStorageService.clearSignInCode(email);
    } catch (e) {
      // Log or handle if clearing fails, but don't let it block sign-in
      print(
        'Warning: Failed to clear sign-in code for $email after validation: $e',
      );
    }

    // 2. Find or create the user
    User user;
    try {
      // Attempt to find user by email (assuming a query method exists)
      // NOTE: HtDataRepository<User> currently lacks findByEmail.
      // We'll simulate this by querying all and filtering for now.
      // Replace with a proper query when available.
      final query = {'email': email}; // Hypothetical query
      final paginatedResponse = await _userRepository.readAllByQuery(query);

      if (paginatedResponse.items.isNotEmpty) {
        user = paginatedResponse.items.first;
        print('Found existing user: ${user.id} for email $email');
      } else {
        // User not found, create a new one
        print('User not found for $email, creating new user.');
        user = User(
          id: _uuid.v4(), // Generate new ID
          email: email,
          role: UserRole.standardUser, // Email verified user is standard user
        );
        user = await _userRepository.create(item: user); // Save the new user
        print('Created new user: ${user.id}');

        // Create default UserAppSettings for the new user
        final defaultAppSettings = UserAppSettings(id: user.id);
        await _userAppSettingsRepository.create(
          item: defaultAppSettings,
          userId: user.id, // Pass user ID for scoping
        );
        print('Created default UserAppSettings for user: ${user.id}');

        // Create default UserContentPreferences for the new user
        final defaultUserPreferences = UserContentPreferences(id: user.id);
        await _userContentPreferencesRepository.create(
          item: defaultUserPreferences,
          userId: user.id, // Pass user ID for scoping
        );
        print('Created default UserContentPreferences for user: ${user.id}');
      }
    } on HtHttpException catch (e) {
      print('Error finding/creating user for $email: $e');
      throw const OperationFailedException(
        'Failed to find or create user account.',
      );
    } catch (e) {
      print('Unexpected error during user lookup/creation for $email: $e');
      throw const OperationFailedException('Failed to process user account.');
    }

    // 3. Generate authentication token
    try {
      final token = await _authTokenService.generateToken(user);
      print('Generated token for user ${user.id}');
      return (user: user, token: token);
    } catch (e) {
      print('Error generating token for user ${user.id}: $e');
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
      user = User(
        id: _uuid.v4(), // Generate new ID
        role: UserRole.guestUser, // Anonymous users are guest users
        email: null, // Anonymous users don't have an email initially
      );
      user = await _userRepository.create(item: user);
      print('Created anonymous user: ${user.id}');
    } on HtHttpException catch (e) {
      print('Error creating anonymous user: $e');
      throw const OperationFailedException('Failed to create anonymous user.');
    } catch (e) {
      print('Unexpected error during anonymous user creation: $e');
      throw const OperationFailedException(
        'Failed to process anonymous sign-in.',
      );
    }

    // Create default UserAppSettings for the new anonymous user
    final defaultAppSettings = UserAppSettings(id: user.id);
    await _userAppSettingsRepository.create(
      item: defaultAppSettings,
      userId: user.id, // Pass user ID for scoping
    );
    print('Created default UserAppSettings for anonymous user: ${user.id}');

    // Create default UserContentPreferences for the new anonymous user
    final defaultUserPreferences = UserContentPreferences(id: user.id);
    await _userContentPreferencesRepository.create(
      item: defaultUserPreferences,
      userId: user.id, // Pass user ID for scoping
    );
    print(
      'Created default UserContentPreferences for anonymous user: ${user.id}',
    );

    // 2. Generate token
    try {
      final token = await _authTokenService.generateToken(user);
      print('Generated token for anonymous user ${user.id}');
      return (user: user, token: token);
    } catch (e) {
      print('Error generating token for anonymous user ${user.id}: $e');
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
    print(
      '[AuthService] Received request for server-side sign-out actions '
      'for user $userId.',
    );

    try {
      // Invalidate the token using the AuthTokenService
      await _authTokenService.invalidateToken(token);
      print(
        '[AuthService] Token invalidation logic executed for user $userId.',
      );
    } on HtHttpException catch (_) {
      // Propagate known exceptions from the token service
      rethrow;
    } catch (e) {
      // Catch unexpected errors during token invalidation
      print(
        '[AuthService] Error during token invalidation for user $userId: $e',
      );
      throw const OperationFailedException(
        'Failed server-side sign-out: Token invalidation failed.',
      );
    }

    print(
      '[AuthService] Server-side sign-out actions complete for user $userId.',
    );
  }

  /// Initiates the process of linking an [emailToLink] to an existing
  /// authenticated [anonymousUser]'s account.
  ///
  /// Throws [ConflictException] if the [emailToLink] is already in use by
  /// another permanent account, or if the [anonymousUser] is not actually
  /// anonymous, or if the [emailToLink] is already pending verification for
  /// another linking process.
  /// Throws [OperationFailedException] for other errors.
  Future<void> initiateLinkEmailProcess({
    required User anonymousUser,
    required String emailToLink,
  }) async {
    if (anonymousUser.role != UserRole.guestUser) {
      throw const BadRequestException(
        'Account is already permanent. Cannot link email.',
      );
    }

    try {
      // 1. Check if emailToLink is already used by another *permanent* user.
      final query = {'email': emailToLink, 'isAnonymous': false};
      final existingUsers = await _userRepository.readAllByQuery(query);
      if (existingUsers.items.isNotEmpty) {
        // Ensure it's not the same user if somehow an anonymous user had an email
        // (though current logic prevents this for new anonymous users).
        // This check is more for emails used by *other* permanent accounts.
        if (existingUsers.items.any((u) => u.id != anonymousUser.id)) {
          throw ConflictException(
            'Email address "$emailToLink" is already in use by another account.',
          );
        }
      }

      // 2. Generate and store the link code.
      // The storage service itself might throw ConflictException if emailToLink
      // is pending for another user or if this user has a pending code.
      final code = await _verificationCodeStorageService
          .generateAndStoreLinkCode(
            userId: anonymousUser.id,
            emailToLink: emailToLink,
          );

      // 3. Send the code via email
      await _emailRepository.sendOtpEmail(
        recipientEmail: emailToLink,
        otpCode: code,
      );
      print(
        'Initiated email link for user ${anonymousUser.id} to email $emailToLink, code sent: $code .',
      );
    } on HtHttpException {
      rethrow;
    } catch (e) {
      print(
        'Error during initiateLinkEmailProcess for user ${anonymousUser.id}, email $emailToLink: $e',
      );
      throw OperationFailedException(
        'Failed to initiate email linking process: $e',
      );
    }
  }

  /// Completes the email linking process for an [anonymousUser] by verifying
  /// the [codeFromUser].
  ///
  /// If successful, updates the user to be permanent with the linked email
  /// and returns the updated User and a new authentication token.
  /// Throws [InvalidInputException] if the code is invalid or expired.
  /// Throws [OperationFailedException] for other errors.
  Future<({User user, String token})> completeLinkEmailProcess({
    required User anonymousUser,
    required String codeFromUser,
    required String oldAnonymousToken, // Needed to invalidate it
  }) async {
    if (anonymousUser.role != UserRole.guestUser) {
      // Should ideally not happen if flow is correct, but good safeguard.
      throw const BadRequestException(
        'Account is already permanent. Cannot complete email linking.',
      );
    }

    try {
      // 1. Validate the link code and retrieve the email that was being linked.
      final linkedEmail = await _verificationCodeStorageService
          .validateAndRetrieveLinkedEmail(
            userId: anonymousUser.id,
            linkCode: codeFromUser,
          );

      if (linkedEmail == null) {
        throw const InvalidInputException(
          'Invalid or expired verification code for email linking.',
        );
      }

      // 2. Update the user to be permanent.
      final updatedUser = User(
        id: anonymousUser.id, // Preserve original ID
        email: linkedEmail,
        role: UserRole.standardUser, // Now a permanent standard user
      );
      final permanentUser = await _userRepository.update(
        id: updatedUser.id,
        item: updatedUser,
      );
      print(
        'User ${permanentUser.id} successfully linked with email $linkedEmail.',
      );

      // 3. Generate a new authentication token for the now-permanent user.
      final newToken = await _authTokenService.generateToken(permanentUser);
      print('Generated new token for linked user ${permanentUser.id}');

      // 4. Invalidate the old anonymous token.
      try {
        await _authTokenService.invalidateToken(oldAnonymousToken);
        print(
          'Successfully invalidated old anonymous token for user ${permanentUser.id}.',
        );
      } catch (e) {
        // Log error but don't fail the whole linking process if invalidation fails.
        // The new token is more important.
        print(
          'Warning: Failed to invalidate old anonymous token for user ${permanentUser.id}: $e',
        );
      }

      // 5. Clear the link code from storage.
      try {
        await _verificationCodeStorageService.clearLinkCode(anonymousUser.id);
      } catch (e) {
        print(
          'Warning: Failed to clear link code for user ${anonymousUser.id} after linking: $e',
        );
      }

      return (user: permanentUser, token: newToken);
    } on HtHttpException {
      rethrow;
    } catch (e) {
      print(
        'Error during completeLinkEmailProcess for user ${anonymousUser.id}: $e',
      );
      throw OperationFailedException(
        'Failed to complete email linking process: $e',
      );
    }
  }

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
      print('[AuthService] Found user ${userToDelete.id} for deletion.');

      // 1. Delete the user record from the repository.
      // This implicitly invalidates tokens that rely on user lookup.
      await _userRepository.delete(id: userId);
      print('[AuthService] User ${userToDelete.id} deleted from repository.');

      // 2. Clear any pending verification codes for this user ID (linking).
      try {
        await _verificationCodeStorageService.clearLinkCode(userId);
        print('[AuthService] Cleared link code for user ${userToDelete.id}.');
      } catch (e) {
        // Log but don't fail deletion if clearing codes fails
        print(
          '[AuthService] Warning: Failed to clear link code for user ${userToDelete.id}: $e',
        );
      }

      // 3. Clear any pending sign-in codes for the user's email (if they had one).
      if (userToDelete.email != null) {
        try {
          await _verificationCodeStorageService.clearSignInCode(
            userToDelete.email!,
          );
          print(
            '[AuthService] Cleared sign-in code for email ${userToDelete.email}.',
          );
        } catch (e) {
          // Log but don't fail deletion if clearing codes fails
          print(
            '[AuthService] Warning: Failed to clear sign-in code for email ${userToDelete.email}: $e',
          );
        }
      }

      // TODO(fulleni): Add logic here to delete or anonymize other
      // user-related data (e.g., settings, content) from other repositories
      // once those features are implemented.

      print(
        '[AuthService] Account deletion process completed for user $userId.',
      );
    } on NotFoundException {
      // Propagate NotFoundException if user doesn't exist
      rethrow;
    } on HtHttpException catch (_) {
      // Propagate other known exceptions from dependencies
      rethrow;
    } catch (e) {
      // Catch unexpected errors during orchestration
      print('Error during deleteAccount for user $userId: $e');
      throw OperationFailedException('Failed to delete user account: $e');
    }
  }
}
