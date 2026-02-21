// lib/features/profile/domain/usecases/upload_profile_photo_usecase.dart
import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../repositories/profile_repository.dart';

class UploadProfilePhotoUseCase {
  final ProfileRepository repository;

  UploadProfilePhotoUseCase(this.repository);

  Future<Either<Failure, String>> call(
    String userId,
    String filePath,
  ) async {
    return await repository.uploadProfilePhoto(userId, filePath);
  }
}