//
// ignore_for_file: strict_raw_type

import 'package:dart_frog/dart_frog.dart';
import 'package:ht_data_client/ht_data_client.dart';
import 'package:ht_shared/ht_shared.dart';

/// {@template model_config}
/// Configuration holder for a specific data model type [T].
///
/// This class encapsulates the type-specific operations (like deserialization
/// from JSON and ID extraction) needed by the generic `/api/v1/data` endpoint
/// handlers. It allows those handlers to work with different data models
/// without needing explicit type checks for these common operations.
///
/// An instance of this config is looked up via the [modelRegistry] based on the
/// `?model=` query parameter provided in the request.
/// {@endtemplate}
class ModelConfig<T> {
  /// {@macro model_config}
  const ModelConfig({
    required this.fromJson,
    // toJson removed
    required this.getId,
  });

  /// Function to deserialize JSON into an object of type [T].
  final FromJson<T> fromJson;

  // toJson field removed

  /// Function to extract the unique string ID from an item of type [T].
  final String Function(T item) getId;
}

// Repository providers are no longer defined here.
// They will be created and provided directly in the main dependency setup.

/// {@template model_registry}
/// Central registry mapping model name strings (used in the `?model=` query parameter)
/// to their corresponding [ModelConfig] instances.
///
/// This registry is the core component enabling the generic `/api/v1/data` endpoint.
/// The middleware (`routes/api/v1/data/_middleware.dart`) uses this map to:
/// 1. Validate the `model` query parameter provided by the client.
/// 2. Retrieve the correct [ModelConfig] containing type-specific functions
///    (like `fromJson`) needed by the generic route handlers (`index.dart`, `[id].dart`).
///
/// While individual repositories (`HtDataRepository<Headline>`, etc.) are provided
/// directly in the main `routes/_middleware.dart`, this registry provides the
/// *metadata* needed to work with those repositories generically based on the
/// request's `model` parameter.
/// {@endtemplate}
final modelRegistry = <String, ModelConfig>{
  'headline': ModelConfig<Headline>(
    fromJson: Headline.fromJson,
    // toJson removed
    getId: (h) => h.id,
  ),
  'category': ModelConfig<Category>(
    fromJson: Category.fromJson,
    // toJson removed
    getId: (c) => c.id,
  ),
  'source': ModelConfig<Source>(
    fromJson: Source.fromJson,
    // toJson removed
    getId: (s) => s.id,
  ),
  'country': ModelConfig<Country>(
    fromJson: Country.fromJson,
    // toJson removed
    getId: (c) => c.id, // Assuming Country has an 'id' field
  ),
};

/// Type alias for the ModelRegistry map for easier provider usage.
typedef ModelRegistryMap = Map<String, ModelConfig>;

/// Dart Frog provider function factory for the entire [modelRegistry].
///
/// This makes the `modelRegistry` map available for injection into the
/// request context via `context.read<ModelRegistryMap>()`. It's primarily
/// used by the middleware in `routes/api/v1/data/_middleware.dart`.
final modelRegistryProvider = provider<ModelRegistryMap>(
  (_) => modelRegistry,
); // Use lowercase provider function for setup
