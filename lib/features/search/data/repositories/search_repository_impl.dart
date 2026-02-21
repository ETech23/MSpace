// lib/features/search/data/repositories/search_repository_impl.dart

import 'package:dartz/dartz.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../../home/domain/entities/artisan_entity.dart';
import '../../domain/repositories/search_repository.dart';
import '../../presentation/providers/search_provider.dart';
import '../datasources/search_remote_datasource.dart';

class SearchRepositoryImpl implements SearchRepository {
  final SearchRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;

  SearchRepositoryImpl({
    required this.remoteDataSource,
    required this.networkInfo,
  });

  @override
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
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure());
    }

    try {
      final results = await remoteDataSource.fuzzySearchArtisans(
        query: query,
        category: category,
        city: city,
        minRating: minRating,
        maxDistance: maxDistance,
        userLat: userLat,
        userLng: userLng,
        limit: limit ?? 30,
        offset: offset ?? 0,
      );
      return Right(results);
    } on ServerException {
      return const Left(ServerFailure());
    } catch (e) {
      return const Left(ServerFailure());
    }
  }

  @override
  Future<Either<Failure, List<SearchSuggestion>>> getSearchSuggestions(
    String query,
  ) async {
    if (!await networkInfo.isConnected) {
      return const Right([]); // Fail silently for suggestions
    }

    try {
      final suggestions = await remoteDataSource.getSearchSuggestions(query);
      return Right(suggestions);
    } catch (_) {
      return const Right([]); // Fail silently
    }
  }

  @override
  Future<Either<Failure, String>> logSearchAnalytics({
    required String query,
    required Map<String, dynamic> filters,
    required int resultsCount,
    required int durationMs,
  }) async {
    try {
      final id = await remoteDataSource.logSearchAnalytics(
        query: query,
        filters: filters,
        resultsCount: resultsCount,
        durationMs: durationMs,
      );
      return Right(id);
    } catch (_) {
      return const Left(ServerFailure());
    }
  }

  @override
  Future<Either<Failure, void>> logSearchClick(
    String searchId,
    String artisanId,
  ) async {
    try {
      await remoteDataSource.logSearchClick(searchId, artisanId);
      return const Right(null);
    } catch (_) {
      return const Left(ServerFailure());
    }
  }

  @override
  Future<Either<Failure, List<String>>> getPopularSearches() async {
    try {
      final searches = await remoteDataSource.getPopularSearches();
      return Right(searches);
    } catch (_) {
      return const Right([]);
    }
  }
}