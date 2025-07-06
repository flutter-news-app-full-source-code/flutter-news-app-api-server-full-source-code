import 'dart:async';
import 'dart:convert';

import 'package:ht_api/src/config/database_connection.dart';
import 'package:ht_api/src/rbac/permission_service.dart';
import 'package:ht_api/src/services/auth_service.dart';
import 'package:ht_api/src/services/auth_token_service.dart';
import 'package:ht_api/src/services/dashboard_summary_service.dart';
import 'package:ht_api/src/services/database_seeding_service.dart';
import 'package:ht_api/src/services/default_user_preference_limit_service.dart';
import 'package:ht_api/src/services/jwt_auth_token_service.dart';
import 'package:ht_api/src/services/token_blacklist_service.dart';
import 'package:ht_api/src/services/user_preference_limit_service.dart';
import 'package:ht_api/src/services/verification_code_storage_service.dart';
import 'package:ht_data_client/ht_data_client.dart';
import 'package:ht_data_postgres/ht_data_postgres.dart';
import 'package:ht_data_repository/ht_data_repository.dart';
import 'package:ht_email_inmemory/ht_email_inmemory.dart';
import 'package:ht_email_repository/ht_email_repository.dart';
import 'package:ht_shared/ht_shared.dart';
import 'package:logging/logging.dart';
import 'package:postgres/postgres.dart';
import 'package:uuid/uuid.dart';

/// A singleton class to manage all application dependencies.
///
/// This class follows a lazy initialization pattern. Dependencies are created
/// only when the `init()` method is first called, typically triggered by the
/// first incoming request. A `Completer` ensures that subsequent requests
/// await the completion of the initial setup.
class AppDependencies {
  AppDependencies._();

  /// The single, global instance of the [AppDependencies].
  static final instance = AppDependencies._();

  final _log = Logger('AppDependencies');
  final _completer = Completer<void>();

  // --- Repositories ---
  late final HtDataRepository<Headline> headlineRepository;
  late final HtDataRepository<Category> categoryRepository;
  late final HtDataRepository<Source> sourceRepository;
  late final HtDataRepository<Country> countryRepository;
  late final HtDataRepository<User> userRepository;
  late final HtDataRepository<UserAppSettings> userAppSettingsRepository;
  late final HtDataRepository<UserContentPreferences>
  userContentPreferencesRepository;
  late final HtDataRepository<AppConfig> appConfigRepository;

  // --- Services ---
  late final HtEmailRepository emailRepository;
  late final TokenBlacklistService tokenBlacklistService;
  late final AuthTokenService authTokenService;
  late final VerificationCodeStorageService verificationCodeStorageService;
  late final AuthService authService;
  late final DashboardSummaryService dashboardSummaryService;
  late final PermissionService permissionService;
  late final UserPreferenceLimitService userPreferenceLimitService;

  /// Initializes all application dependencies.
  ///
  /// This method is idempotent. It performs the full initialization only on
  /// the first call. Subsequent calls will await the result of the first one.
  Future<void> init() {
    if (_completer.isCompleted) {
      _log.fine('Dependencies already initializing/initialized.');
      return _completer.future;
    }

    _log.info('Initializing application dependencies...');
    _init()
        .then((_) {
          _log.info('Application dependencies initialized successfully.');
          _completer.complete();
        })
        .catchError((Object e, StackTrace s) {
          _log.severe('Failed to initialize application dependencies.', e, s);
          _completer.completeError(e, s);
        });

    return _completer.future;
  }

