// lib/features/profile/domain/usecases/update_privacy_settings_usecase.dart
import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/privacy_settings_entity.dart';
import '../repositories/profile_repository.dart';

class UpdatePrivacySettingsUseCase {
  final ProfileRepository repository;

  UpdatePrivacySettingsUseCase(this.repository);

  Future<Either<Failure, void>> call(
    String userId,
    PrivacySettingsEntity settings,
  ) async {
    return await repository.updatePrivacySettings(userId, settings);
  }
}
