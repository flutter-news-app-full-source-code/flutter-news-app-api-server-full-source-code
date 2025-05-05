import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:ht_api/src/services/auth_token_service.dart';
import 'package:ht_data_repository/ht_data_repository.dart';
import 'package:ht_shared/ht_shared.dart';
import 'package:uuid/uuid.dart';

/// {@template jwt_auth_token_service}
/// An implementation of [AuthTokenService] using JSON Web Tokens (JWT).
///
/// Handles the creation (signing) and validation (verification) of JWTs
/// for user authentication.
/// {@endtemplate}
class JwtAuthTokenService implements AuthTokenService {
  /// {@macro jwt_auth_token_service}
  ///
  /// Requires an [HtDataRepository<User>] to fetch user details after
  /// validating the token's subject claim.
  /// Also requires a [Uuid] generator for creating unique JWT IDs (jti).
  const JwtAuthTokenService({
    required HtDataRepository<User> userRepository,
    required Uuid uuidGenerator,
  })  : _userRepository = userRepository,
        _uuid = uuidGenerator;

  final HtDataRepository<User> _userRepository;
  final Uuid _uuid;

  // --- Configuration ---

  // WARNING: Hardcoding secrets is insecure. Use environment variables
  // or a proper secrets management solution in production.
  static const String _secretKey =
      'your-very-hardcoded-super-secret-key-replace-this-in-prod';

  // Define token issuer and default expiry duration
  static const String _issuer = 'http://localhost:8080';
  static const Duration _tokenExpiryDuration = Duration(hours: 1);

  // --- Interface Implementation ---

  @override
  Future<String> generateToken(User user) async {
    try {
      final now = DateTime.now();
      final expiry = now.add(_tokenExpiryDuration);

      final jwt = JWT(
        {
          // Standard claims
          'sub': user.id, // Subject (user ID) - REQUIRED
          'exp': expiry.millisecondsSinceEpoch ~/ 1000, // Expiration Time
          'iat': now.millisecondsSinceEpoch ~/ 1000, // Issued At
          'iss': _issuer, // Issuer
          'jti': _uuid.v4(), // JWT ID (for potential blacklisting)

          // Custom claims (optional, include what's useful)
          'email': user.email,
          'isAnonymous': user.isAnonymous,
        },
        issuer: _issuer,
        subject: user.id,
        jwtId: _uuid.v4(), // Re-setting jti here for clarity if needed
      );

      // Sign the token using HMAC-SHA256
      final token = jwt.sign(
        SecretKey(_secretKey),
        algorithm: JWTAlgorithm.HS256,
        expiresIn: _tokenExpiryDuration, // Redundant but safe
      );

      print('Generated JWT for user ${user.id}');
      return token;
    } catch (e) {
      print('Error generating JWT for user ${user.id}: $e');
      // Map to a standard exception
      throw OperationFailedException(
        'Failed to generate authentication token: $e',
      );
    }
  }

  @override
  Future<User?> validateToken(String token) async {
    try {
      // Verify the token's signature and expiry
      final jwt = JWT.verify(token, SecretKey(_secretKey));

      // Extract user ID from the subject claim
      final userId = jwt.payload['sub'] as String?;
      if (userId == null) {
        print('Token validation failed: Missing "sub" claim.');
        // Throw specific exception for malformed token
        throw const BadRequestException(
          'Malformed token: Missing subject claim.',
        );
      }

      // Fetch the full user object from the repository
      // This ensures the user still exists and is valid
      final user = await _userRepository.read(userId);
      print('Token validated successfully for user ${user.id}');
      return user;
    } on JWTExpiredException {
      print('Token validation failed: Token expired.');
      // Throw specific exception for expired token
      throw const UnauthorizedException('Token expired.');
    } on JWTInvalidException catch (e) {
      print('Token validation failed: Invalid token. Reason: ${e.message}');
      // Throw specific exception for invalid token signature/format
      throw UnauthorizedException('Invalid token: ${e.message}');
    } on JWTException catch (e) {
      // Use JWTException as the general catch-all
      print('Token validation failed: JWT Exception. Reason: ${e.message}');
      // Treat other JWT exceptions as invalid tokens
      throw UnauthorizedException('Invalid token: ${e.message}');
    } on HtHttpException catch (e) {
      // Handle errors from the user repository (e.g., user not found)
      print('Token validation failed: Error fetching user $e');
      // Re-throw repository exceptions directly for the error handler
      rethrow;
    } catch (e) {
      // Catch unexpected errors during validation
      print('Unexpected error during token validation: $e');
      // Wrap unexpected errors in a standard exception type
      throw OperationFailedException(
        'Token validation failed unexpectedly: $e',
      );
    }
  }
}
