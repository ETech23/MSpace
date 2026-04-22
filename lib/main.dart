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
import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/feed/presentation/providers/feed_provider.dart';
import 'features/trust/presentation/screens/account_blocked_screen.dart';
import 'core/widgets/offline_overlay.dart';
import 'core/ads/ad_remote_config_service.dart';
import 'core/config/feature_flags_service.dart';
import 'core/widgets/app_maintenance_screen.dart';
import 'core/services/install_referrer_service.dart';
import 'core/services/deep_link_service.dart';
import 'core/services/onboarding_service.dart';
import 'package:flutter/services.dart';

List<CameraDescription> cameras = [];

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print('📩 Background message received: ${message.notification?.title}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  Object? bootError;
  StackTrace? bootStackTrace;

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    await SupabaseConfig.initialize();
    await init();
    await InstallReferrerService().captureIfNeeded();
    await DeepLinkService.instance.startListening();
    await OnboardingService.initialize();
  } catch (e, st) {
    bootError = e;
    bootStackTrace = st;
    debugPrint('❌ Pre-boot initialization failed: $e');
    debugPrint(st.toString());
  }

  if (bootError != null) {
    runApp(StartupFailureApp(error: bootError, stackTrace: bootStackTrace));
    return;
  }

  runApp(
    ProviderScope(
      child: ArtisanMarketplaceApp(navigatorKey: navigatorKey),
    ),
  );
}

class StartupFailureApp extends StatelessWidget {
  final Object error;
  final StackTrace? stackTrace;

