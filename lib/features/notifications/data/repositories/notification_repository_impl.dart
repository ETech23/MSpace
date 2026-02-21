// lib/features/notifications/data/repositories/notification_repository_impl.dart
import 'package:dartz/dartz.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/notification_entity.dart';
import '../../domain/repositories/notification_repository.dart';
import '../datasources/notification_remote_datasource.dart';

class NotificationRepositoryImpl implements NotificationRepository {
  final NotificationRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;

  NotificationRepositoryImpl({
    required this.remoteDataSource,
    required this.networkInfo,
  });

  @override
  Future<Either<Failure, List<NotificationEntity>>> getNotifications(
    String userId,
  ) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure(message: 'No internet connection'));
    }

    try {
      final notifications = await remoteDataSource.getNotifications(userId);
      return Right(notifications.map((m) => m.toEntity()).toList());
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to get notifications: $e'));
    }
  }

  @override
  Future<Either<Failure, int>> getUnreadCount(String userId) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure(message: 'No internet connection'));
    }

    try {
      final count = await remoteDataSource.getUnreadCount(userId);
      return Right(count);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to get unread count: $e'));
    }
  }

  @override
  Future<Either<Failure, Unit>> markAsRead(String notificationId) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure(message: 'No internet connection'));
    }

    try {
      await remoteDataSource.markAsRead(notificationId);
      return const Right(unit); // Return unit for success
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to mark as read: $e'));
    }
  }

  @override
  Future<Either<Failure, Unit>> markAllAsRead(String userId) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure(message: 'No internet connection'));
    }

    try {
      await remoteDataSource.markAllAsRead(userId);
      return const Right(unit); // Return unit for success
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to mark all as read: $e'));
    }
  }

  @override
  Future<Either<Failure, Unit>> deleteNotification(String notificationId) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure(message: 'No internet connection'));
    }

    try {
      await remoteDataSource.deleteNotification(notificationId);
      return const Right(unit); // Return unit for success
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to delete notification: $e'));
    }
  }

  @override
  Future<Either<Failure, Unit>> saveFCMToken(
    String userId,
    String token,
    String deviceType,
  ) async {
    try {
      await remoteDataSource.saveFCMToken(userId, token, deviceType);
      return const Right(unit);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to save FCM token: $e'));
    }
  }

  @override
  Future<Either<Failure, Unit>> deleteFCMToken(String token) async {
    try {
      await remoteDataSource.deleteFCMToken(token);
      return const Right(unit);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to delete FCM token: $e'));
    }
  }

  @override
  Stream<List<NotificationEntity>> watchNotifications(String userId) {
    return remoteDataSource
        .watchNotifications(userId)
        .map((models) => models.map((m) => m.toEntity()).toList());
  }
}