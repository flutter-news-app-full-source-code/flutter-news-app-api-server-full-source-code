import 'package:dart_frog/dart_frog.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/middlewares/data_fetch_middleware.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/middlewares/ownership_check_middleware.dart';

/// Middleware specific to the item-level `/api/v1/data/[id]` route path.
///
/// This middleware chain is responsible for fetching the requested data item
/// and then performing an ownership check on it.
///
/// The execution order is as follows:
/// 1. `dataFetchMiddleware`: This runs first. It fetches the item by its ID
///    from the database and provides it to the context. If the item is not
///    found, it throws a `NotFoundException`, aborting the request.
/// 2. `ownershipCheckMiddleware`: This runs second. It reads the fetched item
///    from the context and verifies that the authenticated user is the owner,
///    if the model's configuration requires such a check.
///
/// This ensures that the final route handler only executes for valid,
/// authorized requests and can safely assume the requested item exists.
Handler middleware(Handler handler) {
  // The middleware is applied in reverse order of execution.
  // `ownershipCheckMiddleware` is the inner middleware, running after
  // `dataFetchMiddleware`.
  return handler
      .use(ownershipCheckMiddleware()) // Runs second
      .use(dataFetchMiddleware()); // Runs first
}
