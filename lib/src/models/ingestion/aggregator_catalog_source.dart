import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

/// {@template aggregator_catalog_source}
/// A strongly-typed DTO representing a source supported by an external provider.
/// Used during the "Discovery" phase to match internal sources.
/// {@endtemplate}
@immutable
class AggregatorCatalogSource extends Equatable {
  /// {@macro aggregator_catalog_source}
  const AggregatorCatalogSource({
    required this.externalId,
    required this.name,
    this.url,
    this.description,
  });

  /// The unique ID used by the provider.
  final String externalId;

  /// The display name of the source.
  final String name;

  /// The homepage URL of the source (crucial for host-based matching).
  final String? url;

  /// A brief description provided by the aggregator.
  final String? description;

  @override
  List<Object?> get props => [externalId, name, url, description];
}
