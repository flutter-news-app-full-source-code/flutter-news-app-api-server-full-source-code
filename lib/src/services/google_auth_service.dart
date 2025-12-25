import 'package:core/core.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/config/environment_config.dart';
import 'package:http_client/http_client.dart';
import 'package:logging/logging.dart';

/// An abstract interface for a service that provides Google API access tokens.
abstract class IGoogleAuthService {
  /// Retrieves a short-lived OAuth2 access token for a given Google scope.
  Future<String?> getAccessToken({required String scope});
}

/// {@template google_auth_service}
/// A concrete implementation of [IGoogleAuthService] that uses a two-legged
/// OAuth flow to obtain an access token from Google.
///
/// This service is responsible for generating a signed JWT using the service
/// account credentials and exchanging it for a short-lived OAuth2 access token
/// that can be used to authenticate with various Google APIs, such as:
/// - Firebase Cloud Messaging (FCM) v1 API
/// - Google Play Developer API
///
/// It includes in-memory caching to reuse tokens until they expire, reducing
/// unnecessary token exchange requests.
/// {@endtemplate}
class GoogleAuthService implements IGoogleAuthService {
  /// {@macro google_auth_service}
  GoogleAuthService({required Logger log}) : _log = log {
    _tokenClient = HttpClient(
      baseUrl: 'https://oauth2.googleapis.com',
      tokenProvider: () async => null,
    );
  }

  final Logger _log;
  late final HttpClient _tokenClient;

  // In-memory cache for access tokens, keyed by scope.
  final Map<String, ({String token, DateTime expiry})> _tokenCache = {};

  @override
  Future<String?> getAccessToken({required String scope}) async {
    // Check cache first
    final cached = _tokenCache[scope];
    if (cached != null && cached.expiry.isAfter(DateTime.now())) {
      _log.info('Using cached Google access token for scope: $scope');
      return cached.token;
    }

    _log.info('Requesting new Google access token for scope: $scope...');
    try {
      // Step 1: Create and sign the JWT.
      final pem = EnvironmentConfig.firebasePrivateKey!.replaceAll(r'\n', '\n');
      final privateKey = RSAPrivateKey(pem);
      final jwt = JWT(
        {'scope': scope},
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
      final expiresIn = response['expires_in'] as int?;

      if (accessToken == null || expiresIn == null) {
        _log.severe('Google OAuth response did not contain access_token.');
        throw const OperationFailedException(
          'Could not retrieve Google access token.',
        );
      }

      // Cache the new token with its expiry time.
      final expiryTime = DateTime.now().add(Duration(seconds: expiresIn - 60));
      _tokenCache[scope] = (token: accessToken, expiry: expiryTime);

      _log.info('Successfully retrieved new Google access token.');
      return accessToken;
    } on HttpException {
      // Re-throw known HTTP exceptions directly.
      rethrow;
    } catch (e, s) {
      _log.severe('Error during Google token exchange: $e', e, s);
      // Wrap other errors in a standard exception.
      throw OperationFailedException(
        'Failed to authenticate with Google: $e',
      );
    }
  }
}
