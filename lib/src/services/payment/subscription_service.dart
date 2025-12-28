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
///
/// Key Responsibilities:
/// 1. **Purchase Verification:** Validates receipts directly with Apple/Google.
/// 2. **Idempotency:** Ensures transactions are processed exactly once.
/// 3. **Entitlement Portability (Restore Purchase):** Handles the "Restore Purchase"
///    flow by identifying if a subscription is owned by a different user account
///    and transferring ownership to the current user (Entitlement Transfer).
/// 4. **Anti-Sharing Enforcement:** When transferring a subscription, the previous
///    owner is automatically downgraded to prevent account sharing.
/// {@endtemplate}
class SubscriptionService {
  /// {@macro subscription_service}
  const SubscriptionService({
    required DataRepository<UserSubscription> userSubscriptionRepository,
    required DataRepository<User> userRepository,
    required AppStoreServerClient? appStoreClient,
    required GooglePlayClient? googlePlayClient,
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
  final AppStoreServerClient? _appStoreClient;
  final GooglePlayClient? _googlePlayClient;
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
    var willAutoRenew = true;

    // 2. Validate with Provider & Extract Canonical Data
    // We validate the receipt to get the authoritative 'originalTransactionId'.
    // This ID is the permanent, unique identifier for the subscription lifecycle,
    // regardless of renewals or user account changes.
    if (transaction.provider == StoreProvider.apple) {
      if (_appStoreClient == null) {
        throw const ServerException('App Store Client is not initialized.');
      }
      final appleResponse = await _appStoreClient.getAllSubscriptionStatuses(
        transaction.providerReceipt,
      );

      // Find the relevant transaction
      final group = appleResponse.data.singleWhere(
        (group) => group.lastTransactions.any(
          (t) => t.originalTransactionId == transaction.providerReceipt,
        ),
      );
      final lastTransaction = group.lastTransactions.first;

      final decodedTransaction = _appStoreClient.decodeTransaction(
        lastTransaction.signedTransactionInfo,
      );

      expiryDate = decodedTransaction.expiresDate;
      originalTransactionId = decodedTransaction.originalTransactionId;
    } else if (transaction.provider == StoreProvider.google) {
      if (_googlePlayClient == null) {
        throw const ServerException('Google Play Client is not initialized.');
      }
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

    // 3. Global Lookup & Entitlement Transfer (Restore Purchase Logic)
    // We first check if *any* user in the system already owns this subscription.
    // This is critical for the "Restore Purchase" flow.
    final existingSubscriptionByOriginalTransactionId =
        await _findSubscriptionByOriginalTransactionId(originalTransactionId);

    // If the subscription exists but belongs to a *different* user, it implies
    // the current user is restoring a purchase made on a previous account
    // (or on a different device). We must transfer the entitlement.
    if (existingSubscriptionByOriginalTransactionId != null &&
        existingSubscriptionByOriginalTransactionId.userId != user.id) {
      _log.info(
        'Transferring subscription from ${existingSubscriptionByOriginalTransactionId.userId} to ${user.id}',
      );
      await _transferSubscription(
        existingSubscriptionByOriginalTransactionId,
        user,
      );
    }

    // 4. Update/Create UserSubscription for Current User
    // Now that ownership is resolved (or if it's a new purchase), we proceed
    // to update the record for the current user.
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
      originalTransactionId: originalTransactionId,
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

  /// Transfers a subscription from an old [UserSubscription.userId] to [newUser].
  ///
  /// This implements the "Entitlement Transfer" logic:
  /// 1. **Downgrade Old User:** The previous owner is set to [AccessTier.standard].
  ///    This prevents two accounts from sharing the same paid subscription.
  /// 2. **Transfer Ownership:** The [UserSubscription] record is updated to point
  ///    to the [newUser].
  /// 3. **Upgrade New User:** The [newUser] will be upgraded in the main flow
  ///    after this method returns.
  Future<void> _transferSubscription(
    UserSubscription oldSubscription,
    User newUser,
  ) async {
    try {
      final oldUser = await _userRepository.read(id: oldSubscription.userId);
      if (oldUser.tier != AccessTier.standard) {
        await _userRepository.update(
          id: oldSubscription.userId,
          item: oldUser.copyWith(tier: AccessTier.standard),
        );
        _log.info(
          'Downgrading user ${oldSubscription.userId} to ${AccessTier.standard}.',
        );
      }
    } on NotFoundException {
      _log.warning(
        'Old user ${oldSubscription.userId} not found during transfer, assuming account was deleted.',
      );
    } catch (e, s) {
      _log.severe(
        'Failed to downgrade old user ${oldSubscription.userId} during transfer. Aborting to prevent inconsistent state.',
        e,
        s,
      );
      rethrow;
    }

    final updatedSubscription = oldSubscription.copyWith(
      userId: newUser.id,
      tier: AccessTier.premium,
    );

    try {
      await _userSubscriptionRepository.update(
        id: oldSubscription.id,
        item: updatedSubscription,
      );
    } catch (e) {
      _log.severe('Was not able to transfer subscription');
      rethrow;
    }
  }

  /// Handles an incoming Apple App Store Server Notification.
  ///
  /// This method expects a strongly-typed [AppleNotificationPayload] which
  /// has already been validated and decoded by the route handler.
  Future<void> handleAppleNotification(AppleNotificationPayload payload) async {
    _log.info('Processing Apple Notification: ${payload.notificationUUID}');

    if (_appStoreClient == null) {
      _log.warning('App Store Client not initialized. Ignoring notification.');
      return;
    }

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
    var updatedSubscription = subscription;
    var updatedUser = user;

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
      case AppleNotificationType.revoke:
        updatedSubscription = subscription.copyWith(
          status: SubscriptionStatus.expired,
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

    if (_googlePlayClient == null) {
      _log.warning(
        'Google Play Client not initialized. Ignoring notification.',
      );
      return;
    }

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

      var updatedSubscription = subscription;
      var updatedUser = user;

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
