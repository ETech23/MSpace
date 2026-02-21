// ============================================================================
// FILE: lib/features/notifications/presentation/providers/notification_provider.dart
// COMPLETE CLEAN VERSION - NO DUPLICATES
// ============================================================================

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/injection_container.dart';
import '../../domain/entities/notification_entity.dart';
import '../../domain/repositories/notification_repository.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>(
  (ref) => getIt<NotificationRepository>(),
);

// ========================= BASE NOTIFICATION STATE =========================

class NotificationState {
  final bool isLoading;
  final List<NotificationEntity> notifications;
  final int unreadCount;
  final String? error;
  final Set<String> processingIds;
  final bool isMarkingAllAsRead;

  NotificationState({
    this.isLoading = false,
    this.notifications = const [],
    this.unreadCount = 0,
    this.error,
    this.processingIds = const {},
    this.isMarkingAllAsRead = false,
  });

  NotificationState copyWith({
    bool? isLoading,
    List<NotificationEntity>? notifications,
    int? unreadCount,
    String? error,
    bool clearError = false,
    Set<String>? processingIds,
    bool? isMarkingAllAsRead,
  }) {
    return NotificationState(
      isLoading: isLoading ?? this.isLoading,
      notifications: notifications ?? this.notifications,
      unreadCount: unreadCount ?? this.unreadCount,
      error: clearError ? null : (error ?? this.error),
      processingIds: processingIds ?? this.processingIds,
      isMarkingAllAsRead: isMarkingAllAsRead ?? this.isMarkingAllAsRead,
    );
  }
}

// ========================= SYSTEM NOTIFICATIONS =========================

class SystemNotificationNotifier extends StateNotifier<NotificationState> {
  final NotificationRepository repository;
  StreamSubscription<List<NotificationEntity>>? _subscription;
  
  final Map<String, bool> _localReadStatus = {};
  final Set<String> _localDeletedIds = {};
  Timer? _debounceTimer;

  SystemNotificationNotifier({required this.repository}) 
      : super(NotificationState());

  void watchNotifications(String userId) {
    _subscription?.cancel();
    
    _subscription = repository.watchNotifications(userId).listen(
      (allNotifications) {
        _debounceTimer?.cancel();
        _debounceTimer = Timer(const Duration(milliseconds: 150), () {
          _processStreamUpdate(allNotifications);
        });
      },
      onError: (error) {
        print('❌ Error watching system notifications: $error');
        state = state.copyWith(error: error.toString());
      },
    );
  }

  void _processStreamUpdate(List<NotificationEntity> allNotifications) {
    var systemNotifications = allNotifications
        .where((n) => n.type == NotificationType.system)
        .toList();
    
    systemNotifications = systemNotifications
        .where((n) => !_localDeletedIds.contains(n.id))
        .map((n) {
          if (_localReadStatus.containsKey(n.id)) {
            return NotificationEntity(
              id: n.id,
              userId: n.userId,
              type: n.type,
              title: n.title,
              body: n.body,
              read: _localReadStatus[n.id]!,
              data: n.data,
              createdAt: n.createdAt,
            );
          }
          
          if (state.isMarkingAllAsRead && !n.read) {
            return NotificationEntity(
              id: n.id,
              userId: n.userId,
              type: n.type,
              title: n.title,
              body: n.body,
              read: true,
              data: n.data,
              createdAt: n.createdAt,
            );
          }
          
          return n;
        })
        .toList();
    
    _cleanupSyncedOverrides(systemNotifications);
    
    state = state.copyWith(
      notifications: systemNotifications,
      unreadCount: systemNotifications.where((n) => !n.read).length,
    );
  }

  void _cleanupSyncedOverrides(List<NotificationEntity> streamNotifications) {
    final keysToRemove = <String>[];
    
    for (final entry in _localReadStatus.entries) {
      final streamNotification = streamNotifications.firstWhere(
        (n) => n.id == entry.key,
        orElse: () => NotificationEntity(
          id: '',
          userId: '',
          type: NotificationType.system,
          title: '',
          body: '',
          read: false,
          data: {},
          createdAt: DateTime.now(),
        ),
      );
      
      if (streamNotification.id.isNotEmpty && 
          streamNotification.read == entry.value) {
        keysToRemove.add(entry.key);
      }
    }
    
    for (final key in keysToRemove) {
      _localReadStatus.remove(key);
    }
  }

