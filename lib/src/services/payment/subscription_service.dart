import 'package:core/core.dart';
import 'package:data_repository/data_repository.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/clients/payment/app_store_server_client.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/clients/payment/google_play_client.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/enums/enums.dart';
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
    if (await _idempotencyService.isEventProcessed(
      transaction.providerReceipt,
    )) {
      _log.info(
        'Transaction ${transaction.providerReceipt} already processed. Returning existing subscription.',
      );
      final existing = await _findSubscriptionByUserId(user.id);
      if (existing != null) {
        return existing;
      }
      _log.warning(
        'Idempotency record found but no subscription exists. Re-processing.',
      );
    }

    DateTime? expiryDate;
    String? originalTransactionId;
    bool willAutoRenew = true;

    // 2. Validate with Provider
    if (transaction.provider == StoreProvider.apple) {
      final appleResponse = await _appStoreClient.getAllSubscriptionStatuses(
        transaction.providerReceipt,
      );

      final lastTransaction = appleResponse.data.first.lastTransactions.first;
      final decodedTransaction = _appStoreClient.decodeTransaction(
        lastTransaction.signedTransactionInfo,
      );

      expiryDate = decodedTransaction.expiresDate;
      originalTransactionId = decodedTransaction.originalTransactionId;
    } else if (transaction.provider == StoreProvider.google) {
      final googlePurchase = await _googlePlayClient.getSubscription(
        subscriptionId: transaction.planId,
        purchaseToken: transaction.providerReceipt,
      );

      final expiryMillis = int.tryParse(googlePurchase.expiryTimeMillis);
      if (expiryMillis != null) {
        expiryDate = DateTime.fromMillisecondsSinceEpoch(
          expiryMillis,
          isUtc: true,
        );
      }
      willAutoRenew = googlePurchase.autoRenewing;
      originalTransactionId = transaction.providerReceipt;
    } else {
      throw const BadRequestException('Unsupported store provider.');
    }

    if (expiryDate == null) {
      throw const ServerException(
        'Could not determine subscription expiry date.',
      );
    }

    // 3. Update/Create UserSubscription
    final currentSubscription = await _findSubscriptionByUserId(user.id);

    final newStatus = expiryDate.isAfter(DateTime.now())
        ? SubscriptionStatus.active
        : SubscriptionStatus.expired;

    final subscriptionData = UserSubscription(
      id: currentSubscription?.id ?? ObjectId().oid,
      userId: user.id,
      tier: AccessTier.premium,
      status: newStatus,
      provider: transaction.provider,
      validUntil: expiryDate,
      willAutoRenew: willAutoRenew,
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

    if (await _idempotencyService.isEventProcessed(payload.notificationUUID)) {
      _log.info(
        'Apple notification ${payload.notificationUUID} already processed.',
      );
      return;
    }

    final transactionInfo = _appStoreClient.decodeTransaction(
      payload.data.signedTransactionInfo,
    );
    final originalTransactionId = transactionInfo.originalTransactionId;

    final subscription = await _findSubscriptionByOriginalTransactionId(
      originalTransactionId,
    );
    if (subscription == null) {
      _log.warning(
        'No subscription found for Apple ID: $originalTransactionId',
      );
      return;
    }

    final user = await _userRepository.read(id: subscription.userId);
    UserSubscription updatedSubscription = subscription;
    User updatedUser = user;

    switch (payload.notificationType) {
      case AppleNotificationType.didRenew:
      case AppleNotificationType.subscribed:
        updatedSubscription = subscription.copyWith(
          status: SubscriptionStatus.active,
          validUntil: transactionInfo.expiresDate,
        );
        updatedUser = user.copyWith(tier: AccessTier.premium);
      case AppleNotificationType.expired:
      case AppleNotificationType.didFailToRenew:
      case AppleNotificationType.gracePeriodExpired:
        updatedSubscription = subscription.copyWith(
          status: SubscriptionStatus.expired,
          willAutoRenew: false,
        );
        updatedUser = user.copyWith(tier: AccessTier.standard);
      case AppleNotificationType.revoke:
        updatedSubscription = subscription.copyWith(
          status: SubscriptionStatus.revoked,
          willAutoRenew: false,
        );
        updatedUser = user.copyWith(tier: AccessTier.standard);
      case AppleNotificationType.didChangeRenewalStatus:
        if (payload.subtype == AppleNotificationSubtype.autoRenewDisabled) {
          updatedSubscription = subscription.copyWith(willAutoRenew: false);
        } else if (payload.subtype ==
            AppleNotificationSubtype.autoRenewEnabled) {
          updatedSubscription = subscription.copyWith(willAutoRenew: true);
        }
      default:
        _log.info(
          'Unhandled Apple notification type: ${payload.notificationType.name}',
        );
    }

    if (updatedSubscription != subscription) {
      await _userSubscriptionRepository.update(
        id: subscription.id,
        item: updatedSubscription,
      );
    }

    if (updatedUser != user) {
      await _userRepository.update(id: user.id, item: updatedUser);
    }

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

    final eventId = '${payload.eventTimeMillis}_${subDetails.purchaseToken}';
    if (await _idempotencyService.isEventProcessed(eventId)) {
      _log.info('Google notification $eventId already processed.');
      return;
    }

    try {
      final googlePurchase = await _googlePlayClient.getSubscription(
        subscriptionId: subDetails.subscriptionId,
        purchaseToken: subDetails.purchaseToken,
      );

      final subscription = await _findSubscriptionByOriginalTransactionId(
        subDetails.purchaseToken,
      );
      if (subscription == null) {
        _log.warning(
          'No subscription found for Google Token: ${subDetails.purchaseToken}',
        );
        return;
      }

      final user = await _userRepository.read(id: subscription.userId);
      final expiryMillis = int.tryParse(googlePurchase.expiryTimeMillis);
      final expiryDate = expiryMillis != null
          ? DateTime.fromMillisecondsSinceEpoch(expiryMillis, isUtc: true)
          : null;

      UserSubscription updatedSubscription = subscription;
      User updatedUser = user;

      if (expiryDate != null && expiryDate.isAfter(DateTime.now())) {
        updatedSubscription = subscription.copyWith(
          status: SubscriptionStatus.active,
          validUntil: expiryDate,
          willAutoRenew: googlePurchase.autoRenewing,
        );
        updatedUser = user.copyWith(tier: AccessTier.premium);
      } else {
        updatedSubscription = subscription.copyWith(
          status: SubscriptionStatus.expired,
          willAutoRenew: false,
        );
        updatedUser = user.copyWith(tier: AccessTier.standard);
      }

      if (updatedSubscription != subscription) {
        await _userSubscriptionRepository.update(
          id: subscription.id,
          item: updatedSubscription,
        );
      }

      if (updatedUser != user) {
        await _userRepository.update(id: user.id, item: updatedUser);
      }

      await _idempotencyService.recordEvent(eventId);
      _log.info('Successfully processed Google notification.');
    } catch (e) {
      _log.severe('Failed to verify Google subscription state: $e');
      rethrow;
    }
  }

  Future<UserSubscription?> _findSubscriptionByUserId(String userId) async {
    try {
      final subscriptions = await _userSubscriptionRepository.readAll(
        filter: {'userId': userId},
      );
      return subscriptions.items.isNotEmpty ? subscriptions.items.first : null;
    } catch (e) {
      return null;
    }
  }

  Future<UserSubscription?> _findSubscriptionByOriginalTransactionId(
    String originalTransactionId,
  ) async {
    try {
      final subscriptions = await _userSubscriptionRepository.readAll(
        filter: {'originalTransactionId': originalTransactionId},
      );
      return subscriptions.items.isNotEmpty ? subscriptions.items.first : null;
    } catch (e) {
      return null;
    }
  }
}
