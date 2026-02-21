// lib/features/profile/domain/usecases/get_privacy_settings_usecase.dart
import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/privacy_settings_entity.dart';
import '../repositories/profile_repository.dart';

class GetPrivacySettingsUseCase {
  final ProfileRepository repository;

  GetPrivacySettingsUseCase(this.repository);

  Future<Either<Failure, PrivacySettingsEntity>> call(
    String userId,
  ) async {
    return await repository.getPrivacySettings(userId);
  }
}
