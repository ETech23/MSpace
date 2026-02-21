// lib/features/home/domain/repositories/artisan_repository.dart

import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/artisan_entity.dart';

abstract class ArtisanRepository {
  Future<Either<Failure, List<ArtisanEntity>>> getFeaturedArtisans({required int limit});

  Future<Either<Failure, List<ArtisanEntity>>> getNearbyArtisans({
    required double latitude,
    required double longitude,
    String? category,
    double? maxDistance,
    double? radiusKm,
    int? limit,
    int? offset,
  });

  Future<Either<Failure, List<ArtisanEntity>>> searchArtisans({
    required String query,
    String? category,
    double? latitude,
    double? longitude,
    double? maxDistance,
    int? limit,
    int? offset, double? minRating,
  });

  Future<Either<Failure, ArtisanEntity>> getArtisanById(String id);
}
