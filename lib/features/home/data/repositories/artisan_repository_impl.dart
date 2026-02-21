import 'package:dartz/dartz.dart';
import '../../domain/entities/artisan_entity.dart';
import '../../domain/repositories/artisan_repository.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../datasources/artisan_remote_datasource.dart';

class ArtisanRepositoryImpl implements ArtisanRepository {
  final ArtisanRemoteDataSource remoteDataSource;

  ArtisanRepositoryImpl({required this.remoteDataSource, required Object networkInfo});

  @override
  Future<Either<Failure, List<ArtisanEntity>>> getFeaturedArtisans({
    int limit = 10,
  }) async {
    try {
      final artisans = await remoteDataSource.getFeaturedArtisans(
        limit: limit,
      );
      return Right(artisans.map((model) => model.toEntity()).toList());
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: 'Unexpected error: $e'));
    }
  }

  @override
  Future<Either<Failure, List<ArtisanEntity>>> getNearbyArtisans({
    required double latitude,
    required double longitude,
    String? category,
    double? maxDistance,
    double? radiusKm,
    int? limit,
    int? offset,
  }) async {
    try {
      final artisans = await remoteDataSource.getNearbyArtisans(
        latitude: latitude,
        longitude: longitude,
        category: category,
        radiusKm: radiusKm ?? 10.0,
        limit: limit = 20,
        offset: offset = 0,
      );
      return Right(artisans.map((model) => model.toEntity()).toList());
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: 'Unexpected error: $e'));
    }
  }

  @override
  Future<Either<Failure, List<ArtisanEntity>>> searchArtisans({
    required String query,
    String? category,
    double? latitude,
    double? longitude,
    double? maxDistance,
    int? limit,
    int? offset, double? minRating,
  }) async {
    try {
      final artisans = await remoteDataSource.searchArtisans(
        query: query,
        category: category,
        
        limit: limit = 20,
      );
      return Right(artisans.map((model) => model.toEntity()).toList());
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: 'Unexpected error: $e'));
    }
  }

  @override
  Future<Either<Failure, ArtisanEntity>> getArtisanById(String id) async {
    try {
      final artisan = await remoteDataSource.getArtisanById(id);
      return Right(artisan.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: 'Unexpected error: $e'));
    }
  }
}