  Future<void> loadNotifications(String userId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    
    final result = await repository.getNotifications(userId);
    
    result.fold(
      (failure) {
        print('❌ Failed to load system notifications: ${failure.message}');
        state = state.copyWith(
          isLoading: false,
          error: failure.message,
        );
      },
      (allNotifications) {
        final systemNotifications = allNotifications
            .where((n) => n.type == NotificationType.system)
            .toList();
        
        state = state.copyWith(
          isLoading: false,
          notifications: systemNotifications,
          unreadCount: systemNotifications.where((n) => !n.read).length,
        );
      },
    );
  }

  Future<void> markAsRead(String notificationId, String userId) async {
  final notification = state.notifications.firstWhere(
    (n) => n.id == notificationId,
    orElse: () => throw Exception('Notification not found'),
  );

  // 🔹 Only mark unread notifications as read
  if (!notification.read) {
    // Prevent duplicate backend call
    if (state.processingIds.contains(notificationId)) {
      print('⚠️ Mark-as-read already in progress: $notificationId');
      return;
    }

    // Mark in-flight
    state = state.copyWith(
      processingIds: {...state.processingIds, notificationId},
    );

    // Optimistic local read
    _localReadStatus[notificationId] = true;

    state = state.copyWith(
      notifications: state.notifications.map((n) {
        return n.id == notificationId
            ? n.copyWith(read: true)
            : n;
      }).toList(),
      unreadCount:
          state.notifications.where((n) => !n.read && n.id != notificationId).length,
    );

    final result = await repository.markAsRead(notificationId);

    result.fold(
      (failure) {
        print('❌ Failed to mark notification as read: ${failure.message}');
        _localReadStatus.remove(notificationId);

        state = state.copyWith(
          processingIds:
              state.processingIds.where((id) => id != notificationId).toSet(),
        );

        loadNotifications(userId);
      },
      (_) {
        print('✅ Successfully marked notification as read: $notificationId');
        _localReadStatus.remove(notificationId);

        state = state.copyWith(
          processingIds:
              state.processingIds.where((id) => id != notificationId).toSet(),
        );
      },
    );
  }

  // 🔹 Regardless of read status, allow opening notification
  // You can handle navigation or open logic here
  print('📖 Opening notification: $notificationId');
}


  Future<void> markAllAsRead(String userId) async {
    if (state.isMarkingAllAsRead) {
      print('⚠️ Already marking all as read');
      return;
    }
    
    state = state.copyWith(isMarkingAllAsRead: true);
    
    for (final notification in state.notifications) {
      _localReadStatus[notification.id] = true;
    }
    
    final updatedNotifications = state.notifications.map((n) {
      return NotificationEntity(
        id: n.id,
        userId: n.userId,
        type: n.type,
        title: n.title,
        body: n.body,
        read: true,
        data: n.data,
        createdAt: n.createdAt,
      );
    }).toList();

    state = state.copyWith(
      notifications: updatedNotifications,
      unreadCount: 0,
    );

    final result = await repository.markAllAsRead(userId);
    
    result.fold(
      (failure) {
        print('❌ Failed to mark all notifications as read: ${failure.message}');
        _localReadStatus.clear();
        state = state.copyWith(isMarkingAllAsRead: false);
        loadNotifications(userId);
      },
      (_) {
        print('✅ Successfully marked all notifications as read');
        
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            state = state.copyWith(isMarkingAllAsRead: false);
          }
        });
      },
    );
  }

  Future<void> deleteNotification(String notificationId, String userId) async {
    if (state.processingIds.contains(notificationId)) {
      print('⚠️ Already processing notification: $notificationId');
      return;
    }
    
    final newProcessingIds = Set<String>.from(state.processingIds)
      ..add(notificationId);
    state = state.copyWith(processingIds: newProcessingIds);
    
    _localDeletedIds.add(notificationId);
    
    final updatedNotifications = state.notifications
        .where((n) => n.id != notificationId)
        .toList();

    state = state.copyWith(
      notifications: updatedNotifications,
      unreadCount: updatedNotifications.where((n) => !n.read).length,
    );

    final result = await repository.deleteNotification(notificationId);
    
    result.fold(
      (failure) {
        print('❌ Failed to delete notification: ${failure.message}');
        _localDeletedIds.remove(notificationId);
        
        final revertProcessingIds = Set<String>.from(state.processingIds)
          ..remove(notificationId);
        state = state.copyWith(processingIds: revertProcessingIds);
        
        loadNotifications(userId);
      },
      (_) {
        print('✅ Successfully deleted notification: $notificationId');
        
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            _localDeletedIds.remove(notificationId);
            
            final finalProcessingIds = Set<String>.from(state.processingIds)
              ..remove(notificationId);
            state = state.copyWith(processingIds: finalProcessingIds);
          }
        });
      },
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _debounceTimer?.cancel();
    _localReadStatus.clear();
    _localDeletedIds.clear();
    super.dispose();
  }
}

