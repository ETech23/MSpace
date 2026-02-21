// lib/core/services/fcm_notification_service.dart
// SIMPLIFIED - Remove database listeners

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'notification_service.dart';

class FCMNotificationService {
  static final FCMNotificationService _instance = FCMNotificationService._internal();
  factory FCMNotificationService() => _instance;
  FCMNotificationService._internal();

  final _firebaseMessaging = FirebaseMessaging.instance;
  final _supabase = Supabase.instance.client;
  final _localNotifications = NotificationService();
  
  String? _currentUserId;
  String? _fcmToken;
  Function(Map<String, dynamic>)? _onNotificationTap;

  /// Set callback to handle notification taps
  void setNotificationHandler(Function(Map<String, dynamic>) handler) {
    _onNotificationTap = handler;
  }

  Future<void> initialize(String userId) async {
    _currentUserId = userId;
    
    print('🔔 Initializing FCM for user: $userId');
    
    // Request permission
    final settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    print('🔐 Permission: ${settings.authorizationStatus}');

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      print('❌ Push notification permission denied');
      return;
    }

    // Get FCM token
    _fcmToken = await _firebaseMessaging.getToken();
    
    if (_fcmToken == null) {
      print('❌ No FCM token received');
      return;
    }
    
    print('🎫 FCM Token: ${_fcmToken!.substring(0, 30)}...');
    
    // Save to database
    await _saveFCMToken(userId, _fcmToken!);

    // Listen for token refresh
    _firebaseMessaging.onTokenRefresh.listen((newToken) {
      print('🔄 Token refreshed');
      _fcmToken = newToken;
      _saveFCMToken(userId, newToken);
    });

    // Setup message handlers ONLY
    _setupMessageHandlers();

    // ❌ REMOVED: _startDatabaseListener() - This was creating duplicates!

    print('✅ FCM Notification Service initialized');
  }

  Future<void> _saveFCMToken(String userId, String token) async {
  try {
    final deviceType = Platform.isAndroid ? 'android' : 'ios';

    // First, delete all old tokens for this user/device type
    await _supabase
        .from('fcm_tokens')
        .delete()
        .eq('user_id', userId)
        .eq('device_type', deviceType);

    print('🗑️ Deleted old tokens for $deviceType');

    // Then insert the new token
    await _supabase.from('fcm_tokens').insert({
      'user_id': userId,
      'token': token,
      'device_type': deviceType,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });

    print('✅ FCM token saved');
    print('   User: $userId');
    print('   Device: $deviceType');
    print('   Token: ${token.substring(0, 20)}...');
    
  } catch (e, stackTrace) {
    print('❌ Error saving FCM token: $e');
    print('Stack: $stackTrace');
  }
}

  void _setupMessageHandlers() {
  // Foreground - only for when app is OPEN and visible
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print('📩 Foreground message: ${message.notification?.title}');
    
    // Only show local notification if app is in foreground
    // This is the ONE place we create a local notification
    _showLocalNotification(message);
  });

  // Background tap - handle navigation
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    print('📩 Notification tapped from background');
    _handleNotificationTap(message.data);
  });

  // Terminated tap - handle navigation  
  _firebaseMessaging.getInitialMessage().then((RemoteMessage? message) {
    if (message != null) {
      print('📩 App opened from notification (terminated)');
      _handleNotificationTap(message.data);
    }
  });
}

final Set<String> _recentNotifications = {};

