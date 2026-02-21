// lib/core/services/notification_service.dart
// ENHANCED with separate channels for different notification types

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';

enum NotificationChannel {
  messages,
  bookings,
  system,
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications = 
      FlutterLocalNotificationsPlugin();
  
  bool _initialized = false;

  // Notification channels configuration
  static const String _messageChannelId = 'messages_channel';
  static const String _messageChannelName = 'Messages';
  static const String _messageChannelDesc = 'Chat and direct messages';

  static const String _bookingChannelId = 'bookings_channel';
  static const String _bookingChannelName = 'Bookings';
  static const String _bookingChannelDesc = 'Booking updates and status changes';

  static const String _systemChannelId = 'system_channel';
  static const String _systemChannelName = 'System';
  static const String _systemChannelDesc = 'App updates and announcements';
  // Job notifications channel
  static const String _jobChannelId = 'jobs_channel';
  static const String _jobChannelName = 'Job Requests';
  static const String _jobChannelDesc = 'New job postings and matches';

  // ✅ Request notification permission (Android 13+)
  Future<bool> requestPermission() async {
    if (Platform.isAndroid) {
      final androidInfo = await _getAndroidVersion();
      if (androidInfo >= 33) {
        print('🔔 Requesting notification permission (Android 13+)...');
        final status = await Permission.notification.request();
        print('🔔 Permission status: $status');
        return status.isGranted;
      }
      return true;
    }
    
    if (Platform.isIOS) {
      final status = await Permission.notification.request();
      return status.isGranted;
    }
    
    return true;
  }

  Future<int> _getAndroidVersion() async {
    if (Platform.isAndroid) {
      return 33; // Assume Android 13+ for safety
    }
    return 0;
  }

  // ✅ Initialize local notifications with separate channels
  Future<bool> initialize() async {
    if (_initialized) return true;

    try {
      print('🔔 Initializing notification service...');

      final hasPermission = await requestPermission();
      if (!hasPermission) {
        print('⚠️ Notification permission denied');
      }

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

      final initialized = await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _handleNotificationResponse,
      );

      if (initialized == false) {
        print('⚠️ Notification initialization returned false');
      }

      // ✅ Create separate notification channels
      await _createNotificationChannels();

      _initialized = true;
      print('✅ Notification service initialized successfully');
      return true;
    } catch (e, stackTrace) {
      print('❌ Notification service error: $e');
      print('Stack trace: $stackTrace');
      return false;
    }
  }

  // ✅ Create all notification channels
  Future<void> _createNotificationChannels() async {
    if (!Platform.isAndroid) return;

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin == null) return;

    // Messages channel - High priority, custom sound
    await androidPlugin.createNotificationChannel(
      AndroidNotificationChannel(
        _messageChannelId,
        _messageChannelName,
        description: _messageChannelDesc,
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
        enableLights: true,
        ledColor: Colors.blue, // Blue for messages
        showBadge: true,
      ),
    );

    // Bookings channel - High priority
    await androidPlugin.createNotificationChannel(
      AndroidNotificationChannel(
        _bookingChannelId,
        _bookingChannelName,
        description: _bookingChannelDesc,
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
        enableLights: true,
        ledColor: Colors.green, // Green for bookings
        showBadge: true,
      ),
    );

    // System channel - Default priority
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        _systemChannelId,
        _systemChannelName,
        description: _systemChannelDesc,
        importance: Importance.defaultImportance,
        playSound: false,
        enableVibration: false,
        showBadge: true,
      ),
    );

    // Jobs channel - High priority
