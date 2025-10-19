import 'package:core/core.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:data_repository/data_repository.dart';
import 'package:email_repository/email_repository.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/config/app_dependencies.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/middlewares/error_handler.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/models/request_id.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/rbac/permission_service.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/registry/data_operation_registry.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/registry/model_registry.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/auth_service.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/auth_token_service.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/country_query_service.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/dashboard_summary_service.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/rate_limit_service.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/token_blacklist_service.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/user_preference_limit_service.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/verification_code_storage_service.dart';
import 'package:logging/logging.dart';
import 'package:mongo_dart/mongo_dart.dart';

// --- Middleware Definition ---
final _log = Logger('RootMiddleware');

Handler middleware(Handler handler) {
  // This is the root middleware for the entire API. It's responsible for
  // providing all shared dependencies to the request context.
  // The order of `.use()` calls is important: the last one in the chain
  // runs first.

  return handler
      // --- Core Middleware ---
      // These run after all dependencies have been provided.
      .use(errorHandler())
      .use(requestLogger())
      // --- Request ID Provider ---
      // This middleware provides a unique ID for each request for tracing.
      // It depends on the Uuid provider, so it must come after it.
      .use((innerHandler) {
        return (context) {
          _log.info(
            '[REQ_LIFECYCLE] Request received. Generating RequestId...',
          );
          final requestId = RequestId(ObjectId().oid);
          _log.info('[REQ_LIFECYCLE] RequestId generated: ${requestId.id}');
          return innerHandler(context.provide<RequestId>(() => requestId));
        };
      })
      // --- Dependency Provider ---
      // This is the outermost middleware. It runs once per request, before any
      // other middleware. It's responsible for providing all dependencies,
      // which are guaranteed to be pre-initialized by the eager-loading
      // entrypoint (`bin/main.dart`), to the request context.
      .use((handler) {
        return (context) async {
          // Provide all dependencies to the inner handler.
          // The AppDependencies instance is a singleton that has already been
          // initialized at application startup.
          final deps = AppDependencies.instance;
          _log.finer('Providing pre-initialized dependencies to context.');

          return handler
              .use(
                provider<DataOperationRegistry>((_) => DataOperationRegistry()),
              )
              .use(provider<ModelRegistryMap>((_) => modelRegistry))
              .use(
                provider<DataRepository<Headline>>(
                  (_) => deps.headlineRepository,
                ),
              ) //
              .use(provider<DataRepository<Topic>>((_) => deps.topicRepository))
              .use(
                provider<DataRepository<Source>>((_) => deps.sourceRepository),
              ) //
              .use(
                provider<DataRepository<Country>>(
                  (_) => deps.countryRepository,
                ),
              ) //
              .use(
                provider<DataRepository<Language>>(
                  (_) => deps.languageRepository,
                ),
              ) //
              .use(
                provider<DataRepository<User>>((_) => deps.userRepository),
              ) //
              .use(
                provider<DataRepository<UserAppSettings>>(
                  (_) => deps.userAppSettingsRepository,
                ),
              )
              .use(
                provider<DataRepository<UserContentPreferences>>(
                  (_) => deps.userContentPreferencesRepository,
                ),
              )
              .use(
                provider<DataRepository<RemoteConfig>>(
                  (_) => deps.remoteConfigRepository,
                ),
              )
              .use(
                provider<DataRepository<LocalAd>>(
                  (_) => deps.localAdRepository,
                ),
              )
              .use(provider<EmailRepository>((_) => deps.emailRepository))
              .use(
                provider<TokenBlacklistService>(
                  (_) => deps.tokenBlacklistService,
                ),
              )
              .use(provider<AuthTokenService>((_) => deps.authTokenService))
              .use(
                provider<VerificationCodeStorageService>(
                  (_) => deps.verificationCodeStorageService,
                ),
              )
              .use(provider<AuthService>((_) => deps.authService))
              .use(
                provider<DashboardSummaryService>(
                  (_) => deps.dashboardSummaryService,
                ),
              )
              .use(provider<PermissionService>((_) => deps.permissionService))
              .use(
                provider<UserPreferenceLimitService>(
                  (_) => deps.userPreferenceLimitService,
                ),
              )
              .use(provider<RateLimitService>((_) => deps.rateLimitService))
              .use(
                provider<CountryQueryService>((_) => deps.countryQueryService),
              )
              .call(context);
        };
      });
}
