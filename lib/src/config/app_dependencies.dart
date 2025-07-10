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
  late final HtDataRepository<Topic> topicRepository;
  late final HtDataRepository<Source> sourceRepository;
  late final HtDataRepository<Country> countryRepository;
  late final HtDataRepository<User> userRepository;
  late final HtDataRepository<UserAppSettings> userAppSettingsRepository;
  late final HtDataRepository<UserContentPreferences>
      userContentPreferencesRepository;
  late final HtDataRepository<RemoteConfig> remoteConfigRepository;

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
      // The HtDataPostgresClient returns DateTime objects from TIMESTAMPTZ
      // columns. The Headline.fromJson factory expects ISO 8601 strings.
      // This handler converts them before deserialization.
      (json) => Headline.fromJson(_convertTimestampsToString(json)),
      (headline) {
        final json = headline.toJson();
        // The database expects foreign key IDs, not nested objects.
        // We extract the IDs and remove the original objects.
        json['source_id'] = headline.source.id;
        json['topic_id'] = headline.topic.id;
        json['event_country_id'] = headline.eventCountry.id;
        json.remove('source');
        json.remove('topic');
        json.remove('eventCountry');
        return json;
      },
    );
    topicRepository = _createRepository(
      connection,
      'topics',
      (json) => Topic.fromJson(_convertTimestampsToString(json)),
      (topic) => topic.toJson(),
    );
    sourceRepository = _createRepository(
      connection,
      'sources',
      (json) => Source.fromJson(_convertTimestampsToString(json)),
      (source) {
        final json = source.toJson();
        // The database expects headquarters_country_id, not a nested object.
        json['headquarters_country_id'] = source.headquarters.id;
        json.remove('headquarters');
        return json;
      },
    );
    countryRepository = _createRepository(
      connection,
      'countries',
      (json) => Country.fromJson(_convertTimestampsToString(json)),
      (country) => country.toJson(),
    );
    userRepository = _createRepository(
      connection,
      'users',
      (json) => User.fromJson(_convertTimestampsToString(json)),
      (user) {
        final json = user.toJson();
        // Convert enums to their string names for the database.
        json['app_role'] = user.appRole.name;
        json['dashboard_role'] = user.dashboardRole.name;
        // The `feed_action_status` map must be JSON encoded for the JSONB column.
        json['feed_action_status'] = jsonEncode(json['feed_action_status']);
        return json;
      },
    );
    userAppSettingsRepository = _createRepository(
      connection,
      'user_app_settings',
      UserAppSettings.fromJson,
      (settings) {
        final json = settings.toJson();
        // These fields are complex objects and must be JSON encoded for the DB.
        json['display_settings'] = jsonEncode(json['display_settings']);
        json['feed_preferences'] = jsonEncode(json['feed_preferences']);
        return json;
      },
    );
    userContentPreferencesRepository = _createRepository(
      connection,
      'user_content_preferences',
      UserContentPreferences.fromJson,
      (preferences) {
        final json = preferences.toJson();
        // These fields are lists of complex objects and must be JSON encoded.
        json['followed_topics'] = jsonEncode(json['followed_topics']);
        json['followed_sources'] = jsonEncode(json['followed_sources']);
        json['followed_countries'] = jsonEncode(json['followed_countries']);
        json['saved_headlines'] = jsonEncode(json['saved_headlines']);
        return json;
      },
    );
    remoteConfigRepository = _createRepository(
      connection,
      'remote_config',
      (json) => RemoteConfig.fromJson(_convertTimestampsToString(json)),
      (config) {
        final json = config.toJson();
        // All nested config objects must be JSON encoded for JSONB columns.
        json['user_preference_limits'] =
            jsonEncode(json['user_preference_limits']);
        json['ad_config'] = jsonEncode(json['ad_config']);
        json['account_action_config'] =
            jsonEncode(json['account_action_config']);
        json['app_status'] = jsonEncode(json['app_status']);
        return json;
      },
    );

    // 4. Initialize Services.
    emailRepository = const HtEmailRepository(
      emailClient: HtEmailInMemoryClient(),
    );
    tokenBlacklistService = InMemoryTokenBlacklistService(
      log: _log,
    );
    authTokenService = JwtAuthTokenService(
      userRepository: userRepository,
      blacklistService: tokenBlacklistService,
      uuidGenerator: const Uuid(),
      log: _log,
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
      log: _log,
    );
    dashboardSummaryService = DashboardSummaryService(
      headlineRepository: headlineRepository,
      topicRepository: topicRepository,
      sourceRepository: sourceRepository,
    );
    permissionService = const PermissionService();
    userPreferenceLimitService =
        DefaultUserPreferenceLimitService(remoteConfigRepository: remoteConfigRepository, log: _log,);
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

  /// Converts DateTime values in a JSON map to ISO 8601 strings.
  ///
  /// The postgres driver returns DateTime objects for TIMESTAMPTZ columns,
  /// but our models' `fromJson` factories expect ISO 8601 strings. This
  /// utility function performs the conversion for known timestamp fields.
  Map<String, dynamic> _convertTimestampsToString(Map<String, dynamic> json) {
    const timestampKeys = {'created_at', 'updated_at'};
    final newJson = Map<String, dynamic>.from(json);
    for (final key in timestampKeys) {
      if (newJson[key] is DateTime) {
        newJson[key] = (newJson[key] as DateTime).toIso8601String();
      }
    }
    return newJson;
  }
}
