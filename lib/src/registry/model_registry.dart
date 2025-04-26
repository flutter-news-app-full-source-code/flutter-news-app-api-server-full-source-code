//
// ignore_for_file: strict_raw_type

import 'package:dart_frog/dart_frog.dart';
import 'package:ht_data_client/ht_data_client.dart';
// HtDataRepository import is no longer needed here
import 'package:ht_shared/ht_shared.dart';

/// {@template model_config}
/// Configuration holder for a specific data model type [T].
///
/// Contains the necessary functions (serialization, ID extraction)
/// required to handle requests for this model type within the
/// generic `/data` endpoint.
/// {@endtemplate}
class ModelConfig<T> {
  /// {@macro model_config}
  const ModelConfig({
    required this.fromJson,
    required this.toJson,
    required this.getId,
    // repositoryProvider removed
  });

  /// Function to deserialize JSON into an object of type [T].
  final FromJson<T> fromJson;

  /// Function to serialize an object of type [T] into JSON.
  final ToJson<T> toJson;

  /// Function to extract the unique string ID from an item of type [T].
  final String Function(T item) getId;

  // repositoryProvider field removed
}

// Repository providers are no longer defined here.
// They will be created and provided directly in the main dependency setup.

/// {@template model_registry}
/// Central registry mapping model name strings (used in API query params)
/// to their corresponding [ModelConfig] instances.
///
/// This registry is used by the middleware to look up the correct configuration
/// and repository based on the `?model=` query parameter.
/// {@endtemplate}
final modelRegistry = <String, ModelConfig>{
  'headline': ModelConfig<Headline>(
    fromJson: Headline.fromJson,
    toJson: (h) => h.toJson(),
    getId: (h) => h.id,
  ),
  'category': ModelConfig<Category>(
    fromJson: Category.fromJson,
    toJson: (c) => c.toJson(),
    getId: (c) => c.id,
  ),
  'source': ModelConfig<Source>(
    fromJson: Source.fromJson,
    toJson: (s) => s.toJson(),
    getId: (s) => s.id,
  ),
  // Add entry for Country model
  'country': ModelConfig<Country>(
    fromJson: Country.fromJson,
    toJson: (c) => c.toJson(),
    getId: (c) => c.id, // Assuming Country has an 'id' field
  ),
};

/// Type alias for the ModelRegistry map for easier provider usage.
typedef ModelRegistryMap = Map<String, ModelConfig>;

/// Dart Frog provider function factory for the entire [modelRegistry].
///
/// This makes the registry available for injection, primarily for the
/// middleware responsible for resolving the model type.
final modelRegistryProvider = provider<ModelRegistryMap>(
  (_) => modelRegistry,
); // Use lowercase provider function for setup
