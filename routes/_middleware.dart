import 'package:core/core.dart';
import 'package:dart_frog/dart_frog.dart';

import 'package:flutter_news_app_backend_api_full_source_code/src/config/app_dependencies.dart';
import 'package:flutter_news_app_backend_api_full_source_code/src/config/environment_config.dart';
import 'package:flutter_news_app_backend_api_full_source_code/src/middlewares/error_handler.dart';
import 'package:flutter_news_app_backend_api_full_source_code/src/models/request_id.dart';
import 'package:flutter_news_app_backend_api_full_source_code/src/models/storage/local_media_finalization_job.dart';
import 'package:flutter_news_app_backend_api_full_source_code/src/models/storage/local_upload_token.dart';
import 'package:flutter_news_app_backend_api_full_source_code/src/rbac/permission_service.dart';
import 'package:flutter_news_app_backend_api_full_source_code/src/registry/data_operation_registry.dart';
import 'package:flutter_news_app_backend_api_full_source_code/src/registry/model_registry.dart';
import 'package:flutter_news_app_backend_api_full_source_code/src/services/auth_service.dart';
import 'package:flutter_news_app_backend_api_full_source_code/src/services/auth_token_service.dart';
import 'package:flutter_news_app_backend_api_full_source_code/src/services/country_query_service.dart';
import 'package:flutter_news_app_backend_api_full_source_code/src/services/email/email_service.dart';
import 'package:flutter_news_app_backend_api_full_source_code/src/services/google_auth_service.dart';
import 'package:flutter_news_app_backend_api_full_source_code/src/services/idempotency_service.dart';
import 'package:flutter_news_app_backend_api_full_source_code/src/services/media_service.dart';
import 'package:flutter_news_app_backend_api_full_source_code/src/services/push_notification/push_notification_service.dart';
import 'package:flutter_news_app_backend_api_full_source_code/src/services/rate_limit_service.dart';
import 'package:flutter_news_app_backend_api_full_source_code/src/services/reward/rewards_service.dart';
import 'package:flutter_news_app_backend_api_full_source_code/src/services/storage/i_storage_service.dart';
import 'package:flutter_news_app_backend_api_full_source_code/src/services/storage/local_media_finalization_job_service.dart';
import 'package:flutter_news_app_backend_api_full_source_code/src/services/storage/upload_token_service.dart';
import 'package:flutter_news_app_backend_api_full_source_code/src/services/token_blacklist_service.dart';
import 'package:flutter_news_app_backend_api_full_source_code/src/services/user_action_limit_service.dart';
import 'package:flutter_news_app_backend_api_full_source_code/src/services/verification_code_storage_service.dart';
import 'package:flutter_news_app_backend_api_full_source_code/src/util/gcs_jwt_verifier.dart';
import 'package:flutter_news_app_backend_api_full_source_code/src/util/sns_message_handler.dart';
import 'package:logging/logging.dart';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:shelf_cors_headers/shelf_cors_headers.dart' as shelf_cors;

// --- Middleware Definition ---
final _log = Logger('RootMiddleware');

// A flag to ensure the logger is only configured once for the application's
// entire lifecycle.
bool _loggerConfigured = false;

/// Checks if the request's origin is allowed based on the environment.
///
/// In production (when `CORS_ALLOWED_ORIGIN` is set), it performs a strict
/// check against the specified origin.
/// In development, it dynamically allows any `localhost` or `127.0.0.1`
/// origin to support the Flutter web dev server's random ports.
bool _isOriginAllowed(String origin) {
  _log.info('[CORS] Checking origin: "$origin"');
  final allowedOriginEnv = EnvironmentConfig.corsAllowedOrigin;

  if (allowedOriginEnv != null && allowedOriginEnv.isNotEmpty) {
    // Production: strict check against the environment variable.
    final isAllowed = origin == allowedOriginEnv;
    _log.info(
      '[CORS] Production check result: ${isAllowed ? 'ALLOWED' : 'DENIED'}',
    );
    return isAllowed;
  } else {
    // Development: dynamically allow any localhost origin.
    final isAllowed =
        origin.startsWith('http://localhost:') ||
        origin.startsWith('http://127.0.0.1:');
    _log.info(
      '[CORS] Development check result: ${isAllowed ? 'ALLOWED' : 'DENIED'}',
    );
    return isAllowed;
  }
}

