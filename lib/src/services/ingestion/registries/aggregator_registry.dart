import 'package:verity_api/src/models/ingestion/aggregator_type.dart';
import 'package:verity_api/src/registry/data_operation_registry.dart'
    show DataOperationRegistry;
import 'package:verity_api/src/registry/registry.dart'
    show DataOperationRegistry;
import 'package:verity_api/src/services/ingestion/providers/aggregator_provider.dart';

/// {@template aggregator_registry}
/// A centralized registry for news aggregator providers.
///
/// Following the pattern of [DataOperationRegistry], this class decouples
/// the orchestration logic from specific provider implementations.
/// {@endtemplate}
class AggregatorRegistry {
  final Map<AggregatorType, AggregatorProvider> _providers = {};

  /// Retrieves the provider associated with the given [type].
  AggregatorProvider getProvider(AggregatorType type) {
    final provider = _providers[type];
    if (provider == null) {
      throw StateError('No aggregator provider registered for type: $type');
    }
    return provider;
  }

  /// Registers a provider implementation for a specific [type].
  void register(AggregatorType type, AggregatorProvider provider) {
    _providers[type] = provider;
  }
}
