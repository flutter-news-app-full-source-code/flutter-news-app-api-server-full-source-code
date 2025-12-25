import 'dart:convert';

import 'package:core/core.dart';
import 'package:data_repository/data_repository.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/clients/payment/app_store_server_client.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/clients/payment/google_play_client.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/models/payment/apple_notification_payload.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/models/payment/google_subscription_notification.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/payment/idempotency_service.dart';
import 'package:logging/logging.dart';
import 'package:mongo_dart/mongo_dart.dart';

/// {@template subscription_service}
/// The central state machine for the subscription system.
///
/// This service orchestrates the verification of purchases, updates to
/// [UserSubscription] records, and the promotion/demotion of [User.tier].
/// It enforces idempotency to prevent duplicate processing of transactions
/// and webhooks.
/// {@endtemplate}
class SubscriptionService {
  /// {@macro subscription_service}
  const SubscriptionService({
    required DataRepository<UserSubscription> userSubscriptionRepository,
    required DataRepository<User> userRepository,
    required AppStoreServerClient appStoreClient,
    required GooglePlayClient googlePlayClient,
    required IdempotencyService idempotencyService,
    required Logger log,
  }) : _userSubscriptionRepository = userSubscriptionRepository,
       _userRepository = userRepository,
       _appStoreClient = appStoreClient,
       _googlePlayClient = googlePlayClient,
       _idempotencyService = idempotencyService,
       _log = log;

  final DataRepository<UserSubscription> _userSubscriptionRepository;
  final DataRepository<User> _userRepository;
  final AppStoreServerClient _appStoreClient;
  final GooglePlayClient _googlePlayClient;
  final IdempotencyService _idempotencyService;
  final Logger _log;

