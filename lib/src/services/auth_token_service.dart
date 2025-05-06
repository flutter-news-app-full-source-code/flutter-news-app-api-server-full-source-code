import 'package:ht_shared/ht_shared.dart';

/// {@template auth_token_service}
/// Service responsible for generating and validating authentication tokens.
///
/// Implementations will handle the specifics of token creation (e.g., JWT
/// signing with a secret key) and validation (signature, expiry, claims).
/// {@endtemplate}
abstract class AuthTokenService {
  /// {@macro auth_token_service}
  const AuthTokenService();

  /// Generates an authentication token for the given user.
  ///
  /// Returns the generated token string.
  /// Throws [OperationFailedException] if token generation fails.
  Future<String> generateToken(User user);

  /// Validates the given token string.
  ///
  /// Returns the [User] associated with the token if valid.
  /// Returns `null` if the token is invalid, expired, or malformed.
  /// Throws [OperationFailedException] for unexpected validation errors.
  Future<User?> validateToken(String token);

  /// Invalidates the given token, preventing its further use.
  ///
  /// Implementations might achieve this by adding the token's identifier
  /// (e.g., JWT ID 'jti') to a blacklist until its original expiry time.
  ///
  /// - [token]: The token string to invalidate.
  ///
  /// Throws:
  /// - [InvalidInputException] if the token format is invalid.
  /// - [OperationFailedException] if the invalidation process fails unexpectedly.
  Future<void> invalidateToken(String token);
}
