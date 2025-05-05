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

  // Potential future methods:
  // Future<void> invalidateToken(String token); // For token blacklisting
}

/// A basic implementation of [AuthTokenService].
///
/// **Note:** This is a placeholder and **not secure** for production.
/// It does not perform real cryptographic signing or validation.
/// Replace with a proper JWT implementation (e.g., using `dart_jsonwebtoken`).
class SimpleAuthTokenService implements AuthTokenService {
  /// {@macro simple_auth_token_service}
  const SimpleAuthTokenService({
    // In a real implementation, you'd inject a secret key here.
    String secretKey = 'very-secret-key-replace-me',
  }) : _secretKey = secretKey;

  //
  // ignore: unused_field
  final String _secretKey;

  // Placeholder for storing "valid" tokens in this insecure example.
  // A real implementation validates cryptographically.
  static final Map<String, User> _validTokens = {};

  @override
  Future<String> generateToken(User user) async {
    // Insecure placeholder: Generate a simple token string.
    // A real implementation would create a JWT with claims and sign it.
    final token =
        'token_for_${user.id}_${DateTime.now().millisecondsSinceEpoch}';
    _validTokens[token] = user; // Store for simple validation
    print('Generated token (INSECURE): $token for user ${user.id}');
    await Future<void>.delayed(Duration.zero); // Simulate async
    return token;
  }

  @override
  Future<User?> validateToken(String token) async {
    // Insecure placeholder: Check if the token exists in our map.
    // A real implementation would verify JWT signature, expiry, issuer, etc.
    print('Validating token (INSECURE): $token');
    final user = _validTokens[token];
    await Future<void>.delayed(Duration.zero); // Simulate async
    if (user != null) {
      print('Token valid for user ${user.id}');
      return user;
    } else {
      print('Token invalid');
      return null;
    }
  }
}
