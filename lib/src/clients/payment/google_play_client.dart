import 'package:core/core.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/config/environment_config.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/google_auth_service.dart';
import 'package:http_client/http_client.dart';
import 'package:logging/logging.dart';

/// {@template google_play_client}
/// A client for interacting with the Google Play Developer API.
///
/// This client uses the [GoogleAuthService] to obtain access tokens and
/// validates subscription purchases directly with Google servers.
/// {@endtemplate}
class GooglePlayClient {
  /// {@macro google_play_client}
  GooglePlayClient({
    required IGoogleAuthService googleAuthService,
    required Logger log,
    HttpClient? httpClient,
  }) : _log = log,
       _httpClient =
           httpClient ??
           HttpClient(
             baseUrl:
                 'https://androidpublisher.googleapis.com/androidpublisher/v3',
             tokenProvider: () => googleAuthService.getAccessToken(
               scope: 'https://www.googleapis.com/auth/androidpublisher',
             ),
           );

  final Logger _log;
  final HttpClient _httpClient;

  /// Verifies a subscription purchase with Google Play.
  ///
  /// [subscriptionId] is the product ID (e.g., 'premium_monthly').
  /// [purchaseToken] is the token provided by the mobile app after purchase.
  ///
  /// Returns a [Map] containing the subscription resource resource.
  /// Key fields include:
  /// - `expiryTimeMillis`: The time at which the subscription will expire.
  /// - `paymentState`: The payment state of the subscription.
  /// - `autoRenewing`: Whether the subscription will auto-renew.
  Future<Map<String, dynamic>> getSubscription({
    required String subscriptionId,
    required String purchaseToken,
  }) async {
    final packageName = EnvironmentConfig.googlePlayPackageName;
    if (packageName == null) {
      throw const ServerException(
        'Google Play Package Name is not configured.',
      );
    }

    try {
      final response = await _httpClient.get<Map<String, dynamic>>(
        '/applications/$packageName/purchases/subscriptions/$subscriptionId/tokens/$purchaseToken',
      );
      return response;
    } on HttpException catch (e) {
      if (e is NotFoundException) {
        _log.warning(
          'Google subscription not found. ID: $subscriptionId, Token: $purchaseToken',
        );
        // Map 404 to a clearer message for the caller
        throw const NotFoundException(
          'Invalid purchase token or subscription ID.',
        );
      }
      if (e is ForbiddenException) {
        _log.severe(
          'Google API Forbidden. Check Service Account permissions.',
        );
        throw const ServerException(
          'Backend configuration error: Cannot access Google Play API.',
        );
      }
      _log.severe('Google Play API Error: ${e.message}');
      rethrow;
    } catch (e, s) {
      _log.severe('Unexpected error calling Google Play API', e, s);
      throw const ServerException(
        'Failed to verify subscription with Google.',
      );
    }
  }
}
