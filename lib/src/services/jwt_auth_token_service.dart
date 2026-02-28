import 'package:core/core.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

import 'package:flutter_news_app_backend_api_full_source_code/src/config/environment_config.dart';
import 'package:flutter_news_app_backend_api_full_source_code/src/services/auth_token_service.dart';
import 'package:flutter_news_app_backend_api_full_source_code/src/services/token_blacklist_service.dart';
import 'package:logging/logging.dart';
import 'package:mongo_dart/mongo_dart.dart';

/// {@template jwt_auth_token_service}
/// An implementation of [AuthTokenService] using JSON Web Tokens (JWT).
///
/// Handles the creation (signing) and validation (verification) of JWTs,
/// including support for token invalidation via blacklisting.
/// {@endtemplate}
class JwtAuthTokenService implements AuthTokenService {
  /// {@macro jwt_auth_token_service}
  ///
  /// Requires:
  /// - [userRepository]: To fetch user details after validating the token's
  ///   subject claim.
  /// - [blacklistService]: To manage the blacklist of invalidated tokens.
  JwtAuthTokenService({
    required DataRepository<User> userRepository,
    required TokenBlacklistService blacklistService,
    required Logger log,
    String? jwtSecret,
    String? jwtIssuer,
    Duration? jwtExpiry,
  }) : _userRepository = userRepository,
       _blacklistService = blacklistService,
       _log = log,
       _jwtSecret = jwtSecret ?? EnvironmentConfig.jwtSecretKey,
       _jwtIssuer = jwtIssuer ?? EnvironmentConfig.jwtIssuer,
       _jwtExpiry = jwtExpiry ?? EnvironmentConfig.jwtExpiryDuration;

  final DataRepository<User> _userRepository;
  final TokenBlacklistService _blacklistService;
  final Logger _log;
  final String _jwtSecret;
  final String _jwtIssuer;
  final Duration _jwtExpiry;

  // --- Interface Implementation ---

  @override
  Future<String> generateToken(
    User user, {
    SupportedLanguage? language,
  }) async {
    try {
      final now = DateTime.now();
      final expiry = now.add(_jwtExpiry);
      final issuer = _jwtIssuer;

      final jwt = JWT(
        {
          // Standard claims
          'sub': user.id, // Subject (user ID) - REQUIRED
          'exp': expiry.millisecondsSinceEpoch ~/ 1000, // Expiration Time
          'iat': now.millisecondsSinceEpoch ~/ 1000, // Issued At
          'iss': issuer, // Issuer
          'jti': ObjectId().oid, // JWT ID (for potential blacklisting)
          // Custom claims (optional, include what's useful)
          'email': user.email,
          'role': user.role.name, // role for permissions
          'tier': user.tier.name, // AccessTier for entitlements
          'isAnonymous': user.isAnonymous,
          if (language != null) 'lang': language.name,
        },
        issuer: issuer,
        subject: user.id,
        jwtId: ObjectId().oid, // Re-setting jti here for clarity if needed
      );

      // Sign the token using HMAC-SHA256
      final token = jwt.sign(
        SecretKey(_jwtSecret),
        algorithm: JWTAlgorithm.HS256,
        expiresIn: _jwtExpiry, // Redundant but safe
      );

      _log.info(
        'Generated JWT for user ${user.id} '
        'with language: ${language?.name}',
      );
      return token;
    } catch (e) {
      _log.severe('Error generating JWT for user ${user.id}: $e');
      // Map to a standard exception
      throw OperationFailedException(
        'Failed to generate authentication token: $e',
      );
    }
  }

