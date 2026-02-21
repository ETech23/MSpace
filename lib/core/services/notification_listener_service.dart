// lib/core/services/notification_listener_service.dart
// UPDATED: Sends FCM push notifications to other users

import 'package:supabase_flutter/supabase_flutter.dart';
import 'notification_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class NotificationListenerService {
  static final NotificationListenerService _instance = NotificationListenerService._internal();
  factory NotificationListenerService() => _instance;
  NotificationListenerService._internal();

  final _supabase = Supabase.instance.client;
  final _notificationService = NotificationService();
  RealtimeChannel? _channel;
  String? _currentUserId;

  // FCM Server Key - Add this to your environment or hardcode
  static const String _fcmServerKey = 'YOUR_FCM_SERVER_KEY_HERE';

  Future<void> startListening(String userId) async {
    if (_currentUserId == userId && _channel != null) {
      return;
    }

    await stopListening();
    _currentUserId = userId;
    
    print('🔔 Starting notification listener for user: $userId');

    _channel = _supabase
        .channel('notifications:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            print('🔔 New notification received: ${payload.newRecord}');
            _handleNewNotification(payload.newRecord);
          },
        )
        .subscribe();

    print('✅ Notification listener started');
  }

  void _handleNewNotification(Map<String, dynamic> notification) async {
    final title = notification['title'] as String? ?? 'New Notification';
    final body = notification['body'] as String? ?? '';
    final type = notification['type'] as String? ?? 'system';
    final relatedId = notification['related_id'] as String?;
    final data = notification['data'] as Map<String, dynamic>? ?? {};
    final userId = notification['user_id'] as String;

    print('📱 Showing local notification: $title');

    // Show local notification (for current user when app is open)
    if (type == 'message') {
      final senderName = data['senderName'] as String? ?? title;
      _notificationService.sendMessageNotification(
        senderName: senderName,
        messageText: body,
        conversationId: data['conversationId'] ?? relatedId ?? '',
        senderId: data['senderId'] ?? '',
      );
    } else if (type == 'booking') {
      final subType = data['subType'] as String? ?? '';
      final bookingId = relatedId ?? '';
      
      switch (subType) {
        case 'created':
          _notificationService.sendBookingCreatedNotification(
            bookingId: bookingId,
            serviceType: data['serviceType'] ?? 'service',
          );
          break;
        case 'accepted':
          _notificationService.sendBookingAcceptedNotification(
            bookingId: bookingId,
            artisanName: data['artisanName'] ?? 'Artisan',
            serviceType: data['serviceType'] ?? 'service',
          );
          break;
        case 'rejected':
          _notificationService.sendBookingRejectedNotification(
            bookingId: bookingId,
            artisanName: data['artisanName'] ?? 'Artisan',
            serviceType: data['serviceType'] ?? 'service',
            reason: data['reason'],
          );
          break;
        case 'started':
          _notificationService.sendBookingStartedNotification(
            bookingId: bookingId,
            artisanName: data['artisanName'] ?? 'Artisan',
            serviceType: data['serviceType'] ?? 'service',
          );
          break;
        case 'completed':
          _notificationService.sendBookingCompletedNotification(
            bookingId: bookingId,
            artisanName: data['artisanName'] ?? 'Artisan',
            serviceType: data['serviceType'] ?? 'service',
          );
          break;
        default:
          _notificationService.sendLocalNotification(
            title: title,
            body: body,
            data: {'type': type, 'bookingId': bookingId, ...data},
          );
      }
    } 
    // Handle job notifications
  else if (type == 'job') {
    final subType = data['subType'] as String? ?? '';
    final jobId = relatedId ?? '';
    
    switch (subType) {
      case 'new_job':
      case 'job_match':
        _notificationService.sendJobMatchedNotification(
          jobId: jobId,
          jobTitle: data['jobTitle'] ?? 'New Job',
          customerName: data['customerName'] ?? 'Customer',
          distanceKm: (data['distanceKm'] as num?)?.toDouble() ?? 0.0,
          matchScore: (data['matchScore'] as num?)?.toDouble() ?? 0.0,
        );
        break;
      case 'job_accepted':
        _notificationService.sendJobAcceptedNotification(
          jobId: jobId,
          artisanName: data['artisanName'] ?? 'Artisan',
          category: data['category'] ?? 'service',
        );
        break;
      default:
        _notificationService.sendLocalNotification(
          title: title,
          body: body,
          data: {'type': type, 'jobId': jobId, ...data},
        );
    }
  } else {
    _notificationService.sendSystemNotification(
      title: title,
      body: body,
      data: {'type': type, ...data},
    );
  }


    // Send push notification to the recipient's device (if they're not active)
    await _sendPushNotificationToUser(userId, title, body, type, data);
  }

  Future<void> _sendPushNotificationToUser(
    String userId,
    String title,
    String body,
    String type,
    Map<String, dynamic> data,
  ) async {
    try {
      // Get user's FCM tokens
      final response = await _supabase
          .from('fcm_tokens')
          .select('token, device_type')
          .eq('user_id', userId);

      final tokens = response as List;

      if (tokens.isEmpty) {
        print('⚠️ No FCM tokens found for user $userId');
        return;
      }

      print('📤 Sending push notification to ${tokens.length} device(s)');

      for (final tokenData in tokens) {
        await _sendFCMNotification(
          token: tokenData['token'],
          title: title,
          body: body,
          type: type,
          data: data,
        );
      }
    } catch (e) {
      print('❌ Error sending push notification: $e');
    }
  }

  Future<void> _sendFCMNotification({
    required String token,
    required String title,
    required String body,
    required String type,
    required Map<String, dynamic> data,
  }) async {
    try {
      final payload = {
        'to': token,
        'priority': 'high',
        'notification': {
          'title': title,
          'body': body,
          'sound': 'default',
          'badge': '1',
        },
        'data': data,
        'android': {
          'priority': 'high',
          'notification': {
            'channel_id': type == 'message' 
                ? 'messages_channel' 
                : type == 'booking'
                ? 'bookings_channel'
                : 'system_channel',
            'sound': 'default',
            'priority': 'high',
          },
        },
        'apns': {
          'payload': {
            'aps': {
              'alert': {
                'title': title,
                'body': body,
              },
              'sound': 'default',
              'badge': 1,
            },
          },
        },
      };

      final response = await http.post(
        Uri.parse('https://fcm.googleapis.com/fcm/send'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'key=$_fcmServerKey',
        },
        body: json.encode(payload),
      );

      if (response.statusCode == 200) {
        print('✅ Push notification sent successfully');
      } else {
        print('❌ FCM error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('❌ Error sending FCM: $e');
    }
  }

  Future<void> stopListening() async {
    if (_channel != null) {
      await _supabase.removeChannel(_channel!);
      _channel = null;
      _currentUserId = null;
      print('🔕 Notification listener stopped');
    }
  }
}