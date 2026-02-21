// lib/features/profile/domain/usecases/save_artisan_usecase.dart
import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../repositories/profile_repository.dart';

class SaveArtisanUseCase {
  final ProfileRepository repository;

  SaveArtisanUseCase(this.repository);

  Future<Either<Failure, void>> call(
    String userId,
    String artisanId,
  ) async {
    return await repository.saveArtisan(userId, artisanId);
  }
}