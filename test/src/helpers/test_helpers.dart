import 'dart:convert';

import 'package:core/core.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:dart_frog_test/dart_frog_test.dart';
import 'package:data_repository/data_repository.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/middlewares/ownership_check_middleware.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/models/request_id.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/rbac/permission_service.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/registry/data_operation_registry.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/registry/model_registry.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/auth_token_service.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/country_query_service.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/rate_limit_service.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/user_action_limit_service.dart';
import 'package:mocktail/mocktail.dart';

class MockRequestContext extends Mock implements RequestContext {}

class MockRequest extends Mock implements Request {}

class MockUri extends Mock implements Uri {}

class MockPermissionService extends Mock implements PermissionService {}

class MockAuthTokenService extends Mock implements AuthTokenService {}

class MockRateLimitService extends Mock implements RateLimitService {}

class MockUserActionLimitService extends Mock
    implements UserActionLimitService {}

class MockDataOperationRegistry extends Mock implements DataOperationRegistry {}

class MockDataRepository<T> extends Mock implements DataRepository<T> {}

class MockHeadlineRepository extends MockDataRepository<Headline> {}

class MockUserRepository extends MockDataRepository<User> {}

class MockEngagementRepository extends MockDataRepository<Engagement> {}

class MockAppReviewRepository extends MockDataRepository<AppReview> {}

class MockUserContentPreferencesRepository
    extends MockDataRepository<UserContentPreferences> {}

/// Registers common fallback values for Mocktail.
/// Call this in `setUpAll` of your test files.
void registerSharedFallbackValues() {
  registerFallbackValue(const Duration(seconds: 1));
  registerFallbackValue(Uri.parse('http://localhost'));
  registerFallbackValue(HttpMethod.get);
  registerFallbackValue(
    User(
      id: 'fallback-user-id',
      email: 'fallback@example.com',
      appRole: AppUserRole.standardUser,
      dashboardRole: DashboardUserRole.none,
      createdAt: DateTime.now(),
      feedDecoratorStatus: const {},
    ),
  );
  registerFallbackValue(
    Engagement(
      id: 'fallback-engagement-id',
      userId: 'fallback-user-id',
      entityId: 'fallback-entity-id',
      entityType: EngageableType.headline,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      reaction: const Reaction(reactionType: ReactionType.like),
    ),
  );
  registerFallbackValue(
    const UserContentPreferences(
      id: 'fallback-prefs-id',
      followedCountries: [],
      followedSources: [],
      followedTopics: [],
      savedHeadlines: [],
      savedHeadlineFilters: [],
      savedSourceFilters: [],
    ),
  );
}

/// A proxy implementation of [RequestContext] that delegates to another context.
///
/// This is used to wrap the context returned by [TestRequestContext].
/// The internal mock in `dart_frog_test` may define a `provide` method that
/// shadows the `dart_frog` extension method. By using this proxy (which does
/// NOT define `provide`), we force Dart to use the extension method, ensuring
/// that `context.provide(...)` correctly creates a `_ProviderRequestContext`
/// while still delegating `read()` calls to the test harness.
class ProxyRequestContext implements RequestContext {
  /// Creates a [ProxyRequestContext] that delegates to [delegate].
  ProxyRequestContext(this.delegate, [this._providers = const {}]);

  /// The underlying context (usually from [TestRequestContext]).
  final RequestContext delegate;

  final Map<Type, dynamic> _providers;

  @override
  Request get request => delegate.request;

  @override
  Map<String, String> get mountedParams => delegate.mountedParams;

  @override
  RequestContext provide<T>(T Function() create) {
    return ProxyRequestContext(delegate, {
      ..._providers,
      T: create(),
    });
  }

  @override
  T read<T>() {
    if (_providers.containsKey(T)) {
      return _providers[T] as T;
    }
    return delegate.read<T>();
  }
}

