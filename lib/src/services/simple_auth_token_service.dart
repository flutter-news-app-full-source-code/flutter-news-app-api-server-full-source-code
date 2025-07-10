import 'package:ht_api/src/services/auth_token_service.dart';
import 'package:ht_data_repository/ht_data_repository.dart';
import 'package:ht_shared/ht_shared.dart';
import 'package:logging/logging.dart';

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
    required Logger log,
  }) : _userRepository = userRepository,
       _log = log;

  final HtDataRepository<User> _userRepository;
  final Logger _log;
  static const String _tokenPrefix = 'valid-token-for-user-id:';

  @override
  Future<String> generateToken(User user) async {
    _log.info('Generating token for user ${user.id}');
    final token = '$_tokenPrefix${user.id}';
    _log.finer('Generated token: $token');
    // Simulate async operation if needed, though not strictly necessary here
    await Future<void>.delayed(Duration.zero);
    return token;
  }

  @override
  Future<User?> validateToken(String token) async {
    _log.finer('Attempting to validate token: $token');
    if (!token.startsWith(_tokenPrefix)) {
      _log.warning('Validation failed: Invalid prefix.');
      // Mimic JWT behavior by throwing Unauthorized for invalid format
      throw const UnauthorizedException('Invalid token format.');
    }

    final userId = token.substring(_tokenPrefix.length);
    _log.finer('Extracted user ID: $userId');

    if (userId.isEmpty) {
      _log.warning('Validation failed: Empty user ID.');
      throw const UnauthorizedException('Invalid token: Empty user ID.');
    }

    try {
      _log.finer('Attempting to read user from repository...');
      final user = await _userRepository.read(id: userId);
      _log.info('User read successful: ${user.id}');
      return user;
    } on NotFoundException {
      _log.warning('Validation failed: User ID $userId not found.');
      // Return null if user not found, mimicking successful validation
      // of a token for a non-existent user. The middleware handles this.
      return null;
    } on HtHttpException catch (e, s) {
      // Handle other potential repository errors
      _log.warning('Validation failed: Repository error', e, s);
      // Re-throw other client/repo exceptions
      rethrow;
    } catch (e, s) {
      // Catch unexpected errors during validation
      _log.severe('Unexpected validation error', e, s);
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
    _log.info(
      'Received request to invalidate token: $token. '
      'No server-side invalidation is performed for simple tokens.',
    );
    // Simulate async operation
    await Future<void>.delayed(Duration.zero);
    // No specific exceptions thrown here.
  }
}