  const StartupFailureApp({super.key, required this.error, this.stackTrace});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF10131A),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.error_outline,
                        color: Colors.redAccent, size: 56),
                    const SizedBox(height: 16),
                    const Text(
                      'Startup failed',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'The app could not finish initialization. '
                      'Please restart and check logs.',
                      style: TextStyle(color: Colors.white70, height: 1.4),
                    ),
                    const SizedBox(height: 16),
                    SelectableText(
                      error.toString(),
                      style: const TextStyle(
                        color: Colors.amberAccent,
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                    if (stackTrace != null) ...[
                      const SizedBox(height: 12),
                      Expanded(
                        child: SingleChildScrollView(
                          child: SelectableText(
                            stackTrace.toString(),
                            style: const TextStyle(
                              color: Colors.white54,
                              fontFamily: 'monospace',
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ArtisanMarketplaceApp extends ConsumerStatefulWidget {
  final GlobalKey<NavigatorState> navigatorKey;

  const ArtisanMarketplaceApp({super.key, required this.navigatorKey});

  @override
  ConsumerState<ArtisanMarketplaceApp> createState() =>
      _ArtisanMarketplaceAppState();
}

class _ArtisanMarketplaceAppState
    extends ConsumerState<ArtisanMarketplaceApp> {
  @override
  void initState() {
    super.initState();
    _warmUpServices();
    _initializePushNotifications();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Supabase.instance.client.auth.onAuthStateChange.listen((data) {
        if (!mounted) return;
        final router = ref.read(routerProvider);

        // Only handle passwordRecovery — this is reliably triggered ONLY
        // when the user taps the reset password deep link.
        // We do NOT handle signedIn here because Supabase fires it on every
        // session restore and token refresh, making it impossible to
        // distinguish a fresh email confirmation from a regular app open.
        // The email-confirmed screen is reached via the errorBuilder deep
        // link intercept in app_router.dart instead.
        if (data.event == AuthChangeEvent.passwordRecovery) {
          router.go('/reset-password');
        }
      });
    });
  }

  Future<void> _warmUpServices() async {
    if (kIsWeb) return;

    try {
      final notificationService = NotificationService();
      await notificationService.initialize();
      print('✅ Local notifications initialized');
    } catch (e) {
      print('❌ Notification init error: $e');
    }

    try {
      cameras = await availableCameras();
    } catch (e) {
      print('Error initializing cameras: $e');
    }

    try {
      await MobileAds.instance.initialize();
      await AdRemoteConfigService.instance.initialize();
      await FeatureFlagsService.instance.initialize();
    } catch (e) {
      print('❌ Mobile ads init error: $e');
    }
  }

  Future<void> _initializePushNotifications() async {
    await Future.delayed(const Duration(milliseconds: 500));

    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      try {
        final fcmService = FCMNotificationService();
        await fcmService.initialize(user.id);

        fcmService.setNotificationHandler((data) {
          _handleNotificationNavigation(data);
        });

        final notificationService = NotificationService();
        notificationService
            .setNotificationHandler(_handleNotificationNavigation);

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
      final distanceKm = (data['distanceKm'] is num)
          ? (data['distanceKm'] as num).toDouble()
          : 0.0;

      if (subType == 'job_match') {
        await notificationService.sendJobMatchedNotification(
          jobId: jobId,
          jobTitle: jobTitle,
          customerName: customerName,
          distanceKm: distanceKm,
          matchScore: (data['matchScore'] is num)
              ? (data['matchScore'] as num).toDouble()
              : 0.0,
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

  String? _extractDisputeId(Map<String, dynamic> data) {
    final candidates = [
      data['disputeId'],
      data['dispute_id'],
      data['relatedId'],
      data['related_id'],
      data['id'],
    ];
    for (final value in candidates) {
      if (value == null) continue;
      final parsed = value.toString().trim();
      if (parsed.isNotEmpty) return parsed;
    }
    return null;
  }

  String? _extractBookingId(Map<String, dynamic> data) {
    final candidates = [data['bookingId'], data['booking_id']];
    for (final value in candidates) {
      if (value == null) continue;
      final parsed = value.toString().trim();
      if (parsed.isNotEmpty) return parsed;
    }
    return null;
  }

  void _handleNotificationNavigation(Map<String, dynamic> data) {
    final router = ref.read(routerProvider);
    final action = data['action'] as String?;

    print('🔔 Notification tap payload: $data');
    print('🔔 Handling notification tap with action: $action');

    final dataType = data['type'] as String?;
    final disputeId = _extractDisputeId(data);
    if ((action == 'open_dispute' || dataType == 'dispute') &&
        disputeId != null) {
      final bookingId = _extractBookingId(data);
      final query = bookingId != null ? '?bookingId=$bookingId' : '';
      router.push('/disputes/$disputeId/hearing$query');
    } else if (dataType == 'dispute' &&
        (data['subType'] == 'admin_new_dispute' ||
            action == 'open_notifications')) {
      router.push('/admin/disputes');
    } else if (action == 'open_booking' && data['bookingId'] != null) {
      router.push('/bookings/${data['bookingId']}');
    } else if (action == 'open_chat' && data['conversationId'] != null) {
      router.push(
        '/chat/${data['conversationId']}',
        extra: {
          'otherUserId': data['senderId'] ?? '',
          'otherUserName': data['senderName'] ?? 'User',
          'otherUserPhotoUrl': data['senderPhotoUrl'],
        },
      );
    } else if (action == 'open_notifications') {
      router.push('/notifications');
    } else if (action == 'open_profile_analytics') {
      router.push('/profile/analytics');
    } else if (action == 'open_feed_tips') {
      router.push('/feed?tab=tips');
    } else if (action == 'open_appeal') {
      router.push('/notifications');
    } else if (action == 'open_job') {
      final subType = data['subType'] as String? ?? '';
      final relatedId =
          data['relatedId'] as String? ?? data['jobId'] as String?;

      if (subType == 'job_match' || subType == 'new_job') {
        router.push('/artisan/job-matches');
      } else if (relatedId != null && relatedId.isNotEmpty) {
        router.push('/jobs/$relatedId');
      } else {
        router.push('/notifications');
      }
    } else {
      router.push('/notifications');
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(feedPreloadProvider);

    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);
    final moderationStatusAsync =
        ref.watch(currentUserModerationStatusProvider);
    final isBlocked = moderationStatusAsync.maybeWhen(
      data: (status) => status == 'blocked',
      orElse: () => false,
    );

    return MaterialApp.router(
      title: 'MSpace',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      builder: (context, child) {
        return ValueListenableBuilder(
          valueListenable: FeatureFlagsService.instance.flagsListenable,
          builder: (context, flags, _) {
            if (flags.maintenanceMode) {
              return AppMaintenanceScreen(
                message: flags.maintenanceMessage,
                onRetry: () => FeatureFlagsService.instance.refresh(),
              );
            }
            if (isBlocked) {
              return const OfflineOverlay(child: AccountBlockedScreen());
            }
            return OfflineOverlay(
              child: child ?? const SizedBox.shrink(),
            );
          },
        );
      },
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2196F3),
          primary: const Color(0xFF1976D2),
          secondary: const Color(0xFF42A5F5),
          tertiary: const Color(0xFF64B5F6),
          surface: Colors.white,
          background: const Color(0xFFF5F9FF),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: AppBarTheme(
          centerTitle: false,
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF1565C0),
          surfaceTintColor: Colors.transparent,
          toolbarHeight: 64,
          iconTheme: const IconThemeData(color: Color(0xFF1565C0)),
          actionsIconTheme: const IconThemeData(color: Color(0xFF1565C0)),
          titleTextStyle: const TextStyle(
            color: Color(0xFF1565C0),
            fontSize: 20,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.15,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide:
                const BorderSide(color: Color(0xFFE3F2FD), width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide:
                const BorderSide(color: Color(0xFF2196F3), width: 2.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide:
                const BorderSide(color: Color(0xFFEF5350), width: 1.5),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide:
                const BorderSide(color: Color(0xFFEF5350), width: 2.5),
          ),
          filled: true,
          fillColor: const Color(0xFFFAFDFF),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          hintStyle: TextStyle(
            color: Colors.grey[400],
            fontSize: 15,
            fontWeight: FontWeight.w400,
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF2196F3),
            foregroundColor: Colors.white,
            padding:
                const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
            elevation: 0,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF1976D2),
            side: const BorderSide(color: Color(0xFF2196F3), width: 2),
            padding:
                const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shadowColor: const Color(0xFF1976D2).withOpacity(0.08),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          color: Colors.white,
          surfaceTintColor: const Color(0xFFF5F9FF),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: const Color(0xFF2196F3),
          foregroundColor: Colors.white,
          elevation: 6,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18)),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: const Color(0xFFE3F2FD),
          selectedColor: const Color(0xFF2196F3),
          labelStyle: const TextStyle(
            color: Color(0xFF1565C0),
            fontWeight: FontWeight.w500,
          ),
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Colors.white,
          selectedItemColor: Color(0xFF1976D2),
          unselectedItemColor: Color(0xFF90CAF9),
          selectedLabelStyle:
              TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
          type: BottomNavigationBarType.fixed,
          elevation: 8,
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: Colors.white,
          elevation: 8,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24)),
        ),
        dividerTheme: DividerThemeData(
          color: const Color(0xFFE3F2FD),
          thickness: 1,
          space: 1,
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: Color(0xFF2196F3),
        ),
        scaffoldBackgroundColor: const Color(0xFFF8FBFF),
        listTileTheme: const ListTileThemeData(
          contentPadding:
              EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(12))),
        ),
      ),
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
            borderSide:
                const BorderSide(color: Color(0xFF1E3A5F), width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide:
                const BorderSide(color: Color(0xFF42A5F5), width: 2.5),
          ),
          filled: true,
          fillColor: const Color(0xFF1A1F2E),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shadowColor: const Color(0xFF42A5F5).withOpacity(0.15),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          color: const Color(0xFF1E1E2E),
          surfaceTintColor: const Color(0xFF1E3A5F),
        ),
        scaffoldBackgroundColor: const Color(0xFF0D1117),
        dividerTheme: const DividerThemeData(color: Color(0xFF1E3A5F)),
      ),
      routerConfig: router,
    );
  }
}


