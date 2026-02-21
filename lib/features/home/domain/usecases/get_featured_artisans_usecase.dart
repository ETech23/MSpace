import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/artisan_entity.dart';
import '../repositories/artisan_repository.dart';

class GetFeaturedArtisansUseCase {
  final ArtisanRepository repository;

  GetFeaturedArtisansUseCase(this.repository);

  Future<Either<Failure, List<ArtisanEntity>>> call({
    int limit = 10,
  }) async {
    return await repository.getFeaturedArtisans(limit: limit);
  }
}