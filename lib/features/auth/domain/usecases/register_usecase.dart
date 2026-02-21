import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/user_entity.dart';
import '../repositories/auth_repository.dart';

class RegisterUseCase {
  final AuthRepository repository;

  RegisterUseCase(this.repository);

  Future<Either<Failure, UserEntity>> call({
    required String email,
    required String password,
    required String name,
    required String phone,
    required String userType,
    double? latitude,   // ✅ ADD
    double? longitude,  // ✅ ADD
    String? address,    // ✅ ADD
  }) async {
    return await repository.register(
      email: email,
      password: password,
      name: name,
      phone: phone,
      userType: userType,
      latitude: latitude,
      longitude: longitude,
      address: address,
    );
  }
}