import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/error/failures.dart';
import '../../../home/domain/entities/artisan_entity.dart';
import '../repositories/search_repository.dart';

class FuzzySearchParams extends Equatable {
  final String query;
  final String? category;
  final String? city;
  final double? minRating;
  final double? maxDistance;
  final double? userLat;
  final double? userLng;
  final int? limit;
  final int? offset;

  const FuzzySearchParams({
    required this.query,
    this.category,
    this.city,
    this.minRating,
    this.maxDistance,
    this.userLat,
    this.userLng,
    this.limit,
    this.offset,
  });

  @override
  List<Object?> get props => [
        query, category, city, minRating,
        maxDistance, userLat, userLng, limit, offset,
      ];
}

class FuzzySearchUseCase {
  final SearchRepository repository;

  FuzzySearchUseCase(this.repository);

  Future<Either<Failure, List<ArtisanEntity>>> call(FuzzySearchParams params) {
    return repository.fuzzySearchArtisans(
      query: params.query,
      category: params.category,
      city: params.city,
      minRating: params.minRating,
      maxDistance: params.maxDistance,
      userLat: params.userLat,
      userLng: params.userLng,
      limit: params.limit,
      offset: params.offset,
    );
  }
}
