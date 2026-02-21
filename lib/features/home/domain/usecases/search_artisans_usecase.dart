// lib/features/home/domain/usecases/search_artisans_usecase.dart

import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/error/failures.dart';
import '../entities/artisan_entity.dart';
import '../repositories/artisan_repository.dart';

class SearchArtisansParams extends Equatable {
  final String query;
  final String? category;
  final double? latitude;
  final double? longitude;
  final double? maxDistance;
  final int? limit;
  final int? offset;

  const SearchArtisansParams({
    required this.query,
    this.category,
    this.latitude,
    this.longitude,
    this.maxDistance,
    this.limit,
    this.offset,
  });

  @override
  List<Object?> get props => [
        query,
        category,
        latitude,
        longitude,
        maxDistance,
        limit,
        offset,
      ];
}

class SearchArtisansUseCase {
  final ArtisanRepository repository;

  SearchArtisansUseCase(this.repository);

  Future<Either<Failure, List<ArtisanEntity>>> call(
    SearchArtisansParams params,
  ) async {
    return await repository.searchArtisans(
      query: params.query,
      category: params.category,
      latitude: params.latitude,
      longitude: params.longitude,
      maxDistance: params.maxDistance,
      limit: params.limit,
      offset: params.offset,
    );
  }
}