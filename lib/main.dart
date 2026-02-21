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
import 'package:camera/camera.dart';
import 'core/providers/theme_provider.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

List<CameraDescription> cameras = [];

// ✅ Global navigator key for notification navigation
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// ✅ Background message handler (MUST be top-level)
// Simplified background handler - just log
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print('📩 Background message received: ${message.notification?.title}');
  // FCM automatically displays the notification - we don't need to do anything!
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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

  // Initialize cameras
  try {
    cameras = await availableCameras();
  } catch (e) {
    print('Error initializing cameras: $e');
  }

  // Initialize dependency injection
  await init();

  // google_mobile_ads does not implement web plugins.
  if (!kIsWeb) {
    await MobileAds.instance.initialize();
  }

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
    } else if (type == 'job') {
      final subType = data['subType'] ?? '';
      final jobId = data['jobId'] ?? data['relatedId'] ?? '';
      final jobTitle = data['jobTitle'] ?? '';
      final customerName = data['customerName'] ?? '';
      final distanceKm = (data['distanceKm'] is num) ? (data['distanceKm'] as num).toDouble() : 0.0;

      if (subType == 'job_match') {
        await notificationService.sendJobMatchedNotification(
          jobId: jobId,
          jobTitle: jobTitle,
          customerName: customerName,
          distanceKm: distanceKm,
          matchScore: (data['matchScore'] is num) ? (data['matchScore'] as num).toDouble() : 0.0,
        );
      } else {
        await notificationService.sendJobPostedNotification(
          jobId: jobId,
          jobTitle: jobTitle,
          category: data['category'] ?? 'service',
          customerName: customerName,
          distanceKm: distanceKm,
          budget: data['budget'] ?? null,
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

    // Detailed debug logs for notification navigation
    print('🔔 Notification tap payload: $data');
    print('🔔 Handling notification tap with action: $action');

    if (action == 'open_booking' && data['bookingId'] != null) {
      final bookingId = data['bookingId'] as String;
      print('🔀 Navigating to /bookings/$bookingId');
      router.push('/bookings/$bookingId');
    } else if (action == 'open_chat' && data['conversationId'] != null) {
      final conversationId = data['conversationId'] as String;
      final senderId = data['senderId'] as String?;
      print('🔀 Navigating to /chat/$conversationId (otherUserId=${senderId ?? ''})');
      router.push(
        '/chat/$conversationId',
        extra: {
          'otherUserId': senderId ?? '',
          'otherUserName': data['senderName'] ?? 'User',
          'otherUserPhotoUrl': data['senderPhotoUrl'],
        },
      );
    } else if (action == 'open_notifications') {
      print('🔀 Navigating to /notifications');
      router.push('/notifications');
    } else if (action == 'open_job') {
      // Handle job notifications (server sends subType and relatedId)
      final subType = data['subType'] as String? ?? '';
      final relatedId = data['relatedId'] as String? ?? data['jobId'] as String?;

      if (subType == 'job_match' || subType == 'new_job') {
        print('🔀 Navigating to /artisan/job-matches (job_match/new_job)');
        // For artisans, open the job matches screen
        router.push('/artisan/job-matches');
      } else if (relatedId != null && relatedId.isNotEmpty) {
        print('🔀 Navigating to /jobs/$relatedId');
        // For other job types, open the specific job
        router.push('/jobs/$relatedId');
      } else {
        print('🔀 No valid job id found; falling back to /notifications');
        router.push('/notifications');
      }
    } else {
      print('⚠️ Unknown notification action; opening notifications screen');
      router.push('/notifications');
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'MSpace',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: ThemeData(
        // Modern blue gradient color scheme
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2196F3), // Primary blue
          primary: const Color(0xFF1976D2), // Deep blue
          secondary: const Color(0xFF42A5F5), // Light blue
          tertiary: const Color(0xFF64B5F6), // Sky blue
          surface: Colors.white,
          background: const Color(0xFFF5F9FF), // Very light blue tint
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        
        // Modern AppBar with gradient effect
        appBarTheme: AppBarTheme(
          centerTitle: false,
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF1565C0),
          surfaceTintColor: Colors.transparent,
          toolbarHeight: 64,
          iconTheme: const IconThemeData(
            color: Color(0xFF1565C0),
          ),
          actionsIconTheme: const IconThemeData(
            color: Color(0xFF1565C0),
          ),
          titleTextStyle: const TextStyle(
            color: Color(0xFF1565C0),
            fontSize: 20,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.15,
          ),
        ),
        
        // Elegant input fields with blue accents
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFE3F2FD), width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF2196F3), width: 2.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFEF5350), width: 1.5),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFEF5350), width: 2.5),
          ),
          filled: true,
          fillColor: const Color(0xFFFAFDFF),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          hintStyle: TextStyle(
            color: Colors.grey[400],
            fontSize: 15,
            fontWeight: FontWeight.w400,
          ),
        ),
        
        // Modern gradient button
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF2196F3),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
            elevation: 0,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),
        
        // Outlined button with blue theme
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF1976D2),
            side: const BorderSide(color: Color(0xFF2196F3), width: 2),
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),
        
        // Elevated cards with subtle shadow
        cardTheme: CardThemeData(
          elevation: 2,
          shadowColor: const Color(0xFF1976D2).withOpacity(0.08),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          color: Colors.white,
          surfaceTintColor: const Color(0xFFF5F9FF),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
        
        // Modern FAB
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: const Color(0xFF2196F3),
          foregroundColor: Colors.white,
          elevation: 6,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        
        // Chip theme for tags/categories
        chipTheme: ChipThemeData(
          backgroundColor: const Color(0xFFE3F2FD),
          selectedColor: const Color(0xFF2196F3),
          labelStyle: const TextStyle(
            color: Color(0xFF1565C0),
            fontWeight: FontWeight.w500,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        
        // Bottom navigation with subtle elevation
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Colors.white,
          selectedItemColor: Color(0xFF1976D2),
          unselectedItemColor: Color(0xFF90CAF9),
          selectedLabelStyle: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
          type: BottomNavigationBarType.fixed,
          elevation: 8,
        ),
        
        // Dialog theme
        dialogTheme: DialogThemeData(
          backgroundColor: Colors.white,
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
        
        // Divider
        dividerTheme: DividerThemeData(
          color: const Color(0xFFE3F2FD),
          thickness: 1,
          space: 1,
        ),
        
        // Progress indicator
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: Color(0xFF2196F3),
        ),
        
        scaffoldBackgroundColor: const Color(0xFFF8FBFF),
        
        // List tile theme
        listTileTheme: const ListTileThemeData(
          contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
      ),
      
      // Dark theme with deep blue accents
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF42A5F5),
          primary: const Color(0xFF42A5F5),
          secondary: const Color(0xFF64B5F6),
          tertiary: const Color(0xFF90CAF9),
          surface: const Color(0xFF1E1E2E),
          background: const Color(0xFF0D1117),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          backgroundColor: Color(0xFF1E1E2E),
          foregroundColor: Color(0xFF90CAF9),
          surfaceTintColor: Colors.transparent,
          toolbarHeight: 64,
          titleTextStyle: TextStyle(
            color: Color(0xFF90CAF9),
            fontSize: 20,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.15,
          ),
        ),
        
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF2D3748)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF1E3A5F), width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF42A5F5), width: 2.5),
          ),
          filled: true,
          fillColor: const Color(0xFF1A1F2E),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        ),
        
        cardTheme: CardThemeData(
          elevation: 2,
          shadowColor: const Color(0xFF42A5F5).withOpacity(0.15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          color: const Color(0xFF1E1E2E),
          surfaceTintColor: const Color(0xFF1E3A5F),
        ),
        
        scaffoldBackgroundColor: const Color(0xFF0D1117),
        
        dividerTheme: const DividerThemeData(
          color: Color(0xFF1E3A5F),
        ),
      ),
      
      routerConfig: router,
    );
  }
}
