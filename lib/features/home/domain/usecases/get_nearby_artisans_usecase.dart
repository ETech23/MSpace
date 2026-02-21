import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/artisan_entity.dart';
import '../repositories/artisan_repository.dart';

class GetNearbyArtisansUseCase {
  final ArtisanRepository repository;

  GetNearbyArtisansUseCase(this.repository);

  Future<Either<Failure, List<ArtisanEntity>>> call({
    required double latitude,
    required double longitude,
    required double radiusKm,
    int limit = 20,
    int offset = 0,
  }) async {
    return await repository.getNearbyArtisans(
      latitude: latitude,
      longitude: longitude,
      radiusKm: radiusKm,
      limit: limit,
      offset: offset,
    );
  }
}