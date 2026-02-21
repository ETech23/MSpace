// lib/features/profile/domain/usecases/is_artisan_saved_usecase.dart
import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../repositories/profile_repository.dart';

class IsArtisanSavedUseCase {
  final ProfileRepository repository;

  IsArtisanSavedUseCase(this.repository);

  Future<Either<Failure, bool>> call(
    String userId,
    String artisanId,
  ) async {
    return await repository.isArtisanSaved(userId, artisanId);
  }
}