  /// Verifies a purchase transaction from a client and updates the user's
  /// entitlement state.
  ///
  /// This method is idempotent. If the [PurchaseTransaction.providerReceipt] has
  /// already been processed, it will return the existing subscription without
  /// re-verifying with the store.
  Future<UserSubscription> verifyAndProcessPurchase({
    required User user,
    required PurchaseTransaction transaction,
  }) async {
    _log.info(
      'Processing purchase for user ${user.id} via ${transaction.provider.name}',
    );

    // 1. Idempotency Check
    // We use the providerReceipt (purchase token/transaction ID) as the key.
    if (await _idempotencyService.isEventProcessed(
      transaction.providerReceipt,
    )) {
      _log.info(
        'Transaction ${transaction.providerReceipt} already processed. Returning existing subscription.',
      );
      final existing = await _userSubscriptionRepository.readAll(
        filter: {'userId': user.id},
      );
      if (existing.items.isNotEmpty) {
        return existing.items.first;
      }
      // If processed but no subscription found, we might need to re-process
      // or throw. For safety, we proceed to re-verify.
      _log.warning(
        'Idempotency record found but no subscription exists. Re-processing.',
      );
    }

    DateTime? expiryDate;
    String? originalTransactionId;

    // 2. Validate with Provider
    if (transaction.provider == StoreProvider.apple) {
      // For Apple, the providerReceipt is the originalTransactionId
      originalTransactionId = transaction.providerReceipt;
      final response = await _appStoreClient.getAllSubscriptionStatuses(
        originalTransactionId,
      );

      // In a real implementation, we would parse the 'signedTransactionInfo'
      // from the response using _appStoreClient.decodeJws().
      // For this phase, we assume validity if the API call succeeds.
      // TODO: Extract authoritative expiry from JWS.
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

    // 3. Update/Create UserSubscription
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

    // 4. Update User Entitlement
    if (newStatus == SubscriptionStatus.active &&
        user.tier != AccessTier.premium) {
      _log.info('Upgrading user ${user.id} to Premium.');
      await _userRepository.update(
        id: user.id,
        item: user.copyWith(tier: AccessTier.premium),
      );
    }

    // 5. Record Idempotency
    await _idempotencyService.recordEvent(transaction.providerReceipt);

    return subscriptionData;
  }

  /// Handles an incoming Apple App Store Server Notification.
  ///
  /// This method expects a strongly-typed [AppleNotificationPayload] which
  /// has already been validated and decoded by the route handler.
  Future<void> handleAppleNotification(AppleNotificationPayload payload) async {
    _log.info('Processing Apple Notification: ${payload.notificationUUID}');

    // 1. Idempotency Check
    if (await _idempotencyService.isEventProcessed(payload.notificationUUID)) {
      _log.info('Apple notification ${payload.notificationUUID} already processed.');
      return;
    }

    // 2. Extract Data
    // The payload.data contains the signed info. We need to decode the
    // transaction info to get the originalTransactionId.
    final transactionInfo = _appStoreClient.decodeJws(
      payload.data.signedTransactionInfo,
    );
    final originalTransactionId = transactionInfo['originalTransactionId'] as String?;
    final expiresDate = transactionInfo['expiresDate'] as int?;

    if (originalTransactionId == null) {
      _log.warning('Apple notification missing originalTransactionId.');
      return;
    }

    // 3. Find User Subscription
    final subscriptions = await _userSubscriptionRepository.readAll(
      filter: {'originalTransactionId': originalTransactionId},
    );

    if (subscriptions.items.isEmpty) {
      _log.warning('No subscription found for Apple ID: $originalTransactionId');
      return;
    }

    final subscription = subscriptions.items.first;
    final user = await _userRepository.read(id: subscription.userId);

    // 4. Update State based on Notification Type
    UserSubscription updatedSubscription = subscription;
    User updatedUser = user;

    switch (payload.notificationType) {
      case 'DID_RENEW':
      case 'SUBSCRIBED':
        if (expiresDate != null) {
          updatedSubscription = subscription.copyWith(
            status: SubscriptionStatus.active,
            validUntil: DateTime.fromMillisecondsSinceEpoch(expiresDate),
          );
          updatedUser = user.copyWith(tier: AccessTier.premium);
        }
        break;
      case 'EXPIRED':
      case 'DID_FAIL_TO_RENEW':
        updatedSubscription = subscription.copyWith(
          status: SubscriptionStatus.expired,
        );
        updatedUser = user.copyWith(tier: AccessTier.standard);
        break;
      // Handle other types (REFUND, etc.) as needed
    }

    // 5. Persist Changes
    if (updatedSubscription != subscription) {
      await _userSubscriptionRepository.update(
        id: subscription.id,
        item: updatedSubscription,
      );
    }

    if (updatedUser != user) {
      await _userRepository.update(id: user.id, item: updatedUser);
    }

    // 6. Record Idempotency
    await _idempotencyService.recordEvent(payload.notificationUUID);
    _log.info('Successfully processed Apple notification.');
  }

  /// Handles an incoming Google Play Real-Time Developer Notification.
  ///
  /// This method expects a strongly-typed [GoogleSubscriptionNotification].
  Future<void> handleGoogleNotification(
    GoogleSubscriptionNotification payload,
  ) async {
    _log.info('Processing Google Notification...');

    final subDetails = payload.subscriptionNotification;
    if (subDetails == null) {
      _log.info('Notification is not a subscription event. Ignoring.');
      return;
    }

    // 1. Idempotency Check
    // Google doesn't provide a unique event ID in the payload, so we create
    // a composite key from the timestamp and purchase token.
    final eventId = '${payload.eventTimeMillis}_${subDetails.purchaseToken}';
    if (await _idempotencyService.isEventProcessed(eventId)) {
      _log.info('Google notification $eventId already processed.');
      return;
    }

    // 2. Verify with Google API
    // The notification itself is just a signal. We must call the API to get
    // the authoritative state.
    try {
      final response = await _googlePlayClient.getSubscription(
        subscriptionId: subDetails.subscriptionId,
        purchaseToken: subDetails.purchaseToken,
      );

      // 3. Find User Subscription
      // We search by the purchase token (which we store as originalTransactionId for Google)
      final subscriptions = await _userSubscriptionRepository.readAll(
        filter: {'originalTransactionId': subDetails.purchaseToken},
      );

      if (subscriptions.items.isEmpty) {
        _log.warning('No subscription found for Google Token: ${subDetails.purchaseToken}');
        return;
      }

      final subscription = subscriptions.items.first;
      final user = await _userRepository.read(id: subscription.userId);

      // 4. Update State
      final expiryMillis = int.tryParse(response['expiryTimeMillis'] as String? ?? '');
      final DateTime? expiryDate = expiryMillis != null
          ? DateTime.fromMillisecondsSinceEpoch(expiryMillis, isUtc: true)
          : null;

      UserSubscription updatedSubscription = subscription;
      User updatedUser = user;

      if (expiryDate != null && expiryDate.isAfter(DateTime.now())) {
        updatedSubscription = subscription.copyWith(
          status: SubscriptionStatus.active,
          validUntil: expiryDate,
        );
        updatedUser = user.copyWith(tier: AccessTier.premium);
      } else {
        updatedSubscription = subscription.copyWith(
          status: SubscriptionStatus.expired,
        );
        updatedUser = user.copyWith(tier: AccessTier.standard);
      }

      // 5. Persist Changes
      if (updatedSubscription != subscription) {
        await _userSubscriptionRepository.update(
          id: subscription.id,
          item: updatedSubscription,
        );
      }

      if (updatedUser != user) {
        await _userRepository.update(id: user.id, item: updatedUser);
      }

      // 6. Record Idempotency
      await _idempotencyService.recordEvent(eventId);
      _log.info('Successfully processed Google notification.');

    } catch (e) {
      _log.severe('Failed to verify Google subscription state: $e');
      // We do NOT record idempotency here so we can retry on failure.
      rethrow;
    }
  }
}
