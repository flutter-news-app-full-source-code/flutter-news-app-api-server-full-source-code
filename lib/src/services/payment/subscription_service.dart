import 'dart:convert';

import 'package:core/core.dart';
import 'package:data_repository/data_repository.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/clients/payment/app_store_server_client.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/clients/payment/google_play_client.dart';
import 'package:logging/logging.dart';
import 'package:mongo_dart/mongo_dart.dart';

/// {@template subscription_service}
/// The central state machine for the subscription system.
///
/// This service orchestrates the verification of purchases, updates to
/// [UserSubscription] records, and the promotion/demotion of [User.tier].
/// {@endtemplate}
class SubscriptionService {
  /// {@macro subscription_service}
  const SubscriptionService({
    required DataRepository<UserSubscription> userSubscriptionRepository,
    required DataRepository<User> userRepository,
    required AppStoreServerClient appStoreClient,
    required GooglePlayClient googlePlayClient,
    required Logger log,
  }) : _userSubscriptionRepository = userSubscriptionRepository,
       _userRepository = userRepository,
       _appStoreClient = appStoreClient,
       _googlePlayClient = googlePlayClient,
       _log = log;

  final DataRepository<UserSubscription> _userSubscriptionRepository;
  final DataRepository<User> _userRepository;
  final AppStoreServerClient _appStoreClient;
  final GooglePlayClient _googlePlayClient;
  final Logger _log;

  /// Verifies a purchase transaction from a client and updates the user's
  /// entitlement state.
  Future<UserSubscription> verifyAndProcessPurchase({
    required User user,
    required PurchaseTransaction transaction,
  }) async {
    _log.info(
      'Processing purchase for user ${user.id} via ${transaction.provider.name}',
    );

    DateTime? expiryDate;
    String? originalTransactionId;

    // 1. Validate with Provider
    if (transaction.provider == StoreProvider.apple) {
      // For Apple, the providerReceipt is the originalTransactionId
      originalTransactionId = transaction.providerReceipt;
      final response = await _appStoreClient.getAllSubscriptionStatuses(
        originalTransactionId,
      );
      // Simplified parsing logic for Phase 2.
      // In a real app, we would parse the 'signedTransactionInfo' JWS.
      // For now, we assume if we got a 200 OK and data, it's valid.
      // We'll set a default expiry for this initial implementation or
      // parse it if we had the JWS decoder fully set up for the response body.
      expiryDate = DateTime.now().add(const Duration(days: 30));
    } else if (transaction.provider == StoreProvider.google) {
      final response = await _googlePlayClient.getSubscription(
        subscriptionId: transaction.planId,
        purchaseToken: transaction.providerReceipt,
      );
      // Google returns 'expiryTimeMillis' as a string
      final expiryMillis = int.tryParse(
        response['expiryTimeMillis'] as String? ?? '',
      );
      if (expiryMillis != null) {
        expiryDate = DateTime.fromMillisecondsSinceEpoch(
          expiryMillis,
          isUtc: true,
        );
      }
      originalTransactionId =
          transaction.providerReceipt; // Use token as ID for Google
    } else {
      throw const BadRequestException('Unsupported store provider.');
    }

    if (expiryDate == null) {
      throw const ServerException(
        'Could not determine subscription expiry date.',
      );
    }

    // 2. Update/Create UserSubscription
    // Check if a subscription already exists for this user
    UserSubscription? currentSubscription;
    try {
      final subscriptions = await _userSubscriptionRepository.readAll(
        filter: {'userId': user.id},
      );
      if (subscriptions.items.isNotEmpty) {
        currentSubscription = subscriptions.items.first;
      }
    } catch (_) {
      // Ignore errors, assume no subscription
    }

    final newStatus = expiryDate.isAfter(DateTime.now())
        ? SubscriptionStatus.active
        : SubscriptionStatus.expired;

    final subscriptionData = UserSubscription(
      id: currentSubscription?.id ?? ObjectId().oid,
      userId: user.id,
      tier: AccessTier.premium, // Assuming all purchases grant premium for now
      status: newStatus,
      provider: transaction.provider,
      validUntil: expiryDate,
      willAutoRenew: true, // Default assumption until webhook updates it
      originalTransactionId: originalTransactionId ?? '',
    );

    if (currentSubscription != null) {
      await _userSubscriptionRepository.update(
        id: currentSubscription.id,
        item: subscriptionData,
      );
    } else {
      await _userSubscriptionRepository.create(item: subscriptionData);
    }

    // 3. Update User Entitlement
    if (newStatus == SubscriptionStatus.active &&
        user.tier != AccessTier.premium) {
      _log.info('Upgrading user ${user.id} to Premium.');
      await _userRepository.update(
        id: user.id,
        item: user.copyWith(tier: AccessTier.premium),
      );
    }

    return subscriptionData;
  }

  /// Handles an incoming Apple App Store Server Notification.
  ///
  /// [signedPayload] is the JWS string received from Apple.
  Future<void> handleAppleWebhook(String signedPayload) async {
    _log.info('Processing Apple Webhook...');
    // TODO(implementation):
    // 1. Verify JWS signature using Apple root certs (via jose package).
    // 2. Decode payload to get `notificationType` and `subtype`.
    // 3. Extract `data.signedTransactionInfo` and `data.signedRenewalInfo`.
    // 4. Find UserSubscription by `originalTransactionId`.
    // 5. Update status (e.g., DID_RENEW -> active, EXPIRED -> expired).
    // 6. Update User.tier accordingly.

    // For Phase 3, we log the receipt to confirm connectivity.
    _log.fine('Apple Payload received (length: ${signedPayload.length})');
  }

  /// Handles an incoming Google Play Real-Time Developer Notification.
  ///
  /// [message] is the Pub/Sub message object containing the base64 data.
  Future<void> handleGoogleWebhook(Map<String, dynamic> message) async {
    _log.info('Processing Google Webhook...');
    try {
      final dataBase64 = message['data'] as String?;
      if (dataBase64 == null) return;

      final decodedString = utf8.decode(base64.decode(dataBase64));
      final json = jsonDecode(decodedString) as Map<String, dynamic>;

      // TODO(implementation):
      // 1. Check for `subscriptionNotification`.
      // 2. Extract `purchaseToken` and `subscriptionId`.
      // 3. Call GooglePlayClient.getSubscription() to get authoritative status.
      // 4. Update UserSubscription and User.tier.

      _log.fine('Decoded Google Notification: $json');
    } catch (e) {
      _log.warning('Failed to decode Google webhook data: $e');
    }
  }

  /// Handles an incoming Stripe Webhook event.
  Future<void> handleStripeWebhook(String payload, String signature) async {
    _log.info('Processing Stripe Webhook...');
    // TODO(implementation):
    // 1. Verify signature using STRIPE_WEBHOOK_SIGNING_SECRET.
    // 2. Parse event type (e.g., customer.subscription.updated).
    // 3. Extract customer ID or metadata to find the user.
    // 4. Update UserSubscription and User.tier.
    _log.fine('Stripe event received.');
  }
}
