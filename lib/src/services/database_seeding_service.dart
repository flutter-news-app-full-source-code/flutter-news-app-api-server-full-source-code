import 'package:logging/logging.dart';
import 'package:postgres/postgres.dart';

/// {@template database_seeding_service}
/// A service responsible for initializing the database schema and seeding it
/// with initial data.
///
/// This service is intended to be run at application startup, particularly
/// in development environments or during the first run of a production instance
/// to set up the initial admin user and default configuration.
/// {@endtemplate}
class DatabaseSeedingService {
  /// {@macro database_seeding_service}
  const DatabaseSeedingService({
    required Connection connection,
    required Logger log,
  }) : _connection = connection,
       _log = log;

  final Connection _connection;
  final Logger _log;

  // Methods for table creation and data seeding will be added here.
}
