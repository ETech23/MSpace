// lib/features/profile/domain/usecases/get_saved_artisans_usecase.dart
import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/saved_artisan_entity.dart';
import '../repositories/profile_repository.dart';

class GetSavedArtisansUseCase {
  final ProfileRepository repository;

  GetSavedArtisansUseCase(this.repository);

  Future<Either<Failure, List<SavedArtisanEntity>>> call(String userId) async {
    return await repository.getSavedArtisans(userId);
  }
}