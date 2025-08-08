import 'package:core/core.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:data_repository/data_repository.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/middlewares/ownership_check_middleware.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/services/dashboard_summary_service.dart';
import 'package:logging/logging.dart';

final _log = Logger('DataFetchMiddleware');

/// Middleware to fetch a data item by its ID and provide it to the context.
///
/// This middleware is responsible for:
/// 1. Reading the `modelName` and item `id` from the context.
/// 2. Calling the appropriate data repository to fetch the item.
/// 3. If the item is found, providing it to the downstream context wrapped in a
///    [FetchedItem] for type safety.
/// 4. If the item is not found, throwing a [NotFoundException] to halt the
///    request pipeline early.
///
/// This centralizes the item fetching logic for all item-specific routes,
/// ensuring that subsequent middleware (like ownership checks) and the final
/// route handler can safely assume the item exists in the context.
Middleware dataFetchMiddleware() {
  return (handler) {
    return (context) async {
      final modelName = context.read<String>();
      final id = context.request.uri.pathSegments.last;

      _log.info('Fetching item for model "$modelName", id "$id".');

      final item = await _fetchItem(context, modelName, id);

      if (item == null) {
        _log.warning(
          'Item not found for model "$modelName", id "$id".',
        );
        throw NotFoundException(
          'The requested item of type "$modelName" with id "$id" was not found.',
        );
      }

      _log.finer('Item found. Providing to context.');
      final updatedContext = context.provide<FetchedItem<dynamic>>(
        () => FetchedItem(item),
      );

      return handler(updatedContext);
    };
  };
}

/// Helper function to fetch an item from the correct repository based on the
/// model name.
///
/// This function contains the switch statement that maps a `modelName` string
/// to a specific `DataRepository` call.
///
/// Throws [OperationFailedException] for unsupported model types.
Future<dynamic> _fetchItem(
  RequestContext context,
  String modelName,
  String id,
) async {
  // The `userId` is not needed here because this middleware's purpose is to
  // fetch the item regardless of ownership. Ownership is checked in a
  // subsequent middleware. We pass `null` for `userId` to ensure we are
  // performing a global lookup for the item.
  const String? userId = null;

  try {
    switch (modelName) {
      case 'headline':
        return await context.read<DataRepository<Headline>>().read(
              id: id,
              userId: userId,
            );
      case 'topic':
        return await context
            .read<DataRepository<Topic>>()
            .read(id: id, userId: userId);
      case 'source':
        return await context.read<DataRepository<Source>>().read(
              id: id,
              userId: userId,
            );
      case 'country':
        return await context.read<DataRepository<Country>>().read(
              id: id,
              userId: userId,
            );
      case 'language':
        return await context.read<DataRepository<Language>>().read(
              id: id,
              userId: userId,
            );
      case 'user':
        return await context
            .read<DataRepository<User>>()
            .read(id: id, userId: userId);
      case 'user_app_settings':
        return await context.read<DataRepository<UserAppSettings>>().read(
              id: id,
              userId: userId,
            );
      case 'user_content_preferences':
        return await context
            .read<DataRepository<UserContentPreferences>>()
            .read(
              id: id,
              userId: userId,
            );
      case 'remote_config':
        return await context.read<DataRepository<RemoteConfig>>().read(
              id: id,
              userId: userId,
            );
      case 'dashboard_summary':
        // This is a special case that doesn't use a standard repository.
        return await context.read<DashboardSummaryService>().getSummary();
      default:
        _log.warning('Unsupported model type "$modelName" for fetch operation.');
        throw OperationFailedException(
          'Unsupported model type "$modelName" for fetch operation.',
        );
    }
  } on NotFoundException {
    // The repository will throw this if the item doesn't exist.
    // We return null to let the main middleware handler throw a more
    // detailed exception.
    return null;
  } catch (e, s) {
    _log.severe(
      'Unhandled exception in _fetchItem for model "$modelName", id "$id".',
      e,
      s,
    );
    // Re-throw as a standard exception type that the main error handler
    // can process into a 500 error, while preserving the original cause.
    throw OperationFailedException(
      'An internal error occurred while fetching the item: $e',
    );
  }
}
