// lib/features/profile/domain/repositories/profile_repository.dart
import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../entities/profile_update_entity.dart';
import '../entities/notification_settings_entity.dart';
import '../entities/privacy_settings_entity.dart';
import '../entities/saved_artisan_entity.dart';

abstract class ProfileRepository {
  Future<Either<Failure, UserEntity>> updateProfile(
    String userId,
    ProfileUpdateEntity updates,
  );
  
  Future<Either<Failure, String>> uploadProfilePhoto(
    String userId,
    String filePath,
  );
  
  Future<Either<Failure, NotificationSettingsEntity>> getNotificationSettings(
    String userId,
  );
  
  Future<Either<Failure, void>> updateNotificationSettings(
    String userId,
    NotificationSettingsEntity settings,
  );
  
  Future<Either<Failure, PrivacySettingsEntity>> getPrivacySettings(
    String userId,
  );
  
  Future<Either<Failure, void>> updatePrivacySettings(
    String userId,
    PrivacySettingsEntity settings,
  );
  
  Future<Either<Failure, List<SavedArtisanEntity>>> getSavedArtisans(
    String userId,
  );
  
  Future<Either<Failure, void>> saveArtisan(
    String userId,
    String artisanId,
  );
  
  Future<Either<Failure, void>> unsaveArtisan(
    String userId,
    String artisanId,
  );
  
  Future<Either<Failure, bool>> isArtisanSaved(
    String userId,
    String artisanId,
  );
}