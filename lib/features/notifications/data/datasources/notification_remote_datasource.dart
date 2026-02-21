// lib/features/notifications/data/datasources/notification_remote_datasource.dart
// SUPABASE VERSION - Complete fix

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/error/exceptions.dart';
import '../models/notification_model.dart';

abstract class NotificationRemoteDataSource {
  Future<List<NotificationModel>> getNotifications(String userId);
  Future<int> getUnreadCount(String userId);
  Future<void> markAsRead(String notificationId);
  Future<void> markAllAsRead(String userId);
  Future<void> deleteNotification(String notificationId);
  Future<void> saveFCMToken(String userId, String token, String deviceType);
  Future<void> deleteFCMToken(String token);
  Stream<List<NotificationModel>> watchNotifications(String userId);
}

class NotificationRemoteDataSourceImpl implements NotificationRemoteDataSource {
  final SupabaseClient supabaseClient;

  NotificationRemoteDataSourceImpl({required this.supabaseClient});

  @override
  Future<List<NotificationModel>> getNotifications(String userId) async {
    try {
      final response = await supabaseClient
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(100);

      return (response as List)
          .map((json) => NotificationModel.fromJson(json))
          .toList();
    } catch (e) {
      throw ServerException(message: 'Failed to get notifications: $e');
    }
  }

  @override
  Future<int> getUnreadCount(String userId) async {
    try {
      final response = await supabaseClient
          .from('notifications')
          .select('id')
          .eq('user_id', userId)
          .eq('read', false)
          .count();

      return response.count ?? 0;
    } catch (e) {
      throw ServerException(message: 'Failed to get unread count: $e');
    }
  }

  @override
  Future<void> markAsRead(String notificationId) async {
    try {
      await supabaseClient
          .from('notifications')
          .update({'read': true})
          .eq('id', notificationId);
      
      print('✅ Supabase: Marked notification as read: $notificationId');
    } catch (e) {
      print('❌ Supabase: Failed to mark as read: $e');
      throw ServerException(message: 'Failed to update notification: $e');
    }
  }

  @override
  Future<void> markAllAsRead(String userId) async {
    try {
      await supabaseClient
          .from('notifications')
          .update({'read': true})
          .eq('user_id', userId)
          .eq('read', false);

      print('✅ Supabase: Marked all notifications as read for user: $userId');
    } catch (e) {
      print('❌ Supabase: Failed to mark all as read: $e');
      throw ServerException(message: 'Failed to mark all as read: $e');
    }
  }

  @override
  Future<void> deleteNotification(String notificationId) async {
    try {
      await supabaseClient
          .from('notifications')
          .delete()
          .eq('id', notificationId);
      
      print('✅ Supabase: Deleted notification: $notificationId');
    } catch (e) {
      print('❌ Supabase: Failed to delete: $e');
      throw ServerException(message: 'Failed to delete notification: $e');
    }
  }

  @override
  Future<void> saveFCMToken(
    String userId,
    String token,
    String deviceType,
  ) async {
    try {
      await supabaseClient.from('fcm_tokens').upsert({
        'user_id': userId,
        'token': token,
        'device_type': deviceType,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw ServerException(message: 'Failed to save FCM token: $e');
    }
  }

  @override
  Future<void> deleteFCMToken(String token) async {
    try {
      await supabaseClient.from('fcm_tokens').delete().eq('token', token);
    } catch (e) {
      throw ServerException(message: 'Failed to delete FCM token: $e');
    }
  }

  @override
  Stream<List<NotificationModel>> watchNotifications(String userId) {
    return supabaseClient
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(100)
        .map((data) {
          return data
              .map((json) => NotificationModel.fromJson(json))
              .toList();
        });
  }
}