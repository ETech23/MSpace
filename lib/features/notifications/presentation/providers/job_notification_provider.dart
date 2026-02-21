// lib/features/notifications/presentation/providers/job_notification_provider.dart
// FIXED: Auto-refresh UI when new notifications arrive

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/notification_entity.dart';
import '../../domain/repositories/notification_repository.dart';
import 'notification_provider.dart';

final jobNotificationProvider = StateNotifierProvider<JobNotificationNotifier, NotificationState>((ref) {
  final repository = ref.watch(notificationRepositoryProvider);
  return JobNotificationNotifier(repository);
});

class JobNotificationNotifier extends StateNotifier<NotificationState> {
  final NotificationRepository _repository;
  StreamSubscription<List<NotificationEntity>>? _subscription;

  JobNotificationNotifier(this._repository) : super(NotificationState());

  Future<void> loadNotifications(String userId) async {
    state = state.copyWith(isLoading: true);

    final result = await _repository.getNotifications(userId);

    result.fold(
      (failure) {
        state = state.copyWith(
          isLoading: false,
          error: failure.message,
        );
      },
      (allNotifications) {
        final jobNotifications = allNotifications
            .where((n) => n.type == NotificationType.job)
            .toList();
        
        state = state.copyWith(
          isLoading: false,
          notifications: jobNotifications,
          error: null,
        );
      },
    );
  }

  void watchNotifications(String userId) {
    print('👀 Starting to watch job notifications for user: $userId');

    // Cancel previous subscription if present
    _subscription?.cancel();

    _subscription = _repository.watchNotifications(userId).listen(
      (allNotifications) {
        final jobNotifications = allNotifications
            .where((n) => n.type == NotificationType.job)
            .toList();

        state = state.copyWith(
          notifications: jobNotifications,
        );

        print('✅ Job notifications updated. Total: ${state.notifications.length}');
      },
      onError: (error) {
        print('❌ Error watching job notifications: $error');
        state = state.copyWith(error: error.toString());
      },
    );
  }

  Future<void> markAsRead(String notificationId, String userId) async {
    final result = await _repository.markAsRead(notificationId);

    result.fold(
      (failure) {
        state = state.copyWith(error: failure.message);
      },
      (_) {
        // ✅ FIX: Update state immediately
        final updatedNotifications = state.notifications.map((n) {
          if (n.id == notificationId) {
            return n.copyWith(read: true);
          }
          return n;
        }).toList();

        state = state.copyWith(notifications: updatedNotifications);
      },
    );
  }

  Future<void> markAllAsRead(String userId) async {
    final unreadJobNotifications = state.notifications
        .where((n) => !n.read)
        .toList();

    for (final notification in unreadJobNotifications) {
      await _repository.markAsRead(notification.id);
    }

    // ✅ FIX: Update state immediately
    final updatedNotifications = state.notifications.map((n) {
      return n.copyWith(read: true);
    }).toList();

    state = state.copyWith(notifications: updatedNotifications);
  }

  Future<void> deleteNotification(String notificationId, String userId) async {
    final result = await _repository.deleteNotification(notificationId);

    result.fold(
      (failure) {
        state = state.copyWith(error: failure.message);
      },
      (_) {
        // ✅ FIX: Update state immediately
        final updatedNotifications = state.notifications
            .where((n) => n.id != notificationId)
            .toList();

        state = state.copyWith(notifications: updatedNotifications);
      },
    );
  }

  @override
  void dispose() {
    print('🔕 Disposing job notification provider');
    _subscription?.cancel();
    _subscription = null;
    super.dispose();
  }
}

final jobUnreadCountProvider = Provider<int>((ref) {
  final state = ref.watch(jobNotificationProvider);
  return state.notifications.where((n) => !n.read).length;
});