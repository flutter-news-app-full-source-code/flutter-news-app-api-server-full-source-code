import 'package:core/core.dart';
import 'package:data_repository/data_repository.dart';

/// {@template dashboard_summary_service}
/// A service responsible for calculating the dashboard summary data on demand.
///
/// This service aggregates data from various repositories to provide a
/// real-time overview of key metrics in the system.
/// {@endtemplate}
class DashboardSummaryService {
  /// {@macro dashboard_summary_service}
  const DashboardSummaryService({
    required DataRepository<Headline> headlineRepository,
    required DataRepository<Topic> topicRepository,
    required DataRepository<Source> sourceRepository,
  }) : _headlineRepository = headlineRepository,
       _topicRepository = topicRepository,
       _sourceRepository = sourceRepository;

  final DataRepository<Headline> _headlineRepository;
  final DataRepository<Topic> _topicRepository;
  final DataRepository<Source> _sourceRepository;

  /// Calculates and returns the current dashboard summary.
  ///
  /// This method fetches the counts of all items from the required
  /// repositories and constructs a [DashboardSummary] object.
  Future<DashboardSummary> getSummary() async {
    // Define a filter to count only documents with an 'active' status.
    // Using the enum's `name` property ensures type safety and consistency.
    final activeFilter = {'status': ContentStatus.active.name};

    // Use Future.wait to fetch all counts in parallel for efficiency.
    final results = await Future.wait([
      _headlineRepository.count(filter: activeFilter),
      _topicRepository.count(filter: activeFilter),
      _sourceRepository.count(filter: activeFilter),
    ]);

    // The results are integers.
    final headlineCount = results[0];
    final topicCount = results[1];
    final sourceCount = results[2];

    return DashboardSummary(
      id: 'dashboard_summary',
      headlineCount: headlineCount,
      topicCount: topicCount,
      sourceCount: sourceCount,
    );
  }
}