/// A helper function to create a mock [RequestContext] with provided values.
RequestContext createMockRequestContext({
  Request? request,
  HttpMethod method = HttpMethod.get,
  Map<String, String> headers = const {},
  Map<String, String> queryParams = const {},
  String path = '/',
  dynamic body,
  User? authenticatedUser,
  ModelConfig<dynamic>? modelConfig,
  String? modelName,
  PermissionService? permissionService,
  AuthTokenService? authTokenService,
  RateLimitService? rateLimitService,
  UserActionLimitService? userActionLimitService,
  DataOperationRegistry? dataOperationRegistry,
  FetchedItem<dynamic>? fetchedItem,
  DataRepository<User>? userRepository,
  DataRepository<Engagement>? engagementRepository,
  DataRepository<AppReview>? appReviewRepository,
  DataRepository<UserContentPreferences>? userContentPreferencesRepository,
  CountryQueryService? countryQueryService,
}) {
  // If a request object is provided, extract values from it.
  var effectiveMethod = method;
  var effectivePath = path;
  var effectiveHeaders = headers;

  if (request != null) {
    effectiveMethod = request.method;
    effectivePath = request.uri.toString();
    effectiveHeaders = request.headers;
  }

  // Append query params to path if not already present
  if (queryParams.isNotEmpty) {
    final uri = Uri.parse(effectivePath);
    final newUri = uri.replace(
      queryParameters: {...uri.queryParameters, ...queryParams},
    );
    effectivePath = newUri.toString();
  }

  // Handle body encoding
  Object? requestBody = body;
  if (body is Map || body is List) {
    requestBody = jsonEncode(body);
  }

  // Use TestRequestContext from dart_frog_test
  final testContext = TestRequestContext(
    path: effectivePath,
    method: effectiveMethod,
    headers: effectiveHeaders,
    body: requestBody,
  );

  // Provide dependencies using the wrapper's provide method.
  // These are set up on the underlying mock so that read<T>() works.
  testContext.provide<RequestId>(const RequestId('test-request-id'));
  testContext.provide<ModelRegistryMap>(modelRegistry);

  if (authenticatedUser != null) {
    testContext.provide<User?>(authenticatedUser);
    testContext.provide<User>(authenticatedUser);
  }
  if (modelConfig != null) {
    testContext.provide<ModelConfig<dynamic>>(modelConfig);
  }
  if (modelName != null) {
    testContext.provide<String>(modelName);
  }

  // --- Infrastructure Services (Batteries Included) ---
  // Ensure these are always provided with safe defaults if not passed.

  // PermissionService
  final effectivePermissionService =
      permissionService ?? MockPermissionService();
  if (permissionService == null) {
    // Default stubs to prevent "Null is not subtype of bool" errors
    when(
      () => effectivePermissionService.hasPermission(any(), any()),
    ).thenReturn(true);
    when(() => effectivePermissionService.isAdmin(any())).thenReturn(true);
  }
  testContext.provide<PermissionService>(effectivePermissionService);

  // RateLimitService
  final effectiveRateLimitService = rateLimitService ?? MockRateLimitService();
  if (rateLimitService == null) {
    when(
      () => effectiveRateLimitService.checkRequest(
        key: any(named: 'key'),
        limit: any(named: 'limit'),
        window: any(named: 'window'),
      ),
    ).thenAnswer((_) async {});
  }
  testContext.provide<RateLimitService>(effectiveRateLimitService);

  // UserActionLimitService
  final effectiveUserActionLimitService =
      userActionLimitService ?? MockUserActionLimitService();
  if (userActionLimitService == null) {
    when(
      () => effectiveUserActionLimitService.checkEngagementCreationLimit(
        user: any(named: 'user'),
        engagement: any(named: 'engagement'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => effectiveUserActionLimitService.checkReportCreationLimit(
        user: any(named: 'user'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => effectiveUserActionLimitService.checkUserContentPreferencesLimits(
        user: any(named: 'user'),
        updatedPreferences: any(named: 'updatedPreferences'),
      ),
    ).thenAnswer((_) async {});
  }
  testContext.provide<UserActionLimitService>(effectiveUserActionLimitService);

  // --- Optional Services ---

  if (authTokenService != null) {
    testContext.provide<AuthTokenService>(authTokenService);
  }

  if (dataOperationRegistry != null) {
    testContext.provide<DataOperationRegistry>(dataOperationRegistry);
  }
  if (fetchedItem != null) {
    testContext.provide<FetchedItem<dynamic>>(fetchedItem);
  }
  if (userRepository != null) {
    testContext.provide<DataRepository<User>>(userRepository);
  }
  if (engagementRepository != null) {
    testContext.provide<DataRepository<Engagement>>(engagementRepository);
  }
  if (appReviewRepository != null) {
    testContext.provide<DataRepository<AppReview>>(appReviewRepository);
  }
  if (userContentPreferencesRepository != null) {
    testContext.provide<DataRepository<UserContentPreferences>>(
      userContentPreferencesRepository,
    );
  }
  if (countryQueryService != null) {
    testContext.provide<CountryQueryService>(countryQueryService);
  }

  // Return the ProxyRequestContext to ensure extension methods work correctly.
  return ProxyRequestContext(testContext.context);
}

/// Creates a [User] instance for testing purposes with sensible defaults.
User createTestUser({
  String id = 'user-id',
  String email = 'test@example.com',
  AppUserRole appRole = AppUserRole.standardUser,
  DashboardUserRole dashboardRole = DashboardUserRole.none,
}) {
  return User(
    id: id,
    email: email,
    appRole: appRole,
    dashboardRole: dashboardRole,
    createdAt: DateTime.now(),
    feedDecoratorStatus: const {},
  );
}
