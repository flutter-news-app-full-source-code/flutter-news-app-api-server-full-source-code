import 'package:core/core.dart';

/// {@template ingestion_candidate}
/// A transient data transfer object used during the ingestion process.
///
/// It wraps the domain [Headline] model with additional context (like the
/// raw description) that is necessary for AI analysis but is not persisted
/// directly in the [Headline] entity itself.
/// {@endtemplate}
class IngestionCandidate {
  /// {@macro ingestion_candidate}
  const IngestionCandidate({
    required this.headline,
    required this.rawDescription,
  });

  /// The headline model intended for persistence.
  final Headline headline;

  /// The raw description text from the provider, used for AI context extraction.
  final String? rawDescription;
}
