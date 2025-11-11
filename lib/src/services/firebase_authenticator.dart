import 'package:core/core.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/config/environment_config.dart';
import 'package:http_client/http_client.dart';
import 'package:logging/logging.dart';

/// An abstract interface for a service that provides Firebase access tokens.
abstract class IFirebaseAuthenticator {
  /// Retrieves a short-lived OAuth2 access token for Firebase.
  Future<String?> getAccessToken();
}

/// {@template firebase_authenticator}
/// A concrete implementation of [IFirebaseAuthenticator] that uses a
/// two-legged OAuth flow to obtain an access token from Google.
///
/// This service is responsible for generating a signed JWT using the service
/// account credentials and exchanging it for a short-lived OAuth2 access token
/// that can be used to authenticate with Google APIs, such as the Firebase
/// Cloud Messaging (FCM) v1 API.
/// {@endtemplate}
class FirebaseAuthenticator implements IFirebaseAuthenticator {
  /// {@macro firebase_authenticator}
  /// Creates an instance of [FirebaseAuthenticator].
  FirebaseAuthenticator({required Logger log}) : _log = log {
    // This internal HttpClient is used exclusively for the token exchange.
    // It does not have an auth interceptor, which is crucial to prevent
    // an infinite loop.
    _tokenClient = HttpClient(
      baseUrl: 'https://oauth2.googleapis.com',
      tokenProvider: () async => null,
    );
  }

  final Logger _log;
  late final HttpClient _tokenClient;

  @override
  /// Retrieves a short-lived OAuth2 access token for Firebase.
  Future<String?> getAccessToken() async {
    _log.info('Requesting new Firebase access token...');
    try {
      // Step 1: Create and sign the JWT.
      final pem = EnvironmentConfig.firebasePrivateKey!.replaceAll(r'\n', '\n');
      final privateKey = RSAPrivateKey(pem);
      final jwt = JWT(
        // The 'scope' claim defines the permissions the access token will have.
        // 'cloud-platform' is a broad scope suitable for many Google Cloud APIs.
        {'scope': 'https://www.googleapis.com/auth/cloud-platform'},
        issuer: EnvironmentConfig.firebaseClientEmail,
        audience: Audience.one('https://oauth2.googleapis.com/token'),
      );
      final signedToken = jwt.sign(
        privateKey,
        algorithm: JWTAlgorithm.RS256,
        expiresIn: const Duration(minutes: 5),
      );
      _log.finer('Successfully signed JWT for token exchange.');

      // Step 2: Exchange the JWT for an access token.
      final response = await _tokenClient.post<Map<String, dynamic>>(
        '/token',
        data: {
          'grant_type': 'urn:ietf:params:oauth:grant-type:jwt-bearer',
          'assertion': signedToken,
        },
      );

      final accessToken = response['access_token'] as String?;
      if (accessToken == null) {
        _log.severe('Google OAuth response did not contain an access_token.');
        throw const OperationFailedException(
          'Could not retrieve Firebase access token.',
        );
      }
      _log.info('Successfully retrieved new Firebase access token.');
      return accessToken;
    } on HttpException {
      // Re-throw known HTTP exceptions directly.
      rethrow;
    } catch (e, s) {
      _log.severe('Error during Firebase token exchange: $e', e, s);
      // Wrap other errors in a standard exception.
      throw OperationFailedException(
        'Failed to authenticate with Firebase: $e',
      );
    }
  }
}
