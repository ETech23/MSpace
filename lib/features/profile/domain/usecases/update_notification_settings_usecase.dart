// lib/features/profile/domain/usecases/update_notification_settings_usecase.dart
import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/notification_settings_entity.dart';
import '../repositories/profile_repository.dart';

class UpdateNotificationSettingsUseCase {
  final ProfileRepository repository;

  UpdateNotificationSettingsUseCase(this.repository);

  Future<Either<Failure, void>> call(
    String userId,
    NotificationSettingsEntity settings,
  ) async {
    return await repository.updateNotificationSettings(userId, settings);
  }
}