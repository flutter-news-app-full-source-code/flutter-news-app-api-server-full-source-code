import 'package:flutter_news_app_backend_api_full_source_code/src/database/migration.dart';
import 'package:flutter_news_app_backend_api_full_source_code/src/services/database_migration_service.dart'
    show DatabaseMigrationService;

/// A central list of all database migrations to be applied.
///
/// New migration classes should be added to this list. The
/// [DatabaseMigrationService] will automatically sort and apply them based
/// on their `prDate` property.
final List<Migration> allMigrations = [];
