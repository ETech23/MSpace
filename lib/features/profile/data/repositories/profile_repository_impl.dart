// lib/features/profile/data/repositories/profile_repository_impl.dart
import 'package:dartz/dartz.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../../auth/domain/entities/user_entity.dart';

// ✅ FIXED: Import from separate entity files
import '../../domain/entities/profile_update_entity.dart';
import '../../domain/entities/notification_settings_entity.dart';
import '../../domain/entities/privacy_settings_entity.dart';
import '../../domain/entities/saved_artisan_entity.dart';

import '../../domain/repositories/profile_repository.dart';
import '../datasources/profile_remote_datasource.dart';
import '../models/notification_settings_model.dart';
import '../models/privacy_settings_model.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  final ProfileRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;

  ProfileRepositoryImpl({
    required this.remoteDataSource,
    required this.networkInfo,
  });

  @override
  Future<Either<Failure, UserEntity>> updateProfile(
    String userId,
    ProfileUpdateEntity updates,
  ) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure(message: 'No internet connection'));
    }

    try {
      final user = await remoteDataSource.updateProfile(userId, updates);
      return Right(user);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to update profile: $e'));
    }
  }

  @override
  Future<Either<Failure, String>> uploadProfilePhoto(
    String userId,
    String filePath,
  ) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure(message: 'No internet connection'));
    }

    try {
      final photoUrl = await remoteDataSource.uploadProfilePhoto(userId, filePath);
      return Right(photoUrl);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to upload photo: $e'));
    }
  }

  @override
  Future<Either<Failure, NotificationSettingsEntity>> getNotificationSettings(
    String userId,
  ) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure(message: 'No internet connection'));
    }

    try {
      final settings = await remoteDataSource.getNotificationSettings(userId);
      return Right(settings);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to get settings: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> updateNotificationSettings(
    String userId,
    NotificationSettingsEntity settings,
  ) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure(message: 'No internet connection'));
    }

    try {
      final model = NotificationSettingsModel(
        pushNotifications: settings.pushNotifications,
        emailNotifications: settings.emailNotifications,
        bookingUpdates: settings.bookingUpdates,
        promotions: settings.promotions,
        newMessages: settings.newMessages,
      );
      
      await remoteDataSource.updateNotificationSettings(userId, model);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to update settings: $e'));
    }
  }

  @override
  Future<Either<Failure, PrivacySettingsEntity>> getPrivacySettings(
    String userId,
  ) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure(message: 'No internet connection'));
    }

    try {
      final settings = await remoteDataSource.getPrivacySettings(userId);
      return Right(settings);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to get privacy settings: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> updatePrivacySettings(
    String userId,
    PrivacySettingsEntity settings,
  ) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure(message: 'No internet connection'));
    }

    try {
      final model = PrivacySettingsModel(
        profileVisible: settings.profileVisible,
        showEmail: settings.showEmail,
        showPhone: settings.showPhone,
        showAddress: settings.showAddress,
      );
      
      await remoteDataSource.updatePrivacySettings(userId, model);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to update privacy settings: $e'));
    }
  }

  @override
  Future<Either<Failure, List<SavedArtisanEntity>>> getSavedArtisans(
    String userId,
  ) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure(message: 'No internet connection'));
    }

    try {
      print('🔄 Repository: Fetching saved artisans for user $userId');
      final savedArtisans = await remoteDataSource.getSavedArtisans(userId);
      print('✅ Repository: Got ${savedArtisans.length} saved artisans from datasource');
      
      // Convert models to entities
      final entities = savedArtisans.map((model) => model.toEntity()).toList();
      print('✅ Repository: Converted to ${entities.length} entities');
      
      return Right(entities);
    } on ServerException catch (e) {
      print('❌ Repository error: ${e.message}');
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      print('❌ Repository unexpected error: $e');
      return Left(ServerFailure(message: 'Failed to get saved artisans: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> saveArtisan(
    String userId,
    String artisanId,
  ) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure(message: 'No internet connection'));
    }

    try {
      await remoteDataSource.saveArtisan(userId, artisanId);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to save artisan: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> unsaveArtisan(
    String userId,
    String artisanId,
  ) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure(message: 'No internet connection'));
    }

    try {
      await remoteDataSource.unsaveArtisan(userId, artisanId);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to unsave artisan: $e'));
    }
  }

  @override
  Future<Either<Failure, bool>> isArtisanSaved(
    String userId,
    String artisanId,
  ) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure(message: 'No internet connection'));
    }

    try {
      final isSaved = await remoteDataSource.isArtisanSaved(userId, artisanId);
      return Right(isSaved);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to check saved status: $e'));
    }
  }
}