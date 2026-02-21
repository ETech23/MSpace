// lib/features/profile/domain/usecases/get_notification_settings_usecase.dart
import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/notification_settings_entity.dart';
import '../repositories/profile_repository.dart';

class GetNotificationSettingsUseCase {
  final ProfileRepository repository;

  GetNotificationSettingsUseCase(this.repository);

  Future<Either<Failure, NotificationSettingsEntity>> call(
    String userId,
  ) async {
    return await repository.getNotificationSettings(userId);
  }
}