// ========================= BOOKING NOTIFICATIONS =========================

class BookingNotificationNotifier extends StateNotifier<NotificationState> {
  final NotificationRepository repository;
  StreamSubscription<List<NotificationEntity>>? _subscription;
  
  final Map<String, bool> _localReadStatus = {};
  final Set<String> _localDeletedIds = {};
  Timer? _debounceTimer;

  BookingNotificationNotifier({required this.repository}) 
      : super(NotificationState());

  void watchNotifications(String userId) {
    _subscription?.cancel();
    
    _subscription = repository.watchNotifications(userId).listen(
      (allNotifications) {
        _debounceTimer?.cancel();
        _debounceTimer = Timer(const Duration(milliseconds: 150), () {
          _processStreamUpdate(allNotifications);
        });
      },
      onError: (error) {
        print('❌ Error watching booking notifications: $error');
        state = state.copyWith(error: error.toString());
      },
    );
  }

  void _processStreamUpdate(List<NotificationEntity> allNotifications) {
    var bookingNotifications = allNotifications
        .where((n) => n.type == NotificationType.booking)
        .toList();
    
    bookingNotifications = bookingNotifications
        .where((n) => !_localDeletedIds.contains(n.id))
        .map((n) {
          if (_localReadStatus.containsKey(n.id)) {
            return NotificationEntity(
              id: n.id,
              userId: n.userId,
              type: n.type,
              title: n.title,
              body: n.body,
              read: _localReadStatus[n.id]!,
              data: n.data,
              createdAt: n.createdAt,
            );
          }
          
          if (state.isMarkingAllAsRead && !n.read) {
            return NotificationEntity(
              id: n.id,
              userId: n.userId,
              type: n.type,
              title: n.title,
              body: n.body,
              read: true,
              data: n.data,
              createdAt: n.createdAt,
            );
          }
          
          return n;
        })
        .toList();
    
    _cleanupSyncedOverrides(bookingNotifications);
    
    state = state.copyWith(
      notifications: bookingNotifications,
      unreadCount: bookingNotifications.where((n) => !n.read).length,
    );
  }

  void _cleanupSyncedOverrides(List<NotificationEntity> streamNotifications) {
    final keysToRemove = <String>[];
    
    for (final entry in _localReadStatus.entries) {
      final streamNotification = streamNotifications.firstWhere(
        (n) => n.id == entry.key,
        orElse: () => NotificationEntity(
          id: '',
          userId: '',
          type: NotificationType.booking,
          title: '',
          body: '',
          read: false,
          data: {},
          createdAt: DateTime.now(),
        ),
      );
      
      if (streamNotification.id.isNotEmpty && 
          streamNotification.read == entry.value) {
        keysToRemove.add(entry.key);
      }
    }
    
    for (final key in keysToRemove) {
      _localReadStatus.remove(key);
    }
  }

  Future<void> loadNotifications(String userId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    
    final result = await repository.getNotifications(userId);
    
    result.fold(
      (failure) {
        print('❌ Failed to load booking notifications: ${failure.message}');
        state = state.copyWith(
          isLoading: false,
          error: failure.message,
        );
      },
      (allNotifications) {
        final bookingNotifications = allNotifications
            .where((n) => n.type == NotificationType.booking)
            .toList();
        
        state = state.copyWith(
          isLoading: false,
          notifications: bookingNotifications,
          unreadCount: bookingNotifications.where((n) => !n.read).length,
        );
      },
    );
  }

