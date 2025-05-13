import 'package:ht_api/src/services/auth_token_service.dart';
import 'package:ht_data_repository/ht_data_repository.dart';
import 'package:ht_shared/ht_shared.dart';

/// {@template simple_auth_token_service}
/// A minimal, dependency-free implementation of [AuthTokenService] for debugging.
///
/// Generates simple, predictable tokens and validates them by checking a prefix
/// and fetching the user from the repository. Does not involve JWT logic.
/// {@endtemplate}
class SimpleAuthTokenService implements AuthTokenService {
  /// {@macro simple_auth_token_service}
  const SimpleAuthTokenService({
    required HtDataRepository<User> userRepository,
  }) : _userRepository = userRepository;

  final HtDataRepository<User> _userRepository;
  static const String _tokenPrefix = 'valid-token-for-user-id:';

  @override
  Future<String> generateToken(User user) async {
    print('[SimpleAuthTokenService] Generating token for user ${user.id}');
    final token = '$_tokenPrefix${user.id}';
    print('[SimpleAuthTokenService] Generated token: $token');
    // Simulate async operation if needed, though not strictly necessary here
    await Future<void>.delayed(Duration.zero);
    return token;
  }

  @override
  Future<User?> validateToken(String token) async {
    print('[SimpleAuthTokenService] Attempting to validate token: $token');
    if (!token.startsWith(_tokenPrefix)) {
      print('[SimpleAuthTokenService] Validation failed: Invalid prefix.');
      // Mimic JWT behavior by throwing Unauthorized for invalid format
      throw const UnauthorizedException('Invalid token format.');
    }

    final userId = token.substring(_tokenPrefix.length);
    print('[SimpleAuthTokenService] Extracted user ID: $userId');

    if (userId.isEmpty) {
      print('[SimpleAuthTokenService] Validation failed: Empty user ID.');
      throw const UnauthorizedException('Invalid token: Empty user ID.');
    }

    try {
      print(
        '[SimpleAuthTokenService] Attempting to read user from repository...',
      );
      final user = await _userRepository.read(id: userId);
      print('[SimpleAuthTokenService] User read successful: ${user.id}');
      return user;
    } on NotFoundException {
      print(
        '[SimpleAuthTokenService] Validation failed: User ID $userId not found.',
      );
      // Return null if user not found, mimicking successful validation
      // of a token for a non-existent user. The middleware handles this.
      return null;
    } on HtHttpException catch (e, s) {
      // Handle other potential repository errors
      print(
        '[SimpleAuthTokenService] Validation failed: Repository error $e\n$s',
      );
      // Re-throw other client/repo exceptions
      rethrow;
    } catch (e, s) {
      // Catch unexpected errors during validation
      print('[SimpleAuthTokenService] Unexpected validation error: $e\n$s');
      throw OperationFailedException(
        'Simple token validation failed unexpectedly: $e',
      );
    }
  }

  @override
  Future<void> invalidateToken(String token) async {
    // This service uses simple prefixed tokens, not JWTs with JTI.
    // True invalidation/blacklisting isn't applicable here.
    // This method is implemented to satisfy the AuthTokenService interface.
    print(
      '[SimpleAuthTokenService] Received request to invalidate token: $token. '
      'No server-side invalidation is performed for simple tokens.',
    );
    // Simulate async operation
    await Future<void>.delayed(Duration.zero);
    // No specific exceptions thrown here.
  }
}