void _showLocalNotification(RemoteMessage message) {
  final notification = message.notification;
  if (notification == null) return;
  
  // Create unique ID from title + body + timestamp (within 5 seconds)
  final notificationKey = '${notification.title}_${notification.body}_${DateTime.now().millisecondsSinceEpoch ~/ 5000}';
  
  // Check if we already showed this notification recently
  if (_recentNotifications.contains(notificationKey)) {
    print('⚠️ Duplicate notification blocked: ${notification.title}');
    return;
  }
  
  _recentNotifications.add(notificationKey);
  
  // Remove old entries after 10 seconds
  Future.delayed(Duration(seconds: 10), () {
    _recentNotifications.remove(notificationKey);
  });
  
  // Now show the notification
  final type = message.data['type'] ?? 'system';
  final data = message.data;
    
    if (type == 'message') {
      _localNotifications.sendMessageNotification(
        senderName: notification.title ?? 'New Message',
        messageText: notification.body ?? '',
        conversationId: data['conversationId'] ?? data['relatedId'] ?? '',
        senderId: data['senderId'] ?? '',
      );
    } else if (type == 'booking') {
      final subType = data['subType'] ?? '';
      final bookingId = data['bookingId'] ?? data['relatedId'] ?? '';
      
      switch (subType) {
        case 'created':
          _localNotifications.sendBookingCreatedNotification(
            bookingId: bookingId,
            serviceType: data['serviceType'] ?? 'service',
          );
          break;
        case 'accepted':
          _localNotifications.sendBookingAcceptedNotification(
            bookingId: bookingId,
            artisanName: data['artisanName'] ?? 'Artisan',
            serviceType: data['serviceType'] ?? 'service',
          );
          break;
        case 'rejected':
          _localNotifications.sendBookingRejectedNotification(
            bookingId: bookingId,
            artisanName: data['artisanName'] ?? 'Artisan',
            serviceType: data['serviceType'] ?? 'service',
            reason: data['reason'],
          );
          break;
        case 'started':
          _localNotifications.sendBookingStartedNotification(
            bookingId: bookingId,
            artisanName: data['artisanName'] ?? 'Artisan',
            serviceType: data['serviceType'] ?? 'service',
          );
          break;
        case 'completed':
          _localNotifications.sendBookingCompletedNotification(
            bookingId: bookingId,
            artisanName: data['artisanName'] ?? 'Artisan',
            serviceType: data['serviceType'] ?? 'service',
          );
          break;
        default:
          _localNotifications.sendLocalNotification(
            title: notification.title ?? 'Booking Update',
            body: notification.body ?? '',
            data: data,
          );
      }
    } else if (type == 'job') {
      final subType = data['subType'] ?? '';
      final jobId = data['jobId'] ?? data['relatedId'] ?? '';
      final jobTitle = data['jobTitle'] ?? '';
      final customerName = data['customerName'] ?? '';
      final distanceKm = (data['distanceKm'] is num) ? (data['distanceKm'] as num).toDouble() : 0.0;

      if (subType == 'job_match') {
        _localNotifications.sendJobMatchedNotification(
          jobId: jobId,
          jobTitle: jobTitle,
          customerName: customerName,
          distanceKm: distanceKm,
          matchScore: (data['matchScore'] is num) ? (data['matchScore'] as num).toDouble() : 0.0,
        );
      } else {
        _localNotifications.sendJobPostedNotification(
          jobId: jobId,
          jobTitle: jobTitle,
          category: data['category'] ?? 'service',
          customerName: customerName,
          distanceKm: distanceKm,
          budget: data['budget'] ?? null,
        );
      }
    } else {
      _localNotifications.sendSystemNotification(
        title: notification.title ?? 'Notification',
        body: notification.body ?? '',
        data: data,
      );
    }
  }

  void _handleNotificationTap(Map<String, dynamic> data) {
    print('🔔 Notification tapped: $data');
    // Call app-level handler if set
    try {
      if (_onNotificationTap != null) {
        _onNotificationTap!(data);
      }
    } catch (e) {
      print('❌ Error handling notification tap: $e');
    }
  }

  Future<void> clearToken() async {
    try {
      if (_fcmToken != null && _currentUserId != null) {
        await _supabase
            .from('fcm_tokens')
            .delete()
            .eq('user_id', _currentUserId!)
            .eq('token', _fcmToken!);
            
        await _firebaseMessaging.deleteToken();
        print('✅ FCM token removed');
      }
    } catch (e) {
      print('❌ Error removing FCM token: $e');
    }
  }
}