await androidPlugin.createNotificationChannel(
  AndroidNotificationChannel(
    _jobChannelId,
    _jobChannelName,
    description: _jobChannelDesc,
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
    enableLights: true,
    ledColor: Colors.orange, // Orange for jobs
    showBadge: true,
  ),
);

    print('✅ All notification channels created');
  }

  // ✅ Check if notifications are enabled
  Future<bool> areNotificationsEnabled() async {
    if (Platform.isAndroid) {
      final androidInfo = await _getAndroidVersion();
      if (androidInfo >= 33) {
        final status = await Permission.notification.status;
        return status.isGranted;
      }
      return true;
    }
    
    if (Platform.isIOS) {
      final status = await Permission.notification.status;
      return status.isGranted;
    }
    
    return true;
  }

  // ✅ Send notification with specific channel
  Future<void> _sendNotification({
    required String channelId,
    required String channelName,
    required String title,
    required String body,
    required Importance importance,
    required Priority priority,
    String? largeIcon,
    String? bigPicture,
    Map<String, dynamic>? data,
    bool playSound = true,
    bool enableVibration = true,
  }) async {
    try {
      if (!_initialized) {
        await initialize();
      }

      final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        channelId,
        channelName,
        importance: importance,
        priority: priority,
        playSound: playSound,
        enableVibration: enableVibration,
        showWhen: true,
        largeIcon: largeIcon != null ? DrawableResourceAndroidBitmap(largeIcon) : null,
        styleInformation: bigPicture != null 
            ? BigPictureStyleInformation(
                DrawableResourceAndroidBitmap(bigPicture),
              )
            : const BigTextStyleInformation(''),
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final NotificationDetails details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      final notificationId = DateTime.now().millisecondsSinceEpoch.remainder(100000);
      
      await _localNotifications.show(
        notificationId,
        title,
        body,
        details,
        payload: data != null ? json.encode(data) : null,
      );

      print('✅ [$channelName] Notification sent: $title');
    } catch (e, stackTrace) {
      print('❌ Error sending notification: $e');
      print('Stack trace: $stackTrace');
    }
  }

  // ========================= MESSAGE NOTIFICATIONS =========================

  Future<void> sendMessageNotification({
    required String senderName,
    required String messageText,
    required String conversationId,
    required String senderId,
    String? senderPhotoUrl,
  }) async {
    await _sendNotification(
      channelId: _messageChannelId,
      channelName: _messageChannelName,
      title: senderName,
      body: messageText,
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      data: {
        'type': 'message',
        'conversationId': conversationId,
        'senderId': senderId,
        'action': 'open_chat',
      },
    );
  }

  // ========================= BOOKING NOTIFICATIONS =========================

  Future<void> sendBookingCreatedNotification({
    required String bookingId,
    required String serviceType,
    String? artisanName, // Optional for compatibility
  }) async {
    await _sendNotification(
      channelId: _bookingChannelId,
      channelName: _bookingChannelName,
      title: '🎉 New Booking Request',
      body: 'You have a new booking request for $serviceType',
      importance: Importance.high,
      priority: Priority.high,
      data: {
        'type': 'booking',
        'subType': 'created',
        'bookingId': bookingId,
        'action': 'open_booking',
      },
    );
  }

  Future<void> sendBookingAcceptedNotification({
    required String bookingId,
    required String artisanName,
    required String serviceType,
  }) async {
    await _sendNotification(
      channelId: _bookingChannelId,
      channelName: _bookingChannelName,
      title: '✅ Booking Accepted',
      body: '$artisanName accepted your $serviceType booking',
      importance: Importance.high,
      priority: Priority.high,
      data: {
        'type': 'booking',
        'subType': 'accepted',
        'bookingId': bookingId,
        'action': 'open_booking',
      },
    );
  }

  Future<void> sendBookingRejectedNotification({
    required String bookingId,
    required String artisanName,
    required String serviceType,
    String? reason,
  }) async {
    await _sendNotification(
      channelId: _bookingChannelId,
      channelName: _bookingChannelName,
      title: '❌ Booking Declined',
      body: '$artisanName declined your $serviceType booking${reason != null ? ": $reason" : ""}',
      importance: Importance.high,
      priority: Priority.high,
      data: {
        'type': 'booking',
        'subType': 'rejected',
        'bookingId': bookingId,
        'action': 'open_booking',
      },
    );
  }

  Future<void> sendBookingStartedNotification({
    required String bookingId,
    required String artisanName,
    required String serviceType,
  }) async {
    await _sendNotification(
      channelId: _bookingChannelId,
      channelName: _bookingChannelName,
      title: '🔨 Work Started',
      body: '$artisanName has started working on your $serviceType',
      importance: Importance.high,
      priority: Priority.high,
      data: {
        'type': 'booking',
        'subType': 'started',
        'bookingId': bookingId,
        'action': 'open_booking',
      },
    );
  }

  Future<void> sendBookingCompletedNotification({
    required String bookingId,
    required String artisanName,
    required String serviceType,
  }) async {
    await _sendNotification(
      channelId: _bookingChannelId,
      channelName: _bookingChannelName,
      title: '✨ Work Completed',
      body: '$artisanName completed your $serviceType. Please leave a review!',
      importance: Importance.high,
      priority: Priority.high,
      data: {
        'type': 'booking',
        'subType': 'completed',
        'bookingId': bookingId,
        'action': 'open_booking',
      },
    );
  }

  Future<void> sendBookingCancelledNotification({
    required String bookingId,
    required String serviceType,
    String? reason,
    String? cancelledBy, required String userName, // Added for compatibility
  }) async {
    await _sendNotification(
      channelId: _bookingChannelId,
      channelName: _bookingChannelName,
      title: '🚫 Booking Cancelled',
      body: 'Your $serviceType booking was cancelled${reason != null ? ": $reason" : ""}',
      importance: Importance.high,
      priority: Priority.high,
      data: {
        'type': 'booking',
        'subType': 'cancelled',
        'bookingId': bookingId,
        'action': 'open_booking',
      },
    );
  }

  // ========================= JOB NOTIFICATIONS =========================