  Future<void> markAsRead(String notificationId, String userId) async {
  final notification = state.notifications.firstWhere(
    (n) => n.id == notificationId,
    orElse: () => throw Exception('Notification not found'),
  );

  if (!notification.read) {
    if (state.processingIds.contains(notificationId)) {
      print('⚠️ Mark-as-read already in progress: $notificationId');
      return;
    }

    state = state.copyWith(
      processingIds: {...state.processingIds, notificationId},
    );

    _localReadStatus[notificationId] = true;

    state = state.copyWith(
      notifications: state.notifications.map((n) {
        return n.id == notificationId
            ? n.copyWith(read: true)
            : n;
      }).toList(),
      unreadCount:
          state.notifications.where((n) => !n.read && n.id != notificationId).length,
    );

    final result = await repository.markAsRead(notificationId);

    result.fold(
      (failure) {
        print('❌ Failed to mark notification as read: ${failure.message}');
        _localReadStatus.remove(notificationId);

        state = state.copyWith(
          processingIds:
              state.processingIds.where((id) => id != notificationId).toSet(),
        );

        loadNotifications(userId);
      },
      (_) {
        print('✅ Successfully marked notification as read: $notificationId');
        _localReadStatus.remove(notificationId);

        state = state.copyWith(
          processingIds:
              state.processingIds.where((id) => id != notificationId).toSet(),
        );
      },
    );
  }

  print('📖 Opening booking notification: $notificationId');
}


  Future<void> markAllAsRead(String userId) async {
    if (state.isMarkingAllAsRead) {
      print('⚠️ Already marking all as read');
      return;
    }
    
    state = state.copyWith(isMarkingAllAsRead: true);
    
    for (final notification in state.notifications) {
      _localReadStatus[notification.id] = true;
    }
    
    final updatedNotifications = state.notifications.map((n) {
      return NotificationEntity(
        id: n.id,
        userId: n.userId,
        type: n.type,
        title: n.title,
        body: n.body,
        read: true,
        data: n.data,
        createdAt: n.createdAt,
      );
    }).toList();

    state = state.copyWith(
      notifications: updatedNotifications,
      unreadCount: 0,
    );

    final result = await repository.markAllAsRead(userId);
    
    result.fold(
      (failure) {
        print('❌ Failed to mark all notifications as read: ${failure.message}');
        _localReadStatus.clear();
        state = state.copyWith(isMarkingAllAsRead: false);
        loadNotifications(userId);
      },
      (_) {
        print('✅ Successfully marked all notifications as read');
        
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            state = state.copyWith(isMarkingAllAsRead: false);
          }
        });
      },
    );
  }

  Future<void> deleteNotification(String notificationId, String userId) async {
    if (state.processingIds.contains(notificationId)) {
      print('⚠️ Already processing notification: $notificationId');
      return;
    }
    
    final newProcessingIds = Set<String>.from(state.processingIds)
      ..add(notificationId);
    state = state.copyWith(processingIds: newProcessingIds);
    
    _localDeletedIds.add(notificationId);
    
    final updatedNotifications = state.notifications
        .where((n) => n.id != notificationId)
        .toList();

    state = state.copyWith(
      notifications: updatedNotifications,
      unreadCount: updatedNotifications.where((n) => !n.read).length,
    );

    final result = await repository.deleteNotification(notificationId);
    
    result.fold(
      (failure) {
        print('❌ Failed to delete notification: ${failure.message}');
        _localDeletedIds.remove(notificationId);
        
        final revertProcessingIds = Set<String>.from(state.processingIds)
          ..remove(notificationId);
        state = state.copyWith(processingIds: revertProcessingIds);
        
        loadNotifications(userId);
      },
      (_) {
        print('✅ Successfully deleted notification: $notificationId');
        
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            _localDeletedIds.remove(notificationId);
            
            final finalProcessingIds = Set<String>.from(state.processingIds)
              ..remove(notificationId);
            state = state.copyWith(processingIds: finalProcessingIds);
          }
        });
      },
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _debounceTimer?.cancel();
    _localReadStatus.clear();
    _localDeletedIds.clear();
    super.dispose();
  }
}

// ========================= MESSAGE NOTIFICATIONS =========================

class MessageNotificationNotifier extends StateNotifier<NotificationState> {
  final NotificationRepository repository;
  StreamSubscription<List<NotificationEntity>>? _subscription;
  
  final Map<String, bool> _localReadStatus = {};
  final Set<String> _localDeletedIds = {};
  Timer? _debounceTimer;

