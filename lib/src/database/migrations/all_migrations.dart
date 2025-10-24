import 'package:flutter_news_app_api_server_full_source_code/src/database/migration.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/database/migrations/20250924084800__refactor_ad_config_to_role_based.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/database/migrations/20251024000000_add_logo_url_to_sources.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/database/migrations/20251013000056_add_saved_filters_to_user_preferences.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/database/migrations/20251013000057_add_saved_filters_to_remote_config.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/database_migration_service.dart'
    show DatabaseMigrationService;

/// A central list of all database migrations to be applied.
///
/// New migration classes should be added to this list. The
/// [DatabaseMigrationService] will automatically sort and apply them based
/// on their `prDate` property.
final List<Migration> allMigrations = [
  RefactorAdConfigToRoleBased(),
  AddSavedFiltersToUserPreferences(),
  AddSavedFiltersToRemoteConfig(),
  AddLogoUrlToSources(),
];
