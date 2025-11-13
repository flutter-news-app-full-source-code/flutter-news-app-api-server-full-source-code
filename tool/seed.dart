import 'dart:io';

import 'package:args/args.dart';
import 'package:data_mongodb/data_mongodb.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/config/environment_config.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/database_seeding_service.dart';
import 'package:logging/logging.dart';

/// A command-line tool for seeding the database with fixture data on demand.
///
/// This tool provides a flexible way to populate the database with specific
/// sets of data (e.g., topics, sources, headlines) or all fixtures at once,
/// which is useful for development, testing, and staging environments.
/// It is idempotent by default but can perform destructive cleaning operations
/// with the `--clean` flag.
///
/// Usage:
///   dart run tool/seed.dart --resource=topics
///   dart run tool/seed.dart --all
///   dart run tool/seed.dart --clean --all
///
/// Options:
///   --resource: Seeds a specific resource. Can be one of:
///               [topics, sources, headlines, users].
///               This option can be used multiple times.
///   --all:      Seeds all available fixture resources.
///   --clean:    Deletes all existing documents in the specified collection(s)
///               before seeding. Use with caution.
///   --help:     Shows this usage information.
Future<void> main(List<String> args) async {
  // --- Logger Setup ---
  // Configures a logger to provide detailed feedback during the seeding process.
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
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
  final log = Logger('SeedTool');

  // --- Argument Parsing ---
  // Sets up the command-line argument parser to understand the tool's options.
  final parser = ArgParser()
    ..addMultiOption(
      'resource',
      abbr: 'r',
      help: 'Specifies the resource to seed.',
      allowed: ['topics', 'sources', 'headlines', 'users'],
    )
    ..addFlag('all', abbr: 'a', help: 'Seeds all available resources.')
    ..addFlag(
      'help',
      abbr: 'h',
      negatable: false,
      help: 'Shows this usage information.',
    );

  final argResults = parser.parse(args);

  // --- Help Flag Handling ---
  if (argResults['help'] as bool) {
    log.info('Database Seeding Tool\n${parser.usage}');
    exit(0);
  }

  // --- Confirmation Prompt for Destructive Operations ---
  final resourcesToSeed = argResults['resource'] as List<String>;
  final seedAll = argResults['all'] as bool;
  final useClean = argResults['clean'] as bool;

  if (useClean && (resourcesToSeed.isNotEmpty || seedAll)) {
    final target = seedAll ? 'ALL' : resourcesToSeed.join(', ').toUpperCase();
    log.warning('--- DESTRUCTIVE OPERATION WARNING ---');
    log.warning(
      'You are about to DELETE ALL documents from the following collections: $target.',
    );
    log.warning('This action cannot be undone.');
    stdout.write('Are you sure you want to continue? (yes/no): ');

    final confirmation = stdin.readLineSync();
    if (confirmation?.toLowerCase() != 'yes') {
      log.info('Operation cancelled by user.');
      exit(0);
    }
    log.info('Confirmation received. Proceeding with destructive operation...');
  } else if (resourcesToSeed.isEmpty && !seedAll) {
    // No valid arguments provided.
    log.warning('No resources specified. Use --all or --resource.');
    log.info('Usage:\n${parser.usage}');
    exit(1);
  }

  // --- Dependency Initialization and Seeding Logic ---
  MongoDbConnectionManager? mongoDbConnectionManager;
  try {
    // 1. Initialize Database Connection
    // The EnvironmentConfig class automatically loads .env file variables.
    mongoDbConnectionManager = MongoDbConnectionManager();
    await mongoDbConnectionManager.init(EnvironmentConfig.databaseUrl);
    log.info('Successfully connected to the database.');

    // 2. Instantiate the Seeding Service
    final seedingService = DatabaseSeedingService(
      db: mongoDbConnectionManager.db,
      log: Logger('DatabaseSeedingService'),
    );

    // 3. Execute Seeding Based on Arguments
    if (seedAll) {
      // --all flag takes precedence.
      if (useClean) {
        await seedingService.cleanAllFixtures();
      }
      log.info('Seeding all fixture resources...');
      await seedingService.seedAllFixtures();
    } else if (resourcesToSeed.isNotEmpty) {
      // Seed specific resources.
      log.info('Seeding specified resources: ${resourcesToSeed.join(', ')}');
      for (final resource in resourcesToSeed) {
        switch (resource) {
          case 'topics':
            if (useClean) await seedingService.cleanTopics();
            await seedingService.seedTopics();
          case 'sources':
            if (useClean) await seedingService.cleanSources();
            await seedingService.seedSources();
          case 'headlines':
            if (useClean) await seedingService.cleanHeadlines();
            await seedingService.seedHeadlines();
          case 'users':
            if (useClean) await seedingService.cleanUsers();
            await seedingService.seedUsers();
        }
      }
    }

    log.info('On-demand seeding process completed successfully.');
  } on Exception catch (e, s) {
    log.severe('An error occurred during the seeding process.', e, s);
    exit(1);
  } finally {
    // --- Resource Cleanup ---
    // Ensures the database connection is always closed, even if errors occur.
    if (mongoDbConnectionManager != null) {
      log.info('Closing database connection...');
      await mongoDbConnectionManager.close();
      log.info('Database connection closed.');
    }
  }
}
