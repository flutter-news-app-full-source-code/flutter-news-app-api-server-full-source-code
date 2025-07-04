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
    required HtDataRepository<Category> categoryRepository,
    required HtDataRepository<Source> sourceRepository,
  }) : _headlineRepository = headlineRepository,
       _categoryRepository = categoryRepository,
       _sourceRepository = sourceRepository;

  final HtDataRepository<Headline> _headlineRepository;
  final HtDataRepository<Category> _categoryRepository;
  final HtDataRepository<Source> _sourceRepository;

  /// Calculates and returns the current dashboard summary.
  ///
  /// This method fetches all items from the required repositories to count them
  /// and constructs a [DashboardSummary] object.
  Future<DashboardSummary> getSummary() async {
    // Use Future.wait to fetch all counts in parallel for efficiency.
    final results = await Future.wait([
      _headlineRepository.readAll(),
      _categoryRepository.readAll(),
      _sourceRepository.readAll(),
    ]);

    // The results are PaginatedResponse objects.
    final headlineResponse = results[0] as PaginatedResponse<Headline>;
    final categoryResponse = results[1] as PaginatedResponse<Category>;
    final sourceResponse = results[2] as PaginatedResponse<Source>;

    return DashboardSummary(
      id: 'dashboard_summary', // Fixed ID for the singleton summary
      headlineCount: headlineResponse.items.length,
      categoryCount: categoryResponse.items.length,
      sourceCount: sourceResponse.items.length,
    );
  }
}
