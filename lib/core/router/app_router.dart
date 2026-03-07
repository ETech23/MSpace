// lib/core/router/app_router.dart
import 'package:artisan_marketplace/features/auth/presentation/screens/reset_password_screen.dart';
import '../../features/auth/presentation/screens/confirm_email_pending_screen.dart';
import '../../features/auth/presentation/screens/email_confirmed_screen.dart';
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
import '../../features/trust/presentation/screens/dispute_hearing_screen.dart';
import '../../features/trust/presentation/screens/admin_user_management_screen.dart';
import '../../features/trust/presentation/screens/admin_platform_analytics_screen.dart';
import '../config/feature_flags_service.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'root');

/// Builds the reset password screen or error screen depending on
/// what Supabase sent as query parameters.
Widget _buildResetPasswordPage(GoRouterState state) {
  final params = state.uri.queryParameters;
  final error = params['error'];
  final errorDescription = params['error_description'];

  if (error != null) {
    return _ResetErrorScreen(
      description: (errorDescription ?? 'The reset link is invalid or has expired.')
          .replaceAll('+', ' ')
          .replaceAll('%20', ' '),
    );
  }

  return ResetPasswordScreen(
    accessToken: params['access_token'] ?? params['code'],
  );
}

bool _isLoginCallbackUri(Uri uri) {
  final host = uri.host;
  final path = uri.path;
  return host == 'login-callback' ||
      path.startsWith('/login-callback') ||
      path.contains('login-callback');
}

bool _isResetPasswordUri(Uri uri) {
  final host = uri.host;
  final path = uri.path;
  return host == 'reset-password' || path.startsWith('/reset-password');
}

Widget _buildFeatureDisabledScreen({
  required BuildContext context,
  required String title,
  required String message,
}) {
  return Scaffold(
    appBar: AppBar(title: Text(title)),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.block_outlined, size: 64),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => context.go('/home'),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    ),
  );
}