  MessageNotificationNotifier({required this.repository}) 
      : super(NotificationState());

  void watchNotifications(String userId) {
    _subscription?.cancel();
    
    _subscription = repository.watchNotifications(userId).listen(
      (allNotifications) {
        _debounceTimer?.cancel();
        _debounceTimer = Timer(const Duration(milliseconds: 150), () {
          _processStreamUpdate(allNotifications);
        });
      },
      onError: (error) {
        print('❌ Error watching message notifications: $error');
        state = state.copyWith(error: error.toString());
      },
    );
  }

  void _processStreamUpdate(List<NotificationEntity> allNotifications) {
    var messageNotifications = allNotifications
        .where((n) => n.type == NotificationType.message)
        .toList();
    
    messageNotifications = messageNotifications
        .where((n) => !_localDeletedIds.contains(n.id))
        .map((n) {
          if (_localReadStatus.containsKey(n.id)) {
            return NotificationEntity(
              id: n.id,
              userId: n.userId,
              type: n.type,
              title: n.title,
              body: n.body,
              read: _localReadStatus[n.id]!,
              data: n.data,
              createdAt: n.createdAt,
            );
          }
          
          if (state.isMarkingAllAsRead && !n.read) {
            return NotificationEntity(
              id: n.id,
              userId: n.userId,
              type: n.type,
              title: n.title,
              body: n.body,
              read: true,
              data: n.data,
              createdAt: n.createdAt,
            );
          }
          
          return n;
        })
        .toList();
    
    _cleanupSyncedOverrides(messageNotifications);
    
    state = state.copyWith(
      notifications: messageNotifications,
      unreadCount: messageNotifications.where((n) => !n.read).length,
    );
  }

  void _cleanupSyncedOverrides(List<NotificationEntity> streamNotifications) {
    final keysToRemove = <String>[];
    
    for (final entry in _localReadStatus.entries) {
      final streamNotification = streamNotifications.firstWhere(
        (n) => n.id == entry.key,
        orElse: () => NotificationEntity(
          id: '',
          userId: '',
          type: NotificationType.message,
          title: '',
          body: '',
          read: false,
          data: {},
          createdAt: DateTime.now(),
        ),
      );
      
      if (streamNotification.id.isNotEmpty && 
          streamNotification.read == entry.value) {
        keysToRemove.add(entry.key);
      }
    }
    
    for (final key in keysToRemove) {
      _localReadStatus.remove(key);
    }
  }

  Future<void> loadNotifications(String userId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    
    final result = await repository.getNotifications(userId);
    
    result.fold(
      (failure) {
        print('❌ Failed to load message notifications: ${failure.message}');
        state = state.copyWith(
          isLoading: false,
          error: failure.message,
        );
      },
      (allNotifications) {
        final messageNotifications = allNotifications
            .where((n) => n.type == NotificationType.message)
            .toList();
        
        state = state.copyWith(
          isLoading: false,
          notifications: messageNotifications,
          unreadCount: messageNotifications.where((n) => !n.read).length,
        );
      },
    );
  }

  Future<void> markAsRead(String notificationId, String userId) async {
  final notification = state.notifications.firstWhere(
    (n) => n.id == notificationId,
    orElse: () => throw Exception('Notification not found'),
  );

  if (!notification.read) {
    if (state.processingIds.contains(notificationId)) {
      print('⚠️ Mark-as-read already in progress: $notificationId');
      return;
    }

    state = state.copyWith(
      processingIds: {...state.processingIds, notificationId},
    );

    _localReadStatus[notificationId] = true;

    state = state.copyWith(
      notifications: state.notifications.map((n) {
        return n.id == notificationId
            ? n.copyWith(read: true)
            : n;
      }).toList(),
      unreadCount:
          state.notifications.where((n) => !n.read && n.id != notificationId).length,
    );

    final result = await repository.markAsRead(notificationId);

    result.fold(
      (failure) {
        print('❌ Failed to mark notification as read: ${failure.message}');
        _localReadStatus.remove(notificationId);

        state = state.copyWith(
          processingIds:
              state.processingIds.where((id) => id != notificationId).toSet(),
        );

        loadNotifications(userId);
      },
      (_) {
        print('✅ Successfully marked notification as read: $notificationId');
        _localReadStatus.remove(notificationId);

        state = state.copyWith(
          processingIds:
              state.processingIds.where((id) => id != notificationId).toSet(),
        );
      },
    );
  }

  print('📖 Opening message notification: $notificationId');
}


