// Dart Frog Dependency Injection Pattern: Individual Providers
//
// This directory (`lib/src/providers`) and files like this one demonstrate
// a common pattern in Dart Frog for providing dependencies using dedicated
// middleware for each specific dependency (e.g., a client or repository).
//
// Example (Conceptual - Code Removed):
// ```dart
// // Middleware countriesClientProvider() {
// //   final HtCountriesClient client = HtCountriesInMemoryClient();
// //   return provider<HtCountriesClient>((_) => client);
// // }
// ```
// This middleware would then be `.use()`d in a relevant `_middleware.dart` file.
//
// --- Why This Pattern Isn't Used for Core Data Models in THIS Project ---
//
// While the individual provider pattern is valid, this specific project uses a
// slightly different approach for its main data models (Headline, Category, etc.)
// to support the generic `/api/v1/data` endpoint.
//
// Instead of individual provider middleware files here:
// 1. Instances of the core data repositories (`HtDataRepository<Headline>`,
//    `HtDataRepository<Category>`, etc.) are created and provided directly
//    within the top-level `routes/_middleware.dart` file.
// 2. A `modelRegistry` (`lib/src/registry/model_registry.dart`) is used in
//    conjunction with middleware at `routes/api/v1/data/_middleware.dart` to
//    dynamically determine which model and repository to use based on the
//    `?model=` query parameter in requests to `/api/v1/data`.
//
// This centralized approach in `routes/_middleware.dart` and the use of the
// registry were chosen to facilitate the generic nature of the `/api/v1/data`
// endpoint.
//
// This `providers` directory is kept primarily as a reference to the standard
// individual provider pattern or for potential future use with dependencies
// that don't fit the generic data model structure.
