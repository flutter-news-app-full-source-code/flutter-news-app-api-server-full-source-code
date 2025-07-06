// ignore_for_file: public_member_api_docs

import 'package:ht_api/src/rbac/permission_service.dart';
import 'package:ht_api/src/services/auth_service.dart';
import 'package:ht_api/src/services/auth_token_service.dart';
import 'package:ht_api/src/services/dashboard_summary_service.dart';
import 'package:ht_api/src/services/token_blacklist_service.dart';
import 'package:ht_api/src/services/user_preference_limit_service.dart';
import 'package:ht_api/src/services/verification_code_storage_service.dart';
import 'package:ht_data_repository/ht_data_repository.dart';
import 'package:ht_email_repository/ht_email_repository.dart';
import 'package:ht_shared/ht_shared.dart';
import 'package:logging/logging.dart';

/// {@template dependency_container}
/// A singleton service locator for managing and providing access to all shared
/// application dependencies (repositories and services).
///
/// **Rationale for this pattern in Dart Frog:**
///
/// In Dart Frog, middleware defined in the `routes` directory is composed and
/// initialized *before* the custom `run` function in `lib/src/config/server.dart`
/// is executed. This creates a lifecycle challenge: if you try to provide
/// dependencies using `handler.use(provider<...>)` inside `server.dart`, any
/// middleware from the `routes` directory that needs those dependencies will
/// fail because it runs too early.
///
/// This `DependencyContainer` solves the problem by acting as a centralized,
/// globally accessible holder for all dependencies.
///
/// **The Dependency Injection Flow:**
///
/// 1.  **Initialization (`server.dart`):** The `run` function in `server.dart`
///     initializes all repositories and services.
/// 2.  **Population (`server.dart`):** It then calls `DependencyContainer.instance.init(...)`
///     to populate this singleton with the initialized instances. This happens
///     only once at server startup.
/// 3.  **Provision (`routes/_middleware.dart`):** The root middleware, which
///     runs for every request, accesses the initialized dependencies from
///     `DependencyContainer.instance` and uses `context.provide<T>()` to
///     inject them into the request's context.
/// 4.  **Consumption (Other Middleware/Routes):** All subsequent middleware
///     (like the authentication middleware) and route handlers can now safely
///     read the dependencies from the context using `context.read<T>()`.
///
/// This pattern ensures that dependencies are created once and are available
/// throughout the entire request lifecycle, respecting Dart Frog's execution
/// order.
/// {@endtemplate}
class DependencyContainer {
  // Private constructor for the singleton pattern.
  DependencyContainer._();

  /// The single, global instance of the [DependencyContainer].
  static final instance = DependencyContainer._();

  final _log = Logger('DependencyContainer');

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
  late final HtEmailRepository emailRepository;

  // --- Services ---
  late final TokenBlacklistService tokenBlacklistService;
  late final AuthTokenService authTokenService;
  late final VerificationCodeStorageService verificationCodeStorageService;
  late final AuthService authService;
  late final DashboardSummaryService dashboardSummaryService;
  late final PermissionService permissionService;
  late final UserPreferenceLimitService userPreferenceLimitService;

  /// Initializes the container with all the required dependencies.
  ///
  /// This method must be called exactly once at server startup from within
  /// the `run` function in `server.dart`.
  void init({
    required HtDataRepository<Headline> headlineRepository,
    required HtDataRepository<Category> categoryRepository,
    required HtDataRepository<Source> sourceRepository,
    required HtDataRepository<Country> countryRepository,
    required HtDataRepository<User> userRepository,
    required HtDataRepository<UserAppSettings> userAppSettingsRepository,
    required HtDataRepository<UserContentPreferences>
    userContentPreferencesRepository,
    required HtDataRepository<AppConfig> appConfigRepository,
    required HtEmailRepository emailRepository,
    required TokenBlacklistService tokenBlacklistService,
    required AuthTokenService authTokenService,
    required VerificationCodeStorageService verificationCodeStorageService,
    required AuthService authService,
    required DashboardSummaryService dashboardSummaryService,
    required PermissionService permissionService,
    required UserPreferenceLimitService userPreferenceLimitService,
  }) {
    this.headlineRepository = headlineRepository;
    this.categoryRepository = categoryRepository;
    this.sourceRepository = sourceRepository;
    this.countryRepository = countryRepository;
    this.userRepository = userRepository;
    this.userAppSettingsRepository = userAppSettingsRepository;
    this.userContentPreferencesRepository = userContentPreferencesRepository;
    this.appConfigRepository = appConfigRepository;
    this.emailRepository = emailRepository;
    this.tokenBlacklistService = tokenBlacklistService;
    this.authTokenService = authTokenService;
    this.verificationCodeStorageService = verificationCodeStorageService;
    this.authService = authService;
    this.dashboardSummaryService = dashboardSummaryService;
    this.permissionService = permissionService;
    this.userPreferenceLimitService = userPreferenceLimitService;

    _log.info('[INIT_SEQ] 6. Dependency container populated successfully.');
  }
}
