// lib/features/profile/domain/usecases/update_profile_usecase.dart
import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../entities/profile_update_entity.dart';
import '../repositories/profile_repository.dart';

class UpdateProfileUseCase {
  final ProfileRepository repository;

  UpdateProfileUseCase(this.repository);

  Future<Either<Failure, UserEntity>> call(
    String userId,
    ProfileUpdateEntity updates,
  ) async {
    return await repository.updateProfile(userId, updates);
  }
}