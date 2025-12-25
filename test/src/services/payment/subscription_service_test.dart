import 'package:core/core.dart';
import 'package:data_repository/data_repository.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/clients/payment/app_store_server_client.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/clients/payment/google_play_client.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/enums/payment/payment.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/models/payment/payment.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/payment/idempotency_service.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/payment/subscription_service.dart';
import 'package:logging/logging.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class MockDataRepository<T> extends Mock implements DataRepository<T> {}

class MockAppStoreServerClient extends Mock implements AppStoreServerClient {}

class MockGooglePlayClient extends Mock implements GooglePlayClient {}

class MockIdempotencyService extends Mock implements IdempotencyService {}

class MockLogger extends Mock implements Logger {}

void main() {
  group('SubscriptionService', () {
    late DataRepository<UserSubscription> mockUserSubscriptionRepository;
    late DataRepository<User> mockUserRepository;
    late AppStoreServerClient mockAppStoreClient;
    late GooglePlayClient mockGooglePlayClient;
    late IdempotencyService mockIdempotencyService;
    late Logger mockLogger;
    late SubscriptionService service;

    final testUser = User(
      id: 'user-1',
      email: 'test@example.com',
      role: UserRole.user,
      tier: AccessTier.standard,
      createdAt: DateTime.now(),
    );

    setUpAll(() {
      registerFallbackValue(
        User(
          id: 'user-1',
          email: 'test@example.com',
          role: UserRole.user,
          tier: AccessTier.standard,
          createdAt: DateTime.now(),
        ),
      );
      registerFallbackValue(
        UserSubscription(
          id: 'sub-1',
          userId: 'user-1',
          tier: AccessTier.premium,
          status: SubscriptionStatus.active,
          provider: StoreProvider.apple,
          validUntil: DateTime.now().add(const Duration(days: 30)),
          willAutoRenew: true,
          originalTransactionId: 'orig-trans-id',
        ),
      );
    });

    setUp(() {
      mockUserSubscriptionRepository = MockDataRepository<UserSubscription>();
      mockUserRepository = MockDataRepository<User>();
      mockAppStoreClient = MockAppStoreServerClient();
      mockGooglePlayClient = MockGooglePlayClient();
      mockIdempotencyService = MockIdempotencyService();
      mockLogger = MockLogger();

      service = SubscriptionService(
        userSubscriptionRepository: mockUserSubscriptionRepository,
        userRepository: mockUserRepository,
        appStoreClient: mockAppStoreClient,
        googlePlayClient: mockGooglePlayClient,
        idempotencyService: mockIdempotencyService,
        log: mockLogger,
      );

      // Default stubs for successful repository calls
      when(
        () => mockUserRepository.update(
          id: any(named: 'id'),
          item: any(named: 'item'),
        ),
      ).thenAnswer((_) async => testUser);
      when(
        () => mockUserSubscriptionRepository.create(item: any(named: 'item')),
      ).thenAnswer(
        (_) async => UserSubscription(
          id: 'sub-1',
          userId: 'user-1',
          tier: AccessTier.premium,
          status: SubscriptionStatus.active,
          provider: StoreProvider.apple,
          validUntil: DateTime.now().add(const Duration(days: 30)),
          willAutoRenew: true,
          originalTransactionId: 'orig-trans-id',
        ),
      );
      when(
        () => mockUserSubscriptionRepository.update(
          id: any(named: 'id'),
          item: any(named: 'item'),
        ),
      ).thenAnswer(
        (_) async => UserSubscription(
          id: 'sub-1',
          userId: 'user-1',
          tier: AccessTier.premium,
          status: SubscriptionStatus.active,
          provider: StoreProvider.apple,
          validUntil: DateTime.now().add(const Duration(days: 30)),
          willAutoRenew: true,
          originalTransactionId: 'orig-trans-id',
        ),
      );
      when(
        () => mockIdempotencyService.recordEvent(any()),
      ).thenAnswer((_) async {});
    });

    group('verifyAndProcessPurchase', () {
      const transaction = PurchaseTransaction(
        provider: StoreProvider.google,
        providerReceipt: 'google-receipt',
        planId: 'monthly.premium',
      );

      test(
        'returns existing subscription if event is already processed',
        () async {
          when(
            () => mockIdempotencyService.isEventProcessed(any()),
          ).thenAnswer((_) async => true);
          final existingSub = UserSubscription(
            id: 'sub-1',
            userId: testUser.id,
            tier: AccessTier.premium,
            status: SubscriptionStatus.active,
            provider: StoreProvider.google,
            validUntil: DateTime.now().add(const Duration(days: 30)),
            willAutoRenew: true,
            originalTransactionId: 'google-receipt',
          );
          when(
            () => mockUserSubscriptionRepository.readAll(
              filter: any(named: 'filter'),
            ),
          ).thenAnswer(
            (_) async => PaginatedResponse(
              items: [existingSub],
              cursor: null,
              hasMore: false,
            ),
          );

          final result = await service.verifyAndProcessPurchase(
            user: testUser,
            transaction: transaction,
          );

          expect(result, equals(existingSub));
          verifyNever(
            () => mockGooglePlayClient.getSubscription(
              subscriptionId: any(named: 'subscriptionId'),
              purchaseToken: any(named: 'purchaseToken'),
            ),
          );
        },
      );

      test('processes new Google purchase successfully', () async {
        when(
          () => mockIdempotencyService.isEventProcessed(any()),
        ).thenAnswer((_) async => false);
        when(
          () => mockUserSubscriptionRepository.readAll(
            filter: any(named: 'filter'),
          ),
        ).thenAnswer(
          (_) async =>
              const PaginatedResponse(items: [], cursor: null, hasMore: false),
        );
        when(
          () => mockGooglePlayClient.getSubscription(
            subscriptionId: any(named: 'subscriptionId'),
            purchaseToken: any(named: 'purchaseToken'),
          ),
        ).thenAnswer(
          (_) async => GoogleSubscriptionPurchase(
            expiryTimeMillis: DateTime.now()
                .add(const Duration(days: 30))
                .millisecondsSinceEpoch
                .toString(),
            autoRenewing: true,
          ),
        );

        await service.verifyAndProcessPurchase(
          user: testUser,
          transaction: transaction,
        );

        verify(
          () => mockUserSubscriptionRepository.create(item: any(named: 'item')),
        ).called(1);
        final capturedUser =
            verify(
                  () => mockUserRepository.update(
                    id: testUser.id,
                    item: captureAny(named: 'item'),
                  ),
                ).captured.first
                as User;
        expect(capturedUser.tier, AccessTier.premium);
        verify(
          () => mockIdempotencyService.recordEvent(transaction.providerReceipt),
        ).called(1);
      });

      test('throws BadRequestException for Stripe provider', () {
        final stripeTransaction = transaction.copyWith(
          provider: StoreProvider.stripe,
        );

        expect(
          () => service.verifyAndProcessPurchase(
            user: testUser,
            transaction: stripeTransaction,
          ),
          throwsA(isA<BadRequestException>()),
        );
      });
    });

    group('handleAppleNotification', () {
      final transactionInfo = AppleTransactionDecodedPayload(
        originalTransactionId: 'orig-trans-id',
        transactionId: 'trans-id',
        productId: 'prod-id',
        purchaseDate: DateTime.now(),
        originalPurchaseDate: DateTime.now(),
        expiresDate: DateTime.now().add(const Duration(days: 30)),
        type: 'Auto-Renewable Subscription',
        inAppOwnershipType: 'PURCHASED',
      );

      final notificationPayload = AppleNotificationPayload(
        notificationType: AppleNotificationType.didRenew,
        notificationUUID: 'notif-uuid',
        version: '2.0',
        signedDate: DateTime.now(),
        data: const AppleNotificationData(
          signedTransactionInfo: 'signed-info',
          signedRenewalInfo: 'signed-renewal',
          bundleId: 'com.example',
          environment: AppleEnvironment.sandbox,
        ),
      );

      test('updates subscription and user on DID_RENEW notification', () async {
        when(
          () => mockIdempotencyService.isEventProcessed(any()),
        ).thenAnswer((_) async => false);
        when(
          () => mockAppStoreClient.decodeTransaction(any()),
        ).thenReturn(transactionInfo);
        final existingSub = UserSubscription(
          id: 'sub-1',
          userId: testUser.id,
          tier: AccessTier.standard,
          status: SubscriptionStatus.expired,
          provider: StoreProvider.apple,
          validUntil: DateTime.now().subtract(const Duration(days: 1)),
          originalTransactionId: transactionInfo.originalTransactionId,
          willAutoRenew: false,
        );
        when(
          () => mockUserSubscriptionRepository.readAll(
            filter: any(named: 'filter'),
          ),
        ).thenAnswer(
          (_) async => PaginatedResponse(
            items: [existingSub],
            cursor: null,
            hasMore: false,
          ),
        );
        when(
          () => mockUserRepository.read(id: testUser.id),
        ).thenAnswer((_) async => testUser);

        await service.handleAppleNotification(notificationPayload);

        final capturedSub =
            verify(
                  () => mockUserSubscriptionRepository.update(
                    id: existingSub.id,
                    item: captureAny(named: 'item'),
                  ),
                ).captured.first
                as UserSubscription;
        expect(capturedSub.status, SubscriptionStatus.active);

        final capturedUser =
            verify(
                  () => mockUserRepository.update(
                    id: testUser.id,
                    item: captureAny(named: 'item'),
                  ),
                ).captured.first
                as User;
        expect(capturedUser.tier, AccessTier.premium);

        verify(
          () => mockIdempotencyService.recordEvent(
            notificationPayload.notificationUUID,
          ),
        ).called(1);
      });
    });
  });
}
