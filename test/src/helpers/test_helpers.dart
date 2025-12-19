import 'package:core/core.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:data_repository/data_repository.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/middlewares/ownership_check_middleware.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/rbac/permission_service.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/registry/data_operation_registry.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/registry/model_registry.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/auth_token_service.dart';
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

/// A helper function to create a mock [RequestContext] with provided values.
RequestContext createMockRequestContext({
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
}) {
  final request = MockRequest();
  final uri = MockUri();
  when(() => request.method).thenReturn(method);
  when(() => request.headers).thenReturn(headers);
  when(() => request.uri).thenReturn(uri);
  when(() => uri.queryParameters).thenReturn(queryParams);
  when(() => uri.path).thenReturn(path);
  when(
    () => uri.pathSegments,
  ).thenReturn(path.split('/')..removeWhere((s) => s.isEmpty));

  if (body != null) {
    when(request.json).thenAnswer((_) async => body);
  }

  final context = MockRequestContext();
  when(() => context.request).thenReturn(request);

  // Provide a default empty map for dependencies that might be read.
  when(() => context.read<Map<String, dynamic>>()).thenReturn({});

  // Stub the read method for specific types.
  when(() => context.read<User?>()).thenReturn(authenticatedUser);
  if (authenticatedUser != null) {
    when(() => context.read<User>()).thenReturn(authenticatedUser);
  }

  if (modelConfig != null) {
    when(() => context.read<ModelConfig<dynamic>>()).thenReturn(modelConfig);
  }
  if (modelName != null) {
    when(() => context.read<String>()).thenReturn(modelName);
  }
  if (permissionService != null) {
    when(() => context.read<PermissionService>()).thenReturn(permissionService);
  }
  if (authTokenService != null) {
    when(() => context.read<AuthTokenService>()).thenReturn(authTokenService);
  }
  if (rateLimitService != null) {
    when(() => context.read<RateLimitService>()).thenReturn(rateLimitService);
  }
  if (userActionLimitService != null) {
    when(
      () => context.read<UserActionLimitService>(),
    ).thenReturn(userActionLimitService);
  }
  if (dataOperationRegistry != null) {
    when(
      () => context.read<DataOperationRegistry>(),
    ).thenReturn(dataOperationRegistry);
  }
  if (fetchedItem != null) {
    when(() => context.read<FetchedItem<dynamic>>()).thenReturn(fetchedItem);
  }
  if (userRepository != null) {
    when(() => context.read<DataRepository<User>>()).thenReturn(userRepository);
  }
  if (engagementRepository != null) {
    when(
      () => context.read<DataRepository<Engagement>>(),
    ).thenReturn(engagementRepository);
  }
  if (appReviewRepository != null) {
    when(
      () => context.read<DataRepository<AppReview>>(),
    ).thenReturn(appReviewRepository);
  }
  if (userContentPreferencesRepository != null) {
    when(
      () => context.read<DataRepository<UserContentPreferences>>(),
    ).thenReturn(userContentPreferencesRepository);
  }

  // Allow providing new values to the context.
  when(() => context.provide<dynamic>(any())).thenReturn(context);

  return context;
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
