// lib/features/auth/domain/usecases/get_current_user_usecase.dart

import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../data/models/user_model.dart';
import '../repositories/auth_repository.dart';

class GetCurrentUserUseCase {
  final AuthRepository repository;

  GetCurrentUserUseCase(this.repository);

  Future<Either<Failure, UserModel?>> call() async {
    return await repository.getCurrentUser();
  }
}