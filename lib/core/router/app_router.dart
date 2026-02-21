// lib/core/router/app_router.dart
import 'package:artisan_marketplace/features/jobs/presentation/screens/my_jobs_screen.dart';
import 'package:artisan_marketplace/features/jobs/presentation/screens/post_job_screen.dart';
import 'package:artisan_marketplace/features/reviews/presentation/screens/create_review_screen.dart';
import 'package:artisan_marketplace/features/reviews/presentation/screens/user_reviews_screen.dart';
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
import '../../features/messaging/presentation/screens/conversations_screen.dart';
import '../../features/messaging/presentation/screens/chat_screen.dart';
import 'package:artisan_marketplace/features/home/presentation/screens/settings_screen.dart';

import 'package:artisan_marketplace/features/reviews/presentation/screens/specific_user_reviews_screen.dart';

import '../../features/jobs/presentation/screens/job_details_screen.dart';
import '../../features/jobs/presentation/screens/artisan_job_matches_screen.dart';
import '../../features/feed/presentation/screens/feed_screen.dart';
import '../../features/trust/presentation/screens/identity_verification_screen.dart';
import '../../features/trust/presentation/screens/dispute_form_screen.dart';
import '../../features/trust/presentation/screens/report_form_screen.dart';
import '../../features/trust/presentation/screens/admin_identity_reviews_screen.dart';
import '../../features/trust/presentation/screens/admin_disputes_screen.dart';
import '../../features/trust/presentation/screens/admin_reports_screen.dart';
import '../../features/trust/presentation/screens/blocked_users_screen.dart';

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
      GoRoute(
        path: '/feed',
        name: 'feed',
        builder: (context, state) => const FeedScreen(),
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

// MESSAGES ROUTES:
GoRoute(
  path: '/messages',
  name: 'messages',
  builder: (context, state) => const ConversationsScreen(),
),

// ROUTE FOR CHAT:
GoRoute(
  path: '/chat/:conversationId',
  name: 'chat',
  builder: (context, state) {
    final conversationId = state.pathParameters['conversationId'] ?? '';
    final extra = state.extra as Map<String, dynamic>?;
    
    return ChatScreen(
      conversationId: conversationId,
      otherUserId: extra?['otherUserId'] ?? '',
      otherUserName: extra?['otherUserName'] ?? 'User',
      otherUserPhotoUrl: extra?['otherUserPhotoUrl'],
    );
  },
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
        path: '/profile/blocked',
        name: 'profile-blocked',
        builder: (context, state) => const BlockedUsersScreen(),
      ),
      GoRoute(
        path: '/profile/saved',
        name: 'profile-saved',
        builder: (context, state) => const SavedArtisansScreen(),
      ),
      GoRoute(
        path: '/profile/verify',
        name: 'profile-verify',
        builder: (context, state) => const IdentityVerificationScreen(),
      ),

      GoRoute(
        path: '/profile/settings',
        name: 'settings',
        builder: (context, state) => const SettingsScreen(),
      ),

      GoRoute(
  path: '/reviews',
  name: 'reviews',
  builder: (context, state) => const UserReviewsScreen(),
),
GoRoute(
  path: '/reviews/create',
  name: 'createReview',
  builder: (context, state) {
    final extra = state.extra as Map<String, dynamic>;
    return CreateReviewScreen(
      bookingId: extra['bookingId'],
      artisanId: extra['artisanId'],
      artisanName: extra['artisanName'],
      artisanPhotoUrl: extra['artisanPhotoUrl'],
    );
  },
),

    // Route for viewing a specific user's reviews
GoRoute(
  path: '/reviews/user/:userId',
  name: 'userReviews',
  builder: (context, state) {
    final userId = state.pathParameters['userId']!;
    final extra = state.extra as Map<String, dynamic>?;
    
    return SpecificUserReviewsScreen(
      userId: userId,
      userName: extra?['userName'] as String? ?? 'User',
      userType: extra?['userType'] as String? ?? 'artisan',
    );
  },
),
      // Artisan - specific routes first to avoid ambiguous matches
      GoRoute(
        path: '/artisan/job-matches',
        builder: (context, state) => const ArtisanJobMatchesScreen(),
      ),

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
      GoRoute(
        path: '/bookings/:id/dispute',
        name: 'booking-dispute',
        builder: (context, state) {
          final bookingId = state.pathParameters['id'] ?? '';
          return DisputeFormScreen(bookingId: bookingId);
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

// In your router:
GoRoute(
  path: '/jobs/:id',
  builder: (context, state) => JobDetailsScreen(
    jobId: state.pathParameters['id']!,
  ),
),

GoRoute(
  path: '/post-job',
  builder: (context, state) => PostJobScreen(),
),

GoRoute(
  path: '/report',
  name: 'report',
  builder: (context, state) {
    final extra = state.extra as Map<String, dynamic>? ?? {};
    return ReportFormScreen(
      targetType: extra['targetType'] as String? ?? 'user',
      targetId: extra['targetId'] as String? ?? '',
      targetLabel: extra['targetLabel'] as String? ?? 'Item',
    );
  },
),
/** GoRoute(
  path: '/jobs/:id',
  builder: (context, state) => JobDetailsScreen(
    jobId: state.pathParameters['id']!,
  ),
),**/


GoRoute(
  path: '/my-jobs',
  builder: (context, state) => const MyJobsScreen(),
),

// Admin review routes
GoRoute(
  path: '/admin/identity',
  builder: (context, state) => const AdminIdentityReviewsScreen(),
),
GoRoute(
  path: '/admin/disputes',
  builder: (context, state) => const AdminDisputesScreen(),
),
GoRoute(
  path: '/admin/reports',
  builder: (context, state) => const AdminReportsScreen(),
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
