import 'package:ht_data_repository/ht_data_repository.dart';
import 'package:ht_shared/ht_shared.dart';

/// {@template dashboard_summary_service}
/// A service responsible for calculating the dashboard summary data on demand.
///
/// This service aggregates data from various repositories to provide a
/// real-time overview of key metrics in the system.
/// {@endtemplate}
class DashboardSummaryService {
  /// {@macro dashboard_summary_service}
  const DashboardSummaryService({
    required HtDataRepository<Headline> headlineRepository,
    required HtDataRepository<Topic> topicRepository,
    required HtDataRepository<Source> sourceRepository,
  }) : _headlineRepository = headlineRepository,
       _topicRepository = topicRepository,
       _sourceRepository = sourceRepository;

  final HtDataRepository<Headline> _headlineRepository;
  final HtDataRepository<Topic> _topicRepository;
  final HtDataRepository<Source> _sourceRepository;

  /// Calculates and returns the current dashboard summary.
  ///
  /// This method fetches the counts of all items from the required
  /// repositories and constructs a [DashboardSummary] object.
  Future<DashboardSummary> getSummary() async {
    // Use Future.wait to fetch all counts in parallel for efficiency.
    final results = await Future.wait([
      _headlineRepository.count(),
      _topicRepository.count(),
      _sourceRepository.count(),
    ]);

    // The results are integers.
    final headlineCount = results[0];
    final topicCount = results[1];
    final sourceCount = results[2];

    return DashboardSummary(
      id: 'dashboard_summary', // Fixed ID for the singleton summary
      headlineCount: headlineCount,
      topicCount: topicCount,
      sourceCount: sourceCount,
    );
  }
}
