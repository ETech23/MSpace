// lib/features/profile/domain/usecases/get_user_profile_usecase.dart

import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/user_profile_entity.dart';
import '../repositories/user_profile_repository.dart';

class GetUserProfileUseCase {
  final UserProfileRepository repository;

  GetUserProfileUseCase({required this.repository});

  Future<Either<Failure, UserProfileEntity>> call({
    required String userId,
    required String userType,
  }) async {
    return await repository.getUserProfile(
      userId: userId,
      userType: userType,
    );
  }
}