final routerProvider = Provider<GoRouter>((ref) {
  final isInitialized = ref.watch(isAuthInitializedProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    debugLogDiagnostics: true,
    initialLocation: '/splash',

    redirect: (context, state) {
      // Strip trailing slash using the raw URI path — this fires before
      // route matching so GoRouter can correctly find /reset-password
      // when Supabase delivers /reset-password/?code=...
      final uri = state.uri;
      final path = uri.path;
      if (path != '/' && path.endsWith('/')) {
        final stripped = path.substring(0, path.length - 1);
        final query = uri.query.isNotEmpty ? '?${uri.query}' : '';
        return '$stripped$query';
      }

      // Supabase mobile callbacks may arrive with route in URI host:
      // io.supabase.artisanmarketplace://login-callback/?code=...
      if (_isLoginCallbackUri(uri)) {
        return '/email-confirmed';
      }
      if (_isResetPasswordUri(uri) && path != '/reset-password') {
        final query = uri.query.isNotEmpty ? '?${uri.query}' : '';
        return '/reset-password$query';
      }

      if (!isInitialized && state.matchedLocation != '/splash') {
        return '/splash';
      }
      return null;
    },

    routes: [
      // ── Splash ─────────────────────────────────────────────────────────────
      GoRoute(
        path: '/splash',
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),

      // ── Home / Feed ─────────────────────────────────────────────────────────
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

      // ── Auth ────────────────────────────────────────────────────────────────
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

      // Shown immediately after registration — awaiting email confirmation.
      GoRoute(
        path: '/confirm-email',
        name: 'confirm-email',
        builder: (context, state) {
          final email = state.uri.queryParameters['email'] ?? '';
          return ConfirmEmailPendingScreen(email: email);
        },
      ),

      // Shown after user taps confirmation link and app opens via deep link.
      GoRoute(
        path: '/email-confirmed',
        name: 'email-confirmed',
        builder: (context, state) => const EmailConfirmedScreen(),
      ),

      // Password reset — WITHOUT trailing slash.
      // e.g. io.supabase.artisanmarketplace://reset-password?code=...
      GoRoute(
        path: '/reset-password',
        name: 'reset-password',
        builder: (context, state) => _buildResetPasswordPage(state),
      ),


      // ── Location Setup ──────────────────────────────────────────────────────
      GoRoute(
        path: '/location-setup',
        name: 'location-setup',
        builder: (context, state) {
          final userId = state.uri.queryParameters['userId'] ?? '';
          final isArtisan =
              state.uri.queryParameters['isArtisan'] == 'true';
          return LocationCaptureScreen(
              userId: userId, isArtisan: isArtisan);
        },
      ),

      // ── Notifications ───────────────────────────────────────────────────────
      GoRoute(
        path: '/notifications',
        name: 'notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),

      // ── Messaging ───────────────────────────────────────────────────────────
      GoRoute(
        path: '/messages',
        name: 'messages',
        builder: (context, state) {
          final flags = FeatureFlagsService.instance.currentFlags;
          if (flags.disableChat) {
            return _buildFeatureDisabledScreen(
              context: context,
              title: 'Chat Unavailable',
              message: 'Chat is temporarily disabled. Please try again later.',
            );
          }
          return const ConversationsScreen();
        },
      ),
      GoRoute(
        path: '/chat/:conversationId',
        name: 'chat',
        builder: (context, state) {
          final flags = FeatureFlagsService.instance.currentFlags;
          if (flags.disableChat) {
            return _buildFeatureDisabledScreen(
              context: context,
              title: 'Chat Unavailable',
              message: 'Chat is temporarily disabled. Please try again later.',
            );
          }
          final conversationId =
              state.pathParameters['conversationId'] ?? '';
          final extra = state.extra as Map<String, dynamic>?;
          return ChatScreen(
            conversationId: conversationId,
            otherUserId: extra?['otherUserId'] ?? '',
            otherUserName: extra?['otherUserName'] ?? 'User',
            otherUserPhotoUrl: extra?['otherUserPhotoUrl'],
          );
        },
      ),

      // ── Profile ─────────────────────────────────────────────────────────────
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

      // ── Reviews ─────────────────────────────────────────────────────────────
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

      // ── Artisan ─────────────────────────────────────────────────────────────
      GoRoute(
        path: '/artisan/job-matches',
        builder: (context, state) => const ArtisanJobMatchesScreen(),
      ),
      GoRoute(
        path: '/artisan/:id',
        name: 'artisan-detail',
        pageBuilder: (context, state) {
          final artisanId = state.pathParameters['id'] ?? '';
          final initialArtisan = state.extra is ArtisanEntity
              ? state.extra as ArtisanEntity
              : null;
          return CustomTransitionPage(
            key: state.pageKey,
            child: ArtisanDetailScreen(
              artisanId: artisanId,
              initialArtisan: initialArtisan,
            ),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              final curved = CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              );
              return FadeTransition(
                opacity: curved,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.025),
                    end: Offset.zero,
                  ).animate(curved),
                  child: child,
                ),
              );
            },
          );
        },
      ),

      // ── Bookings ────────────────────────────────────────────────────────────
      GoRoute(
        path: '/bookings',
        name: 'bookings',
        builder: (context, state) => const BookingListScreen(),
      ),
      GoRoute(
        path: '/bookings/create',
        name: 'create-booking',
        builder: (context, state) {
          final flags = FeatureFlagsService.instance.currentFlags;
          if (flags.disableBookings) {
            return _buildFeatureDisabledScreen(
              context: context,
              title: 'Bookings Unavailable',
              message: 'Bookings are temporarily disabled. Please try again later.',
            );
          }
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
          return BookingDetailScreen(
              bookingId: bookingId, booking: booking);
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

      // ── Search ──────────────────────────────────────────────────────────────
      GoRoute(
        path: '/search',
        name: 'search',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const SearchScreen(),
          transitionsBuilder:
              (context, animation, secondaryAnimation, child) {
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

      // ── Jobs ────────────────────────────────────────────────────────────────
      GoRoute(
        path: '/jobs/:id',
        builder: (context, state) => JobDetailsScreen(
          jobId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/post-job',
        builder: (context, state) {
          final flags = FeatureFlagsService.instance.currentFlags;
          if (flags.disablePostJob) {
            return _buildFeatureDisabledScreen(
              context: context,
              title: 'Posting Unavailable',
              message: 'Job posting is temporarily disabled. Please try again later.',
            );
          }
          return const PostJobScreen();
        },
      ),
      GoRoute(
        path: '/my-jobs',
        builder: (context, state) => const MyJobsScreen(),
      ),

      // ── Report ──────────────────────────────────────────────────────────────
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

      // ── Admin ────────────────────────────────────────────────────────────────
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
      GoRoute(
        path: '/admin/users',
        builder: (context, state) => const AdminUserManagementScreen(),
      ),
      GoRoute(
        path: '/admin/analytics',
        builder: (context, state) => const AdminPlatformAnalyticsScreen(),
      ),
      GoRoute(
        path: '/disputes/:disputeId/hearing',
        builder: (context, state) {
          final disputeId = state.pathParameters['disputeId'] ?? '';
          final bookingId =
              state.uri.queryParameters['bookingId'] ?? '';
          return DisputeHearingScreen(
            disputeId: disputeId,
            bookingId: bookingId,
          );
        },
      ),
    ],

    errorBuilder: (context, state) {
      // GoRouter's redirect callback does not fire for unmatched routes —
      // errorBuilder is the only hook that receives them. We intercept
      // /reset-password/ (trailing slash appended by Supabase) here and
      // render the correct screen instead of a 404.
      final uri = state.uri;
      if (_isResetPasswordUri(uri)) {
        return _buildResetPasswordPage(state);
      }

      // Email confirmation deep link lands here as:
      // io.supabase.artisanmarketplace://login-callback/?...
      // The host is login-callback which GoRouter sees as a path.
      if (_isLoginCallbackUri(uri)) {
        return const EmailConfirmedScreen();
      }

      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Page not found',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                state.uri.toString(),
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
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

// ── Reset error screen ────────────────────────────────────────────────────────
class _ResetErrorScreen extends StatelessWidget {
  final String description;
  const _ResetErrorScreen({required this.description});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.link_off_rounded,
                  size: 64, color: colorScheme.error),
              const SizedBox(height: 24),
              Text(
                'Link Expired',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                description,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: () => context.go('/login'),
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    textStyle: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  child: const Text('Request New Link'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
