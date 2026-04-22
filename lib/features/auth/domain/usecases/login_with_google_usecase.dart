import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../data/models/user_model.dart';
import '../repositories/auth_repository.dart';

class LoginWithGoogleUseCase {
  final AuthRepository repository;

  LoginWithGoogleUseCase(this.repository);

  Future<Either<Failure, UserModel>> call({String? preferredUserType}) async {
    return await repository.loginWithGoogle(preferredUserType: preferredUserType);
  }
}