Future<void> sendJobPostedNotification({
  required String jobId,
  required String jobTitle,
  required String category,
  required String customerName,
  required double distanceKm,
  String? budget,
}) async {
  await _sendNotification(
    channelId: _jobChannelId,
    channelName: _jobChannelName,
    title: '💼 New $category Job',
    body: '$customerName posted: $jobTitle (${distanceKm.toStringAsFixed(1)}km away)',
    importance: Importance.high,
    priority: Priority.high,
    playSound: true,
    enableVibration: true,
    data: {
      'type': 'job',
      'subType': 'new_job',
      'jobId': jobId,
      'action': 'open_job',
    },
  );
}

Future<void> sendJobMatchedNotification({
  required String jobId,
  required String jobTitle,
  required String customerName,
  required double distanceKm,
  required double matchScore,
}) async {
  await _sendNotification(
    channelId: _jobChannelId,
    channelName: _jobChannelName,
    title: '🎯 Job Match',
    body: 'Perfect match! $jobTitle by $customerName (${distanceKm.toStringAsFixed(1)}km)',
    importance: Importance.high,
    priority: Priority.high,
    playSound: true,
    enableVibration: true,
    data: {
      'type': 'job',
      'subType': 'job_match',
      'jobId': jobId,
      'matchScore': matchScore.toString(),
      'action': 'open_job',
    },
  );
}

Future<void> sendJobAcceptedNotification({
  required String jobId,
  required String artisanName,
  required String category,
}) async {
  await _sendNotification(
    channelId: _jobChannelId,
    channelName: _jobChannelName,
    title: '✅ Job Accepted',
    body: '$artisanName accepted your $category job request',
    importance: Importance.high,
    priority: Priority.high,
    data: {
      'type': 'job',
      'subType': 'job_accepted',
      'jobId': jobId,
      'action': 'open_job',
    },
  );
}

  // Legacy method for backward compatibility
  Future<void> sendLocalNotification({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    // Default to system channel for generic notifications
    await sendSystemNotification(
      title: title,
      body: body,
      data: data,
    );
  }

  // ========================= SYSTEM NOTIFICATIONS =========================

  Future<void> sendSystemNotification({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    await _sendNotification(
      channelId: _systemChannelId,
      channelName: _systemChannelName,
      title: title,
      body: body,
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      playSound: false,
      enableVibration: false,
      data: data ?? {
        'type': 'system',
        'action': 'none',
      },
    );
  }

  // ========================= NAVIGATION HANDLING =========================

  Function(Map<String, dynamic>)? _onNotificationTap;

  void setNotificationHandler(Function(Map<String, dynamic>) handler) {
    _onNotificationTap = handler;
    print('📌 Notification handler set');
  }

  void _handleNotificationResponse(NotificationResponse response) {
    print('👆 Notification tapped: ${response.payload}');
    
    if (response.payload != null && _onNotificationTap != null) {
      try {
        final Map<String, dynamic> data = json.decode(response.payload!);
        _onNotificationTap!(data);
      } catch (e) {
        print('❌ Error parsing notification data: $e');
      }
    }
  }

  // ========================= UTILITY METHODS =========================

  Future<void> cancelNotification(int id) async {
    await _localNotifications.cancel(id);
  }

  Future<void> cancelAllNotifications() async {
    await _localNotifications.cancelAll();
  }

  Future<List<ActiveNotification>> getActiveNotifications() async {
    if (Platform.isAndroid) {
      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      return await androidPlugin?.getActiveNotifications() ?? [];
    }
    return [];
  }
}