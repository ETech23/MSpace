// TODO Implement this library.
import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../home/domain/entities/artisan_entity.dart';
import '../../presentation/providers/search_provider.dart';

abstract class SearchRepository {
  /// Fuzzy search with typo tolerance, phonetic matching
  Future<Either<Failure, List<ArtisanEntity>>> fuzzySearchArtisans({
    required String query,
    String? category,
    String? city,
    double? minRating,
    double? maxDistance,
    double? userLat,
    double? userLng,
    int? limit,
    int? offset,
  });

  /// Get autocomplete suggestions
  Future<Either<Failure, List<SearchSuggestion>>> getSearchSuggestions(
    String query,
  );

  /// Log search for analytics
  Future<Either<Failure, String>> logSearchAnalytics({
    required String query,
    required Map<String, dynamic> filters,
    required int resultsCount,
    required int durationMs,
  });

  /// Log when user clicks a search result
  Future<Either<Failure, void>> logSearchClick(
    String searchId,
    String artisanId,
  );

  /// Get popular/trending searches
  Future<Either<Failure, List<String>>> getPopularSearches();
}