// lib/features/profile/domain/usecases/unsave_artisan_usecase.dart
import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../repositories/profile_repository.dart';

class UnsaveArtisanUseCase {
  final ProfileRepository repository;

  UnsaveArtisanUseCase(this.repository);

  Future<Either<Failure, void>> call(
    String userId,
    String artisanId,
  ) async {
    return await repository.unsaveArtisan(userId, artisanId);
  }
}