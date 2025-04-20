import 'package:dart_frog/dart_frog.dart';
import 'package:ht_api/src/middleware/error_handler.dart'; // Import error handler
import 'package:ht_api/src/providers/countries_client_provider.dart';
import 'package:ht_countries_client/ht_countries_client.dart'
    show HtCountriesClient; // Import client provider

/// Applies global middleware to the entire application.
///
/// This middleware chain:
/// 1. Provides the [HtCountriesClient] instance to the context.
/// 2. Handles errors using the centralized [errorHandler].
///
/// The order is important: the error handler needs to wrap the provider
/// and subsequent route handlers to catch exceptions from them.
Handler middleware(Handler handler) {
  return handler
      // Inject the HtCountriesClient instance into the request context.
      .use(countriesClientProvider())
      // Apply the centralized error handling middleware.
      // This should generally be one of the outermost middlewares
      // to catch errors from providers and route handlers.
      .use(errorHandler());

  // You could add other global middleware here, like logging:
  // .use(requestLogger())
}