Handler middleware(Handler handler) {
  // This is the root middleware for the entire API. It's responsible for
  // providing all shared dependencies to the request context.
  // The order of `.use()` calls is important: the last one in the chain
  // runs first.

  // This check ensures that the logger is configured only once.
  if (!_loggerConfigured) {
    Logger.root.level = Level.ALL;
    Logger.root.onRecord.listen((record) {
      // A more detailed logger that includes the error and stack trace.
      // ignore: avoid_print
      print(
        '${record.level.name}: ${record.time}: ${record.loggerName}: '
        '${record.message}',
      );
      if (record.error != null) {
        // ignore: avoid_print
        print('  ERROR: ${record.error}');
      }
      if (record.stackTrace != null) {
        // ignore: avoid_print
        print('  STACK TRACE: ${record.stackTrace}');
      }
    });
    _loggerConfigured = true;
  }

  return handler
      // --- Core Middleware ---
      // These run after all dependencies have been provided.
      .use(errorHandler())
      .use(requestLogger())
      // --- CORS Middleware ---
      // This is applied globally to all routes, including /media/[...].
      .use((handler) {
        final corsMiddleware = fromShelfMiddleware(
          shelf_cors.corsHeaders(
            originChecker: _isOriginAllowed,
            headers: {
              shelf_cors.ACCESS_CONTROL_ALLOW_CREDENTIALS: 'true',
              shelf_cors.ACCESS_CONTROL_ALLOW_METHODS:
                  'GET, POST, PUT, DELETE, OPTIONS',
              shelf_cors.ACCESS_CONTROL_ALLOW_HEADERS:
                  'Origin, Content-Type, Authorization, Accept',
              shelf_cors.ACCESS_CONTROL_MAX_AGE: '86400',
            },
          ),
        );
        return (context) {
          return corsMiddleware(handler)(context);
        };
      })
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
      // other middleware. It's responsible for initializing and providing all
      // dependencies for the request.
      .use((handler) {
        return (context) async {
          // 1. Ensure all dependencies are initialized (idempotent).
          _log.info('Ensuring all application dependencies are initialized...');
          await AppDependencies.instance.init();
          _log.info('Dependencies are ready.');

          // 2. Provide all dependencies to the inner handler.
          final deps = AppDependencies.instance;
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
              )
              .use(
                provider<DataRepository<UserContext>>(
                  (_) => deps.userContextRepository,
                ),
              ) //
              .use(
                provider<DataRepository<AppSettings>>(
                  (_) => deps.appSettingsRepository,
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
                provider<DataRepository<UserRewards>>(
                  (_) => deps.userRewardsRepository,
                ),
              )
              .use(
                provider<DataRepository<PushNotificationDevice>>(
                  (_) => deps.pushNotificationDeviceRepository,
                ),
              )
              .use(
                provider<DataRepository<InAppNotification>>(
                  (_) => deps.inAppNotificationRepository,
                ),
              )
              .use(
                provider<DataRepository<Engagement>>(
                  (_) => deps.engagementRepository,
                ),
              )
              .use(
                provider<DataRepository<Report>>(
                  (_) => deps.reportRepository,
                ),
              )
              .use(
                provider<DataRepository<AppReview>>(
                  (_) => deps.appReviewRepository,
                ),
              )
              .use(
                provider<DataRepository<LocalUploadToken>>(
                  (_) => deps.uploadTokenRepository,
                ),
              )
              .use(
                provider<DataRepository<KpiCardData>>(
                  (_) => deps.kpiCardDataRepository,
                ),
              )
              .use(
                provider<DataRepository<ChartCardData>>(
                  (_) => deps.chartCardDataRepository,
                ),
              )
              .use(
                provider<DataRepository<RankedListCardData>>(
                  (_) => deps.rankedListCardDataRepository,
                ),
              )
              .use(
                provider<DataRepository<LocalMediaFinalizationJob>>(
                  (_) => deps.localMediaFinalizationJobRepository,
                ),
              )
              .use(
                provider<IPushNotificationService>(
                  (_) => deps.pushNotificationService,
                ),
              )
              .use(
                provider<IGoogleAuthService?>(
                  (_) => deps.googleAuthService,
                ),
              )
              .use(provider<EmailService>((_) => deps.emailService))
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
              .use(provider<PermissionService>((_) => deps.permissionService))
              .use(
                provider<UserActionLimitService>(
                  (_) => deps.userActionLimitService,
                ),
              )
              .use(provider<RateLimitService>((_) => deps.rateLimitService))
              .use(
                provider<CountryQueryService>((_) => deps.countryQueryService),
              )
              .use(provider<RewardsService>((_) => deps.rewardsService))
              .use(provider<MediaService>((_) => deps.mediaService))
              .use(
                provider<DataRepository<MediaAsset>>(
                  (_) => deps.mediaAssetRepository,
                ),
              )
              .use(provider<IStorageService>((_) => deps.storageService))
              .use(provider<IGcsJwtVerifier>((_) => deps.gcsJwtVerifier))
              .use(provider<SnsMessageHandler>((_) => deps.snsMessageHandler))
              .use(provider<IdempotencyService>((_) => deps.idempotencyService))
              .use(
                provider<UploadTokenService>((_) => deps.uploadTokenService),
              )
              .use(
                provider<LocalMediaFinalizationJobService>(
                  (_) => deps.finalizationJobService,
                ),
              )
              .call(context);
        };
      });
}