  Future<void> _init() async {
    // 1. Establish Database Connection.
    await DatabaseConnectionManager.instance.init();
    final connection = await DatabaseConnectionManager.instance.connection;

    // 2. Run Database Seeding.
    final seedingService = DatabaseSeedingService(
      connection: connection,
      log: _log,
    );
    await seedingService.createTables();
    await seedingService.seedGlobalFixtureData();
    await seedingService.seedInitialAdminAndConfig();

    // 3. Initialize Repositories.
    headlineRepository = _createRepository(
      connection,
      'headlines',
      (json) {
        if (json['created_at'] is DateTime) {
          json['created_at'] =
              (json['created_at'] as DateTime).toIso8601String();
        }
        if (json['updated_at'] is DateTime) {
          json['updated_at'] =
              (json['updated_at'] as DateTime).toIso8601String();
        }
        if (json['published_at'] is DateTime) {
          json['published_at'] =
              (json['published_at'] as DateTime).toIso8601String();
        }
        return Headline.fromJson(json);
      },
      (h) => h.toJson(), // toJson already handles DateTime correctly
    );
    categoryRepository = _createRepository(
      connection,
      'categories',
      (json) {
        if (json['created_at'] is DateTime) {
          json['created_at'] =
              (json['created_at'] as DateTime).toIso8601String();
        }
        if (json['updated_at'] is DateTime) {
          json['updated_at'] =
              (json['updated_at'] as DateTime).toIso8601String();
        }
        return Category.fromJson(json);
      },
      (c) => c.toJson(),
    );
    sourceRepository = _createRepository(
      connection,
      'sources',
      (json) {
        if (json['created_at'] is DateTime) {
          json['created_at'] =
              (json['created_at'] as DateTime).toIso8601String();
        }
        if (json['updated_at'] is DateTime) {
          json['updated_at'] =
              (json['updated_at'] as DateTime).toIso8601String();
        }
        return Source.fromJson(json);
      },
      (s) => s.toJson(),
    );
    countryRepository = _createRepository(
      connection,
      'countries',
      (json) {
        if (json['created_at'] is DateTime) {
          json['created_at'] =
              (json['created_at'] as DateTime).toIso8601String();
        }
        if (json['updated_at'] is DateTime) {
          json['updated_at'] =
              (json['updated_at'] as DateTime).toIso8601String();
        }
        return Country.fromJson(json);
      },
      (c) => c.toJson(),
    );
    userRepository = _createRepository(
      connection,
      'users',
      (json) {
        // The postgres driver returns DateTime objects, but the model's
        // fromJson expects ISO 8601 strings. We must convert them first.
        if (json['created_at'] is DateTime) {
          json['created_at'] = (json['created_at'] as DateTime).toIso8601String();
        }
        if (json['last_engagement_shown_at'] is DateTime) {
          json['last_engagement_shown_at'] =
              (json['last_engagement_shown_at'] as DateTime).toIso8601String();
        }
        return User.fromJson(json);
      },
      (user) {
        // The `roles` field is a List<String>, but the database expects a
        // JSONB array. We must explicitly encode it.
        final json = user.toJson();
        json['roles'] = jsonEncode(json['roles']);
        return json;
      },
    );
    userAppSettingsRepository = _createRepository(
      connection,
      'user_app_settings',
      (json) {
        // The DB has created_at/updated_at, but the model doesn't.
        // Remove them before deserialization to avoid CheckedFromJsonException.
        json.remove('created_at');
        json.remove('updated_at');
        return UserAppSettings.fromJson(json);
      },
      (settings) {
        final json = settings.toJson();
        // These fields are complex objects and must be JSON encoded for the DB.
        json['display_settings'] = jsonEncode(json['display_settings']);
        json['feed_preferences'] = jsonEncode(json['feed_preferences']);
        json['engagement_shown_counts'] =
            jsonEncode(json['engagement_shown_counts']);
        json['engagement_last_shown_timestamps'] =
            jsonEncode(json['engagement_last_shown_timestamps']);
        return json;
      },
    );
    userContentPreferencesRepository = _createRepository(
      connection,
      'user_content_preferences',
      (json) {
        // The postgres driver returns DateTime objects, but the model's
        // fromJson expects ISO 8601 strings. We must convert them first.
        if (json['created_at'] is DateTime) {
          json['created_at'] =
              (json['created_at'] as DateTime).toIso8601String();
        }
        if (json['updated_at'] is DateTime) {
          json['updated_at'] =
              (json['updated_at'] as DateTime).toIso8601String();
        }
        return UserContentPreferences.fromJson(json);
      },
      (preferences) {
        final json = preferences.toJson();
        json['followed_categories'] = jsonEncode(json['followed_categories']);
        json['followed_sources'] = jsonEncode(json['followed_sources']);
        json['followed_countries'] = jsonEncode(json['followed_countries']);
        json['saved_headlines'] = jsonEncode(json['saved_headlines']);
        return json;
      },
    );
    appConfigRepository = _createRepository(
      connection,
      'app_config',
      (json) {
        if (json['created_at'] is DateTime) {
          json['created_at'] =
              (json['created_at'] as DateTime).toIso8601String();
        }
        if (json['updated_at'] is DateTime) {
          json['updated_at'] =
              (json['updated_at'] as DateTime).toIso8601String();
        }
        return AppConfig.fromJson(json);
      },
      (c) => c.toJson(),
    );

    // 4. Initialize Services.
    emailRepository = const HtEmailRepository(
      emailClient: HtEmailInMemoryClient(),
    );
    tokenBlacklistService = InMemoryTokenBlacklistService();
    authTokenService = JwtAuthTokenService(
      userRepository: userRepository,
      blacklistService: tokenBlacklistService,
      uuidGenerator: const Uuid(),
    );
    verificationCodeStorageService = InMemoryVerificationCodeStorageService();
    authService = AuthService(
      userRepository: userRepository,
      authTokenService: authTokenService,
      verificationCodeStorageService: verificationCodeStorageService,
      emailRepository: emailRepository,
      userAppSettingsRepository: userAppSettingsRepository,
      userContentPreferencesRepository: userContentPreferencesRepository,
      uuidGenerator: const Uuid(),
    );
    dashboardSummaryService = DashboardSummaryService(
      headlineRepository: headlineRepository,
      categoryRepository: categoryRepository,
      sourceRepository: sourceRepository,
    );
    permissionService = const PermissionService();
    userPreferenceLimitService = DefaultUserPreferenceLimitService(
      appConfigRepository: appConfigRepository,
    );
  }

  HtDataRepository<T> _createRepository<T>(
    Connection connection,
    String tableName,
    FromJson<T> fromJson,
    ToJson<T> toJson,
  ) {
    return HtDataRepository<T>(
      dataClient: HtDataPostgresClient<T>(
        connection: connection,
        tableName: tableName,
        fromJson: fromJson,
        toJson: toJson,
        log: _log,
      ),
    );
  }
}
