// ============================================================================
// FILE 1: lib/features/notifications/domain/repositories/notification_repository.dart
// ============================================================================
import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/notification_entity.dart';

abstract class NotificationRepository {
  Future<Either<Failure, List<NotificationEntity>>> getNotifications(String userId);
  Future<Either<Failure, int>> getUnreadCount(String userId);
  Future<Either<Failure, Unit>> markAsRead(String notificationId);
  Future<Either<Failure, Unit>> markAllAsRead(String userId);
  Future<Either<Failure, Unit>> deleteNotification(String notificationId);
  Future<Either<Failure, Unit>> saveFCMToken(String userId, String token, String deviceType);
  Future<Either<Failure, Unit>> deleteFCMToken(String token);
  Stream<List<NotificationEntity>> watchNotifications(String userId);
}
