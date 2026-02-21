// lib/core/services/push_notification_service.dart
// UPDATED: Proper device type detection and token management

import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class PushNotificationService {
  static final PushNotificationService _instance = PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  
  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  Function(Map<String, dynamic>)? onNotificationTap;

  Future<void> initialize({
    required String userId,
    Function(Map<String, dynamic>)? onNotificationTap,
  }) async {
    this.onNotificationTap = onNotificationTap;
    
    // Request permissions
    final settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('✅ Push notification permission granted');
      
      // Get FCM token
      await _getFCMToken(userId);
      
      // Listen for token refresh
      _firebaseMessaging.onTokenRefresh.listen((newToken) {
        _updateFCMToken(userId, newToken);
      });
      
      print('✅ Push notification service initialized');
    } else {
      print('⚠️ Push notification permission denied');
    }
  }

  Future<void> _getFCMToken(String userId) async {
    try {
      _fcmToken = await _firebaseMessaging.getToken();
      
      if (_fcmToken != null) {
        print('📱 FCM Token: ${_fcmToken!.substring(0, 20)}...');
        await _updateFCMToken(userId, _fcmToken!);
      }
    } catch (e) {
      print('❌ Error getting FCM token: $e');
    }
  }

  Future<void> _updateFCMToken(String userId, String token) async {
    try {
      final supabase = Supabase.instance.client;
      
      // Detect device type
      String deviceType = 'android';
      if (!kIsWeb) {
        if (Platform.isIOS) {
          deviceType = 'ios';
        } else if (Platform.isAndroid) {
          deviceType = 'android';
        }
      }
      
      // Use direct insert/update instead of RPC
      await supabase.from('fcm_tokens').upsert({
        'user_id': userId,
        'token': token,
        'device_type': deviceType,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id,token');
      
      _fcmToken = token;
      print('✅ FCM token updated in database (device: $deviceType)');
    } catch (e) {
      print('❌ Error updating FCM token: $e');
    }
  }

  Future<void> clearToken(String userId) async {
    try {
      final supabase = Supabase.instance.client;
      
      if (_fcmToken != null) {
        await supabase
            .from('fcm_tokens')
            .delete()
            .eq('user_id', userId)
            .eq('token', _fcmToken!);
      }
      
      _fcmToken = null;
      print('✅ FCM token cleared');
    } catch (e) {
      print('❌ Error clearing FCM token: $e');
    }
  }

  Future<void> sendTestNotification() async {
    await _localNotifications.show(
      0,
      'Test Notification',
      'This is a test message',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'test_channel',
          'Test',
          importance: Importance.high,
          priority: Priority.high,
          sound: RawResourceAndroidNotificationSound('notification_sound'),
          playSound: true,
        ),
        iOS: DarwinNotificationDetails(
          sound: 'default',
        ),
      ),
    );
  }
}

// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('📩 Background message: ${message.notification?.title}');
  // Background messages are handled by the edge function
}