  @override
  Future<User?> validateToken(String token) async {
    _log.finer('[validateToken] Attempting to validate token...');
    try {
      // Verify the token's signature and expiry
      _log.finer('[validateToken] Verifying token signature and expiry...');
      final jwt = JWT.verify(token, SecretKey(_jwtSecret));
      _log.finer('[validateToken] Token verified. Payload: ${jwt.payload}');

      // --- Blacklist Check ---
      // Extract the JWT ID (jti) claim
      final jti = jwt.payload['jti'] as String?;
      if (jti == null || jti.isEmpty) {
        _log.warning(
          '[validateToken] Token validation failed: Missing or empty "jti" claim.',
        );
        // Throw specific exception for malformed token
        throw const BadRequestException(
          'Malformed token: Missing or empty JWT ID (jti) claim.',
        );
      }

      _log.finer('[validateToken] Checking blacklist for jti: $jti');
      final isBlacklisted = await _blacklistService.isBlacklisted(jti);
      if (isBlacklisted) {
        _log.warning(
          '[validateToken] Token validation failed: Token is blacklisted (jti: $jti).',
        );
        // Throw specific exception for blacklisted token
        throw const UnauthorizedException('Token has been invalidated.');
      }
      _log.finer('[validateToken] Token is not blacklisted (jti: $jti).');
      // --- End Blacklist Check ---

      // Extract user ID from the subject claim ('sub')
      final subClaim = jwt.payload['sub'];
      _log.finer(
        '[validateToken] Extracted "sub" claim: $subClaim '
        '(Type: ${subClaim.runtimeType})',
      );

      // Safely attempt to cast to String
      String? userId;
      if (subClaim is String) {
        userId = subClaim;
        _log.finer(
          '[validateToken] "sub" claim successfully cast to String: $userId',
        );
      } else if (subClaim != null) {
        // Treat non-string sub as an error
        _log.severe(
          '[validateToken] ERROR: "sub" claim is not a String '
          '(Type: ${subClaim.runtimeType}).',
        );
        throw BadRequestException(
          'Malformed token: "sub" claim is not a String '
          '(Type: ${subClaim.runtimeType}).',
        );
      }

      if (userId == null || userId.isEmpty) {
        _log.warning(
          '[validateToken] Token validation failed: Missing or empty "sub" claim.',
        );
        // Throw specific exception for malformed token
        throw const BadRequestException(
          'Malformed token: Missing or empty subject claim.',
        );
      }

      _log.finer('[validateToken] Attempting to fetch user with ID: $userId');
      // Fetch the full user object from the repository
      // This ensures the user still exists and is valid
      final user = await _userRepository.read(id: userId);
      _log
        ..finer(
          '[validateToken] User repository read successful for ID: $userId',
        )
        ..info(
          '[validateToken] Token validated successfully for user ${user.id}',
        );
      return user;
    } on JWTExpiredException catch (e, s) {
      _log.warning('[validateToken] Token expired.', e, s);
      // Throw the standardized exception instead of rethrowing the specific one
      throw const UnauthorizedException('Token expired.');
    } on JWTInvalidException catch (e, s) {
      _log.warning(
        '[validateToken] CATCH JWTInvalidException: Invalid token. '
        'Reason: ${e.message}\n$s',
      );
      // Throw specific exception for invalid token signature/format
      throw UnauthorizedException('Invalid token: ${e.message}');
    } on JWTException catch (e, s) {
      // Use JWTException as the general catch-all for other JWT issues
      _log.warning(
        '[validateToken] CATCH JWTException: General JWT error. '
        'Reason: ${e.message}\n$s',
      );
      // Treat other JWT exceptions as invalid tokens
      throw UnauthorizedException('Invalid token: ${e.message}');
    } on HttpException catch (e, s) {
      // Handle errors from the user repository (e.g., user not found)
      // or blacklist check (if it threw HttpException)
      _log.warning(
        '[validateToken] CATCH HttpException: Error during validation. '
        'Type: ${e.runtimeType}, Message: $e\n$s',
      );
      // Re-throw repository/blacklist exceptions directly
      rethrow;
    } catch (e, s) {
      // Catch unexpected errors during validation
      _log.severe('[validateToken] CATCH UNEXPECTED Exception', e, s);
      // Wrap unexpected errors in a standard exception type
      throw OperationFailedException(
        'Token validation failed unexpectedly: $e',
      );
    }
  }

  @override
  Future<void> invalidateToken(String token) async {
    _log.finer('[invalidateToken] Attempting to invalidate token...');
    try {
      // 1. Verify the token signature FIRST, but ignore expiry for blacklisting
      //    We want to blacklist even if it's already expired, to be safe.
      _log.finer('[invalidateToken] Verifying signature (ignoring expiry)...');
      final jwt = JWT.verify(
        token,
        SecretKey(_jwtSecret),
        checkExpiresIn: false, // IMPORTANT: Don't fail if expired here
        checkHeaderType: true, // Keep other standard checks
      );
      _log.finer('[invalidateToken] Token signature verified.');

      // 2. Extract JTI (JWT ID)
      final jti = jwt.payload['jti'] as String?;
      if (jti == null || jti.isEmpty) {
        _log.warning('[invalidateToken] Failed: Missing or empty "jti" claim.');
        throw const InvalidInputException(
          'Cannot invalidate token: Missing or empty JWT ID (jti) claim.',
        );
      }
      _log.finer('[invalidateToken] Extracted jti: $jti');

      // 3. Extract Expiry Time (exp)
      final expClaim = jwt.payload['exp'];
      if (expClaim == null || expClaim is! int) {
        _log.warning(
          '[invalidateToken] Failed: Missing or invalid "exp" claim.',
        );
        throw const InvalidInputException(
          'Cannot invalidate token: Missing or invalid expiry (exp) claim.',
        );
      }
      final expiryDateTime = DateTime.fromMillisecondsSinceEpoch(
        expClaim * 1000,
        isUtc: true,
      );
      _log
        ..finer('[invalidateToken] Extracted expiry: $expiryDateTime')
        // 4. Add JTI to the blacklist
        ..finer('[invalidateToken] Adding jti $jti to blacklist...');
      await _blacklistService.blacklist(jti, expiryDateTime);
      _log.info(
        '[invalidateToken] Token (jti: $jti) successfully blacklisted.',
      );
    } on JWTException catch (e, s) {
      // Catch errors during the initial verification (e.g., bad signature)
      _log.warning(
        '[invalidateToken] CATCH JWTException: Invalid token format/signature. '
        'Reason: ${e.message}\n$s',
      );
      // Treat as invalid input for invalidation purposes
      throw InvalidInputException('Invalid token format: ${e.message}');
    } on HttpException catch (e, s) {
      // Catch errors from the blacklist service itself
      _log.warning(
        '[invalidateToken] CATCH HttpException: Error during blacklisting. '
        'Type: ${e.runtimeType}, Message: $e\n$s',
      );
      // Re-throw blacklist service exceptions
      rethrow;
    } catch (e, s) {
      // Catch unexpected errors
      _log.severe('[invalidateToken] CATCH UNEXPECTED Exception', e, s);
      throw OperationFailedException(
        'Token invalidation failed unexpectedly: $e',
      );
    }
  }
}
