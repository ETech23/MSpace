import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// ✅ Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('🎯 Background message: ${message.notification?.title}');
  await FCMService()._showLocalNotification(message);
}

class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = 
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  Function(String, Map<String, dynamic>)? _onNotificationTapped;

  // ✅ Set callback for notification taps
  void setNotificationHandler(Function(String, Map<String, dynamic>) handler) {
    _onNotificationTapped = handler;
  }

  Future<bool> initialize() async {
    if (_initialized) return true;

    try {
      print('🔔 Initializing FCM service...');

      // ✅ Request permission
      NotificationSettings settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false, // Ask for full permission
      );

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        print('❌ User denied notification permission');
        return false;
      }

      print('✅ Notification permission: ${settings.authorizationStatus}');

      // ✅ Initialize local notifications
      const AndroidInitializationSettings androidSettings = 
          AndroidInitializationSettings('@mipmap/ic_launcher');
      
      const DarwinInitializationSettings iosSettings = 
          DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          print('👆 Notification tapped: ${response.payload}');
          if (response.payload != null) {
            try {
              final payload = json.decode(response.payload!) as Map<String, dynamic>;
              _onNotificationTapped?.call('local', payload);
            } catch (e) {
              print('❌ Error parsing payload: $e');
            }
          }
        },
      );

      // ✅ Create Android notification channel
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(
        const AndroidNotificationChannel(
          'booking_channel',
          'Booking Notifications',
          description: 'Notifications for booking updates',
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
        ),
      );

      // ✅ Get FCM token
      final token = await _fcm.getToken();
      print('🎯 FCM Token: $token');
      
      // TODO: Save token to user profile in Supabase
      // await _saveTokenToProfile(token);

      // ✅ Handle foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // ✅ Handle when app is opened from terminated state
      final initialMessage = await _fcm.getInitialMessage();
      if (initialMessage != null) {
        print('🎯 App opened from notification');
        _handleNotificationTap(initialMessage);
      }

      // ✅ Handle when app is in background
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      // ✅ Set background message handler
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      _initialized = true;
      print('✅ FCM service initialized successfully');
      return true;
    } catch (e) {
      print('❌ FCM initialization error: $e');
      return false;
    }
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print('📱 Foreground message: ${message.notification?.title}');
    await _showLocalNotification(message);
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'booking_channel',
      'Booking Notifications',
      channelDescription: 'Notifications for booking updates',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      playSound: true,
      enableVibration: true,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      message.notification?.title ?? 'Naco',
      message.notification?.body ?? 'New notification',
      details,
      payload: json.encode(message.data),
    );
  }

  void _handleNotificationTap(RemoteMessage message) {
    print('👆 Notification tapped: ${message.data}');
    _onNotificationTapped?.call('remote', message.data);
  }

  // ✅ Send local notification (for testing or booking updates)
  Future<void> sendLocalNotification({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'booking_channel',
      'Booking Notifications',
      channelDescription: 'Notifications for booking updates',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      details,
      payload: data != null ? json.encode(data) : null,
    );
  }

  Future<String?> getToken() async {
    return await _fcm.getToken();
  }

  Future<AuthorizationStatus> getPermissionStatus() async {
    final settings = await _fcm.getNotificationSettings();
    return settings.authorizationStatus;
  }

  Future<AuthorizationStatus> requestPermission() async {
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    return settings.authorizationStatus;
  }

  // ✅ Show test notification
  Future<void> showTestNotification() async {
    await sendLocalNotification(
      title: 'Test Notification',
      body: 'This is a test notification from Naco',
      data: {'type': 'test'},
    );
  }
}