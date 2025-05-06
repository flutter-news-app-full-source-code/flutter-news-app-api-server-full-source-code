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
    print('[validateToken] Attempting to validate token...');
    try {
      // Verify the token's signature and expiry
      print('[validateToken] Verifying token signature and expiry...');
      final jwt = JWT.verify(token, SecretKey(_secretKey));
      print('[validateToken] Token verified. Payload: ${jwt.payload}');

      // Extract user ID from the subject claim
      final subClaim = jwt.payload['sub'];
      print(
        '[validateToken] Extracted "sub" claim: $subClaim '
        '(Type: ${subClaim.runtimeType})',
      );

      // Safely attempt to cast to String
      String? userId;
      if (subClaim is String) {
        userId = subClaim;
        print('[validateToken] "sub" claim successfully cast to String: $userId');
      } else if (subClaim != null) {
        print(
          '[validateToken] WARNING: "sub" claim is not a String. '
          'Attempting toString().',
        );
        // Handle potential non-string types if necessary, or throw error
        // For now, let's treat non-string sub as an error
        throw BadRequestException(
          'Malformed token: "sub" claim is not a String '
          '(Type: ${subClaim.runtimeType}).',
        );
      }

      if (userId == null || userId.isEmpty) {
        print('[validateToken] Token validation failed: Missing or empty "sub" claim.');
        // Throw specific exception for malformed token
        throw const BadRequestException(
          'Malformed token: Missing or empty subject claim.',
        );
      }

      print('[validateToken] Attempting to fetch user with ID: $userId');
      // Fetch the full user object from the repository
      // This ensures the user still exists and is valid
      final user = await _userRepository.read(userId);
      print('[validateToken] User repository read successful for ID: $userId');
      print('[validateToken] Token validated successfully for user ${user.id}');
      return user;
    } on JWTExpiredException catch (e, s) {
      print('[validateToken] CATCH JWTExpiredException: Token expired. $e\n$s');
      // Throw specific exception for expired token
      throw const UnauthorizedException('Token expired.');
    } on JWTInvalidException catch (e, s) {
      print(
        '[validateToken] CATCH JWTInvalidException: Invalid token. '
        'Reason: ${e.message}\n$s',
      );
      // Throw specific exception for invalid token signature/format
      throw UnauthorizedException('Invalid token: ${e.message}');
    } on JWTException catch (e, s) {
      // Use JWTException as the general catch-all
      print(
        '[validateToken] CATCH JWTException: General JWT error. '
        'Reason: ${e.message}\n$s',
      );
      // Treat other JWT exceptions as invalid tokens
      throw UnauthorizedException('Invalid token: ${e.message}');
    } on HtHttpException catch (e, s) {
      // Handle errors from the user repository (e.g., user not found)
      print(
        '[validateToken] CATCH HtHttpException: Error fetching user. '
        'Type: ${e.runtimeType}, Message: $e\n$s',
      );
      // Re-throw repository exceptions directly for the error handler
      rethrow;
    } catch (e, s) {
      // Catch unexpected errors during validation
      print('[validateToken] CATCH UNEXPECTED Exception: $e\n$s');
      // Wrap unexpected errors in a standard exception type
      throw OperationFailedException(
        'Token validation failed unexpectedly: $e',
      );
    }
  }
}
