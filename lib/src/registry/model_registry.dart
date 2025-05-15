//
// ignore_for_file: strict_raw_type, lines_longer_than_80_chars

import 'package:dart_frog/dart_frog.dart';
import 'package:ht_data_client/ht_data_client.dart';
import 'package:ht_shared/ht_shared.dart';

/// Defines the ownership type of a data model and associated access rules.
enum ModelOwnership {
  /// Indicates the resource is fully managed by admins (only admins can
  /// Create, Read, Update, Delete).
  adminOwned,

  /// Indicates the resource is managed by admins (only admins can Create,
  /// Update, Delete), but read operations (GET) are allowed for all
  /// authenticated users.
  adminOwnedReadAllowed,

  /// Indicates the resource is owned by a specific user (only the owning user
  /// or an admin can Create, Read, Update, Delete).
  userOwned,
}

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
    required this.getId,
    required this.ownership, // New field
  });

  /// Function to deserialize JSON into an object of type [T].
  final FromJson<T> fromJson;

  /// Function to extract the unique string ID from an item of type [T].
  final String Function(T item) getId;

  /// The ownership type of this model.
  final ModelOwnership ownership;
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
final modelRegistry = <String, ModelConfig<dynamic>>{
  'headline': ModelConfig<Headline>(
    fromJson: Headline.fromJson,
    getId: (h) => h.id,
    ownership: ModelOwnership.adminOwnedReadAllowed, // Updated ownership
  ),
  'category': ModelConfig<Category>(
    fromJson: Category.fromJson,
    getId: (c) => c.id,
    ownership: ModelOwnership.adminOwnedReadAllowed, // Updated ownership
  ),
  'source': ModelConfig<Source>(
    fromJson: Source.fromJson,
    getId: (s) => s.id,
    ownership: ModelOwnership.adminOwnedReadAllowed, // Updated ownership
  ),
  'country': ModelConfig<Country>(
    fromJson: Country.fromJson,
    getId: (c) => c.id, // Assuming Country has an 'id' field
    ownership: ModelOwnership.adminOwnedReadAllowed, // Updated ownership
  ),
};

/// Type alias for the ModelRegistry map for easier provider usage.
typedef ModelRegistryMap = Map<String, ModelConfig<dynamic>>;

/// Dart Frog provider function factory for the entire [modelRegistry].
///
/// This makes the `modelRegistry` map available for injection into the
/// request context via `context.read<ModelRegistryMap>()`. It's primarily
/// used by the middleware in `routes/api/v1/data/_middleware.dart`.
final modelRegistryProvider = provider<ModelRegistryMap>(
  (_) => modelRegistry,
); // Use lowercase provider function for setup
