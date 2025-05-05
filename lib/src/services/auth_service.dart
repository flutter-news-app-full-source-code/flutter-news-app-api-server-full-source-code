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
    required Uuid uuidGenerator,
  })  : _userRepository = userRepository,
        _authTokenService = authTokenService,
        _verificationCodeStorageService = verificationCodeStorageService,
        _emailRepository = emailRepository,
        _uuid = uuidGenerator;

  final HtDataRepository<User> _userRepository;
  final AuthTokenService _authTokenService;
  final VerificationCodeStorageService _verificationCodeStorageService;
  final HtEmailRepository _emailRepository;
  final Uuid _uuid;

  /// Initiates the email sign-in process.
  ///
  /// Generates a verification code, stores it, and sends it via email.
  /// Throws [InvalidInputException] for invalid email format (via email client).
  /// Throws [OperationFailedException] if code generation/storage/email fails.
  Future<void> initiateEmailSignIn(String email) async {
    try {
      // Generate and store the code
      final code = await _verificationCodeStorageService.generateAndStoreCode(
        email,
      );

      // Send the code via email
      await _emailRepository.sendOtpEmail(
        recipientEmail: email,
        otpCode: code,
      );
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
  ) async {
    // 1. Validate the code
    final isValidCode = await _verificationCodeStorageService.validateCode(
      email,
      code,
    );
    if (!isValidCode) {
      // Consider distinguishing between expired and simply incorrect codes
      // For now, treat both as invalid input.
      throw const InvalidInputException(
        'Invalid or expired verification code.',
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
          isAnonymous: false, // Email verified user is not anonymous
        );
        user = await _userRepository.create(user); // Save the new user
        print('Created new user: ${user.id}');
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
        isAnonymous: true,
        email: null, // Anonymous users don't have an email initially
      );
      user = await _userRepository.create(user);
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

  /// Performs sign-out actions (currently placeholder).
  ///
  /// In a real implementation, this might involve invalidating the token
  /// on the server-side (e.g., adding to a blacklist if using JWTs).
  /// The primary sign-out action (clearing local token) happens client-side.
  Future<void> performSignOut({required String userId}) async {
    // Placeholder: Server-side token invalidation logic would go here.
    // For the current SimpleAuthTokenService, there's nothing server-side
    // to invalidate easily. A real JWT implementation might use a blacklist.
    print('Performing server-side sign-out actions for user $userId (if any).');
    await Future<void>.delayed(Duration.zero); // Simulate async
    // No exceptions thrown here unless invalidation fails.
  }
}
