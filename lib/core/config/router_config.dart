// lib/core/router/app_router.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/home/presentation/screens/splash_screen.dart';
import '../../features/home/presentation/screens/artisan_detail_screen.dart';
import '../../features/home/presentation/screens/location_capture_screen.dart';
import '../../features/home/presentation/screens/profile_screen.dart';
import '../../features/home/presentation/screens/edit_profile_screen.dart';
import '../../features/home/domain/entities/artisan_entity.dart';
import '../../features/booking/presentation/screens/create_booking_screen.dart';
import '../../features/booking/presentation/screens/booking_list_screen.dart';
import '../../features/booking/presentation/screens/booking_detail_screen.dart';
import '../../features/booking/domain/entities/booking_entity.dart';
import '../../features/search/presentation/screens/search_screen.dart';
import '../../features/profile/presentation/screens/notification_settings_screen.dart';
import '../../features/profile/presentation/screens/privacy_settings_screen.dart';
import '../../features/profile/presentation/screens/saved_artisans_screen.dart';
import '../../features/notifications/presentation/screens/notifications_screen.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = 
    GlobalKey<NavigatorState>(debugLabel: 'root');

final routerProvider = Provider<GoRouter>((ref) {
  final isInitialized = ref.watch(isAuthInitializedProvider);
  
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    debugLogDiagnostics: true,
    initialLocation: '/splash',
    
    redirect: (context, state) {
      if (!isInitialized && state.matchedLocation != '/splash') {
        return '/splash';
      }
      return null;
    },
    
    routes: [
      // Splash
      GoRoute(
        path: '/splash',
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),

      // Home
      GoRoute(
        path: '/home',
        name: 'home',
        builder: (context, state) => const HomeScreen(),
      ),

      // Auth
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        builder: (context, state) => const RegisterScreen(),
      ),

      // Location Setup
      GoRoute(
        path: '/location-setup',
        name: 'location-setup',
        builder: (context, state) {
          final userId = state.uri.queryParameters['userId'] ?? '';
          final isArtisan = state.uri.queryParameters['isArtisan'] == 'true';
          return LocationCaptureScreen(userId: userId, isArtisan: isArtisan);
        },
      ),

      // Notifications
      GoRoute(
        path: '/notifications',
        name: 'notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),

      // Messages (Coming Soon Placeholder)
      GoRoute(
        path: '/messages',
        name: 'messages',
        builder: (context, state) => Scaffold(
          appBar: AppBar(title: const Text('Messages')),
          body: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.message, size: 80, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'Messaging feature coming soon!',
                  style: TextStyle(fontSize: 18),
                ),
                SizedBox(height: 8),
                Text(
                  'You\'ll be able to chat with artisans here',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ),

      // Profile
      GoRoute(
        path: '/profile',
        name: 'profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/profile/edit',
        name: 'profile-edit',
        builder: (context, state) => const EditProfileScreen(),
      ),
      GoRoute(
        path: '/profile/notifications',
        name: 'profile-notifications',
        builder: (context, state) => const NotificationSettingsScreen(),
      ),
      GoRoute(
        path: '/profile/privacy',
        name: 'profile-privacy',
        builder: (context, state) => const PrivacySettingsScreen(),
      ),
      GoRoute(
        path: '/profile/saved',
        name: 'profile-saved',
        builder: (context, state) => const SavedArtisansScreen(),
      ),

      // Artisan
      GoRoute(
        path: '/artisan/:id',
        name: 'artisan-detail',
        builder: (context, state) {
          final artisanId = state.pathParameters['id'] ?? '';
          return ArtisanDetailScreen(artisanId: artisanId);
        },
      ),

      // Bookings
      GoRoute(
        path: '/bookings',
        name: 'bookings',
        builder: (context, state) => const BookingListScreen(),
      ),
      GoRoute(
        path: '/bookings/create',
        name: 'create-booking',
        builder: (context, state) {
          final artisan = state.extra as ArtisanEntity?;
          if (artisan == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) context.go('/home');
            });
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          return CreateBookingScreen(artisan: artisan);
        },
      ),
      GoRoute(
        path: '/bookings/:id',
        name: 'booking-detail',
        builder: (context, state) {
          final bookingId = state.pathParameters['id'] ?? '';
          final booking = state.extra as BookingEntity?;
          return BookingDetailScreen(bookingId: bookingId, booking: booking);
        },
      ),

      // Search
      GoRoute(
        path: '/search',
        name: 'search',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const SearchScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.05),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOut,
                )),
                child: child,
              ),
            );
          },
        ),
      ),
    ],
    
    errorBuilder: (context, state) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Page not found', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(state.uri.toString(), style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => context.go('/home'),
                child: const Text('Go Home'),
              ),
            ],
          ),
        ),
      );
    },
  );
});