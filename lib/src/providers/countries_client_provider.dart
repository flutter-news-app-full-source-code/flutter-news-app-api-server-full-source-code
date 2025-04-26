// import 'package:dart_frog/dart_frog.dart';
// import 'package:ht_countries_client/ht_countries_client.dart';
// import 'package:ht_countries_inmemory/ht_countries_inmemory.dart';

// /// Provides an instance of [HtCountriesClient] to the request context.
// ///
// /// This middleware uses the inmemory implementation
// /// [HtCountriesInMemoryClient].
// Middleware countriesClientProvider() {
//   // Create the client instance once when the middleware is initialized.
//   // This assumes the in-memory client is cheap to create and can be reused
//   // across requests.
//   final HtCountriesClient client = HtCountriesInMemoryClient();

//   return (Handler innerHandler) {
//     return (RequestContext context) {
//       // Provide the existing client instance to this request's context.
//       final updatedContext = context.provide<HtCountriesClient>(()=> client);
//       // Call the next handler in the chain with the updated context.
//       return innerHandler(updatedContext);
//     };
//   };
// }