  Future<void> markAllAsRead(String userId) async {
    if (state.isMarkingAllAsRead) {
      print('⚠️ Already marking all as read');
      return;
    }
    
    state = state.copyWith(isMarkingAllAsRead: true);
    
    for (final notification in state.notifications) {
      _localReadStatus[notification.id] = true;
    }
    
    final updatedNotifications = state.notifications.map((n) {
      return NotificationEntity(
        id: n.id,
        userId: n.userId,
        type: n.type,
        title: n.title,
        body: n.body,
        read: true,
        data: n.data,
        createdAt: n.createdAt,
      );
    }).toList();

    state = state.copyWith(
      notifications: updatedNotifications,
      unreadCount: 0,
    );

    final result = await repository.markAllAsRead(userId);
    
    result.fold(
      (failure) {
        print('❌ Failed to mark all notifications as read: ${failure.message}');
        _localReadStatus.clear();
        state = state.copyWith(isMarkingAllAsRead: false);
        loadNotifications(userId);
      },
      (_) {
        print('✅ Successfully marked all notifications as read');
        
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            state = state.copyWith(isMarkingAllAsRead: false);
          }
        });
      },
    );
  }

  Future<void> deleteNotification(String notificationId, String userId) async {
    if (state.processingIds.contains(notificationId)) {
      print('⚠️ Already processing notification: $notificationId');
      return;
    }
    
    final newProcessingIds = Set<String>.from(state.processingIds)
      ..add(notificationId);
    state = state.copyWith(processingIds: newProcessingIds);
    
    _localDeletedIds.add(notificationId);
    
    final updatedNotifications = state.notifications
        .where((n) => n.id != notificationId)
        .toList();

    state = state.copyWith(
      notifications: updatedNotifications,
      unreadCount: updatedNotifications.where((n) => !n.read).length,
    );

    final result = await repository.deleteNotification(notificationId);
    
    result.fold(
      (failure) {
        print('❌ Failed to delete notification: ${failure.message}');
        _localDeletedIds.remove(notificationId);
        
        final revertProcessingIds = Set<String>.from(state.processingIds)
          ..remove(notificationId);
        state = state.copyWith(processingIds: revertProcessingIds);
        
        loadNotifications(userId);
      },
      (_) {
        print('✅ Successfully deleted notification: $notificationId');
        
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            _localDeletedIds.remove(notificationId);
            
            final finalProcessingIds = Set<String>.from(state.processingIds)
              ..remove(notificationId);
            state = state.copyWith(processingIds: finalProcessingIds);
          }
        });
      },
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _debounceTimer?.cancel();
    _localReadStatus.clear();
    _localDeletedIds.clear();
    super.dispose();
  }
}

// ========================= PROVIDERS =========================

final systemNotificationProvider =
    StateNotifierProvider<SystemNotificationNotifier, NotificationState>((ref) {
  return SystemNotificationNotifier(
    repository: ref.watch(notificationRepositoryProvider),
  );
});

final bookingNotificationProvider =
    StateNotifierProvider<BookingNotificationNotifier, NotificationState>((ref) {
  return BookingNotificationNotifier(
    repository: ref.watch(notificationRepositoryProvider),
  );
});

final messageNotificationProvider =
    StateNotifierProvider<MessageNotificationNotifier, NotificationState>((ref) {
  return MessageNotificationNotifier(
    repository: ref.watch(notificationRepositoryProvider),
  );
});

// ========================= UNREAD COUNT PROVIDERS =========================

final systemUnreadCountProvider = Provider<int>((ref) {
  return ref.watch(systemNotificationProvider).unreadCount;
});

final bookingUnreadCountProvider = Provider<int>((ref) {
  return ref.watch(bookingNotificationProvider).unreadCount;
});

final messageUnreadCountProvider = Provider<int>((ref) {
  return ref.watch(messageNotificationProvider).unreadCount;
});

final totalUnreadCountProvider = Provider<int>((ref) {
  final system = ref.watch(systemUnreadCountProvider);
  final booking = ref.watch(bookingUnreadCountProvider);
  final message = ref.watch(messageUnreadCountProvider);
  return system + booking + message;
});