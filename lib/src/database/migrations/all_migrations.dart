import 'package:flutter_news_app_api_server_full_source_code/src/database/migration.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/database/migrations/20250924084800__refactor_ad_config_to_role_based.dart';

/// A central list of all database migrations to be applied.
///
/// New migration classes should be added to this list. The
/// [DatabaseMigrationService] will automatically sort and apply them based on
/// their `prDate` property.
final List<Migration> allMigrations = [
  RefactorAdConfigToRoleBased(),
];
