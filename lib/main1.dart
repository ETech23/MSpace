import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/di/injection_container.dart';
import 'core/config/supabase_config.dart';
import 'core/router/app_router.dart';
import 'core/services/notification_service.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/services/fcm_notification_service.dart';
import 'package:timeago/timeago.dart' as timeago;

// ✅ Global navigator key for notification navigation
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// ✅ Background message handler (MUST be top-level)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print('📩 Background notification: ${message.notification?.title}');
  
  // Show local notification when app is in background
  final notificationService = NotificationService();
  await notificationService.initialize();
  
  final data = message.data;
  final notification = message.notification;
  
  if (notification != null) {
    final type = data['type'] ?? 'system';
    
    if (type == 'message') {
      await notificationService.sendMessageNotification(
        senderName: notification.title ?? 'New Message',
        messageText: notification.body ?? '',
        conversationId: data['conversationId'] ?? '',
        senderId: data['senderId'] ?? '',
      );
    } else if (type == 'booking') {
      await notificationService.sendLocalNotification(
        title: notification.title ?? 'Booking Update',
        body: notification.body ?? '',
        data: data,
      );
    } else {
      await notificationService.sendSystemNotification(
        title: notification.title ?? 'Notification',
        body: notification.body ?? '',
        data: data,
      );
    }
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // ✅ Set timeago locale (optional, defaults to English)
  timeago.setLocaleMessages('en', timeago.EnMessages());
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Register background message handler
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // Initialize Supabase
  await SupabaseConfig.initialize();

  // Initialize local notifications
  if (!kIsWeb) {
    try {
      final notificationService = NotificationService();
      await notificationService.initialize();
      print('✅ Local notifications initialized');
    } catch (e) {
      print('❌ Notification init error: $e');
    }
  }

  // Initialize dependency injection
  await init();

  runApp(
    ProviderScope(
      child: ArtisanMarketplaceApp(navigatorKey: navigatorKey),
    ),
  );
}

class ArtisanMarketplaceApp extends ConsumerStatefulWidget {
  final GlobalKey<NavigatorState> navigatorKey;
  
  const ArtisanMarketplaceApp({super.key, required this.navigatorKey});

  @override
  ConsumerState<ArtisanMarketplaceApp> createState() => _ArtisanMarketplaceAppState();
}

class _ArtisanMarketplaceAppState extends ConsumerState<ArtisanMarketplaceApp> {
  @override
  void initState() {
    super.initState();
    _initializePushNotifications();
  }

  Future<void> _initializePushNotifications() async {
  await Future.delayed(const Duration(milliseconds: 500));
  
  final user = Supabase.instance.client.auth.currentUser;
  if (user != null) {
    try {
      final fcmService = FCMNotificationService();
      await fcmService.initialize(user.id);
      // Wire notification taps to app navigation
      fcmService.setNotificationHandler((data) {
        _handleNotificationNavigation(data);
      });

      // Also wire local NotificationService taps
      final notificationService = NotificationService();
      notificationService.setNotificationHandler(_handleNotificationNavigation);

      print('✅ FCM initialized for user: ${user.id}');
    } catch (e) {
      print('❌ FCM init error: $e');
    }
  }
}

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notificationService = NotificationService();
    final notification = message.notification;
    final data = message.data;
    
    if (notification == null) return;
    
    final type = data['type'] ?? 'system';
    
    if (type == 'message') {
      await notificationService.sendMessageNotification(
        senderName: notification.title ?? 'New Message',
        messageText: notification.body ?? '',
        conversationId: data['conversationId'] ?? '',
        senderId: data['senderId'] ?? '',
      );
    } else if (type == 'booking') {
      final subType = data['subType'] ?? '';
      final bookingId = data['bookingId'] ?? '';
      
      switch (subType) {
        case 'created':
          await notificationService.sendBookingCreatedNotification(
            bookingId: bookingId,
            serviceType: data['serviceType'] ?? 'service',
          );
          break;
        case 'accepted':
          await notificationService.sendBookingAcceptedNotification(
            bookingId: bookingId,
            artisanName: data['artisanName'] ?? 'Artisan',
            serviceType: data['serviceType'] ?? 'service',
          );
          break;
        case 'rejected':
          await notificationService.sendBookingRejectedNotification(
            bookingId: bookingId,
            artisanName: data['artisanName'] ?? 'Artisan',
            serviceType: data['serviceType'] ?? 'service',
            reason: data['reason'],
          );
          break;
        case 'started':
          await notificationService.sendBookingStartedNotification(
            bookingId: bookingId,
            artisanName: data['artisanName'] ?? 'Artisan',
            serviceType: data['serviceType'] ?? 'service',
          );
          break;
        case 'completed':
          await notificationService.sendBookingCompletedNotification(
            bookingId: bookingId,
            artisanName: data['artisanName'] ?? 'Artisan',
            serviceType: data['serviceType'] ?? 'service',
          );
          break;
        default:
          await notificationService.sendLocalNotification(
            title: notification.title ?? 'Booking Update',
            body: notification.body ?? '',
            data: data,
          );
      }
    } else {
      await notificationService.sendSystemNotification(
        title: notification.title ?? 'Notification',
        body: notification.body ?? '',
        data: data,
      );
    }
  }

  void _handleNotificationNavigation(Map<String, dynamic> data) {
    final router = ref.read(routerProvider);
    final action = data['action'] as String?;
    
    print('🔔 Handling notification tap with action: $action');
    
    if (action == 'open_booking' && data['bookingId'] != null) {
      final bookingId = data['bookingId'] as String;
      router.push('/bookings/$bookingId');
    } else if (action == 'open_chat' && data['conversationId'] != null) {
      final conversationId = data['conversationId'] as String;
      final senderId = data['senderId'] as String?;
      router.push(
        '/chat/$conversationId',
        extra: {
          'otherUserId': senderId ?? '',
          'otherUserName': data['senderName'] ?? 'User',
          'otherUserPhotoUrl': data['senderPhotoUrl'],
        },
      );
    } else if (action == 'open_notifications') {
      router.push('/notifications');
    } else if (action == 'open_job') {
      // Handle job notifications (server sends subType and relatedId)
      final subType = data['subType'] as String? ?? '';
      final relatedId = data['relatedId'] as String? ?? data['jobId'] as String?;

      if (subType == 'job_match' || subType == 'new_job') {
        // For artisans, open the job matches screen
        router.push('/artisan/job-matches');
      } else if (relatedId != null && relatedId.isNotEmpty) {
        // For other job types, open the specific job
        router.push('/jobs/$relatedId');
      } else {
        router.push('/notifications');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'MSpace',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromARGB(255, 206, 195, 224),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          focusedBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide(color: Colors.deepPurple, width: 2),
          ),
          errorBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide(color: Colors.red),
          ),
          filled: true,
          fillColor: Colors.grey[50],
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: const Color.fromARGB(255, 195, 184, 221),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color.fromARGB(255, 192, 177, 223),
            side: const BorderSide(color: Color.fromARGB(255, 205, 193, 233)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey[200]!),
          ),
          color: Colors.white,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Color.fromARGB(255, 215, 205, 238),
          foregroundColor: Colors.white,
          elevation: 4,
        ),
        scaffoldBackgroundColor: Colors.grey[50],
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromARGB(255, 200, 184, 226),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          backgroundColor: Color(0xFF1E1E1E),
          foregroundColor: Colors.white,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey[800]!),
          ),
          color: const Color(0xFF2C2C2C),
        ),
        scaffoldBackgroundColor: const Color(0xFF121212),
      ),
      routerConfig: router,
    );
  }
}