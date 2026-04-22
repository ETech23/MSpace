import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Shown after the user taps the confirmation link in their email.
/// Waits for Supabase to establish a session, then routes to location
/// setup (first time) or home (returning confirmed user).
class EmailConfirmedScreen extends ConsumerStatefulWidget {
  const EmailConfirmedScreen({super.key});

  @override
  ConsumerState<EmailConfirmedScreen> createState() =>
      _EmailConfirmedScreenState();
}

class _EmailConfirmedScreenState
    extends ConsumerState<EmailConfirmedScreen> {
  @override
  void initState() {
    super.initState();
    _proceedAfterConfirmation();
  }

  Future<void> _proceedAfterConfirmation() async {
    final supabase = Supabase.instance.client;
    var user = supabase.auth.currentUser;

    // If session is not ready yet (race condition on slow devices),
    // wait up to 5 seconds for it to arrive.
    if (user == null) {
      try {
        final event = await supabase.auth.onAuthStateChange
            .firstWhere((e) => e.session != null)
            .timeout(const Duration(seconds: 5));
        user = event.session?.user;
      } catch (_) {
        if (mounted) context.go('/login');
        return;
      }
    }

    if (!mounted) return;
    if (user == null) {
      context.go('/login');
      return;
    }

    // Brief pause so the user sees the success screen.
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    // Check if this user already has location data.
    // New users won't have it — send them to location setup.
    try {
      final profile = await supabase
          .from('users')
          .select('latitude, longitude, user_type')
          .eq('id', user.id)
          .maybeSingle();

      if (!mounted) return;

      final hasLocation = profile != null &&
          profile['latitude'] != null &&
          profile['longitude'] != null;

      if (!hasLocation) {
        final isArtisan = profile?['user_type'] == 'artisan' ||
            profile?['user_type'] == 'business';
        context.go(
          '/location-setup?userId=${user.id}&isArtisan=$isArtisan',
        );
      } else {
        final isBusiness = profile?['user_type'] == 'business';
        context.go(isBusiness ? '/profile/edit' : '/home');
      }
    } catch (_) {
      if (mounted) context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.verified_rounded,
                  size: 52,
                  color: Colors.green.shade600,
                ),
              ),
              const SizedBox(height: 32),

              Text(
                'Email Confirmed!',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),

              Text(
                'Your account is now active. Welcome to MSpace!',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 36),

              LinearProgressIndicator(
                backgroundColor: colorScheme.surfaceVariant,
                color: Colors.green.shade500,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 12),
              Text(
                'Setting up your account...',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
