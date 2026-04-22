// lib/features/home/presentation/screens/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../booking/presentation/providers/booking_provider.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../../reviews/presentation/providers/review_provider.dart';
import '../../../trust/presentation/providers/trust_provider.dart';
import '../../../../core/ads/ad_widgets.dart';
import '../../../../core/providers/theme_provider.dart';
import '../../../../core/services/referral_service.dart';
import '../../../profile/presentation/providers/user_profile_provider.dart';
import 'dart:math';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with SingleTickerProviderStateMixin {
  static const String _supportUrl = String.fromEnvironment(
    'SUPPORT_URL',
    defaultValue: 'https://etech23.github.io/MSpace/',
  );
  static const String _supportEmail = String.fromEnvironment(
    'SUPPORT_EMAIL',
    defaultValue: 'support@mspace.app',
  );

  late AnimationController _headerAnim;
  late Animation<double> _headerFade;

  @override
  void initState() {
    super.initState();
    _headerAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _headerFade = CurvedAnimation(parent: _headerAnim, curve: Curves.easeOut);

    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  @override
  void dispose() {
    _headerAnim.dispose();
    super.dispose();
  }

  void _loadData() {
    final user = ref.read(authProvider).user;
    if (user != null) {
      ref.read(settingsProvider.notifier).loadPrivacySettings(user.id);
      ref.read(bookingProvider.notifier).loadUserBookings(
            userId: user.id,
            userType: user.userType,
          );
      ref.read(bookingProvider.notifier).loadBookingStats(
            userId: user.id,
            userType: user.userType,
          );
      ref.read(userProfileProvider.notifier).loadUserProfile(
            userId: user.id,
            userType: user.userType,
          );
      ref.read(savedArtisansProvider.notifier).loadSavedArtisans(user.id);
      if (user.userType == 'artisan') {
        ref.read(reviewProvider.notifier).loadArtisanReviews(user.id);
      } else {
        ref.read(reviewProvider.notifier).loadUserReviews(user.id);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final themeMode = ref.watch(themeModeProvider);
    final privacySettings = ref.watch(settingsProvider).privacySettings;

    if (user == null) return Scaffold(body: _NotLoggedIn());

    if (user.userType == 'admin') {
      return _AdminProfileScreen(
        user: user,
        themeMode: themeMode,
        onLogout: () => _showLogoutDialog(context, ref),
        onThemePicker: () => _showThemePicker(context, ref, themeMode),
        onSupport: () => _openSupport(context),
        onSwitchType: () => _showSwitchDialog(context, ref, user),
        onAbout: () => _showAboutDialog(context, theme),
      );
    }

    final isArtisan = user.isArtisan;
    final isBusiness = user.isBusiness;
    final isPublicProfileEnabled = (privacySettings?.profileVisible ?? true) &&
        (privacySettings?.webProfileVisible ?? true);
    final publicProfileSubtitle = privacySettings == null
        ? 'Preview how your profile appears on the web'
        : isPublicProfileEnabled
            ? 'Preview how your profile appears on the web'
            : !(privacySettings.profileVisible)
                ? 'Profile visibility is off, so your web profile is hidden'
                : 'Turn Web Profile Visible back on to appear online';
    final roleLabel = isBusiness ? 'Business' : (isArtisan ? 'Artisan' : 'Client');
    final bookingCount = ref.watch(bookingProvider).bookings.length;
    final bookingStats = ref.watch(bookingProvider).stats;
    final savedCount = ref.watch(savedArtisansProvider).artisans.length;
    final reviewState = ref.watch(reviewProvider);
    final userStats = ref.watch(userProfileProvider).stats ?? const <String, dynamic>{};
    final reviewCount = reviewState.reviews.length;
    double? avgRating;
    if (isArtisan && reviewCount > 0) {
      avgRating = reviewState.reviews.fold<double>(0, (s, r) => s + r.rating) /
          reviewCount;
    }
    final totalBookings =
        (userStats['totalBookings'] as int?) ?? bookingStats?['total'] ?? bookingCount;
    final completedBookings =
        (userStats['completedBookings'] as int?) ?? bookingStats?['completed'] ?? 0;
    final completionRate =
        totalBookings == 0 ? 0 : ((completedBookings / totalBookings) * 100).round();

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _UserHeader(
            user: user,
            isArtisan: isArtisan,
            isBusiness: isBusiness,
            roleLabel: roleLabel,
            fadeAnim: _headerFade,
            colorScheme: colorScheme,
            onSettings: () => context.push('/profile/settings'),
            onShare: () async {
              final referralService =
                  ReferralService(Supabase.instance.client);
              final code = await referralService.ensureReferralCode(user.id);
              final link = referralService.buildPlayStoreShareLink(
                packageName: 'com.mspace.app',
                code: code,
              );
              Clipboard.setData(ClipboardData(text: link));
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Invite link copied!')),
              );
            },
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Stats row
                  _StatsRow(
                    bookingCount: bookingCount,
                    savedCount: savedCount,
                    isArtisan: isArtisan,
                    reviewCount: reviewCount,
                    avgRating: avgRating,
                    colorScheme: colorScheme,
                    theme: theme,
                  ),
                  const SizedBox(height: 28),

                  // Ad
                  Center(child: BannerAdWidget()),
                  const SizedBox(height: 28),

                  // Activity section
                  _SectionLabel(label: 'Activity', theme: theme),
                  const SizedBox(height: 12),
                  _MenuCard(
                    colorScheme: colorScheme,
                    items: [
                      _MenuItem(
                        icon: Icons.calendar_month_rounded,
                        label: 'My Bookings',
                        subtitle: 'View and manage your bookings',
                        color: const Color(0xFF5C6BC0),
                        badge: bookingCount > 0 ? '$bookingCount' : null,
                        onTap: () => context.push('/bookings'),
                      ),
                      _MenuItem(
                        icon: Icons.favorite_rounded,
                        label: 'Saved Artisans',
                        subtitle: 'Your favourite professionals',
                        color: const Color(0xFFE53935),
                        onTap: () => context.push('/profile/saved'),
                      ),
                      _MenuItem(
                        icon: Icons.star_rounded,
                        label: 'Reviews & Ratings',
                        subtitle: isArtisan
                            ? 'Reviews you received'
                            : 'Reviews you left',
                        color: const Color(0xFFFFA000),
                        onTap: () => context.push('/reviews'),
                      ),
                      _MenuItem(
                        icon: Icons.receipt_long_rounded,
                        label: 'Invoices',
                        subtitle: 'Create, print, and share invoice PDFs',
                        color: const Color(0xFF00897B),
                        onTap: () => context.push('/profile/invoices'),
                      ),
                      _MenuItem(
                        icon: Icons.analytics_rounded,
                        label: 'My Analytics',
                        subtitle: 'Completion rate: $completionRate% across $totalBookings bookings',
                        color: const Color(0xFF6A1B9A),
                        onTap: () => context.push('/profile/analytics'),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Account section
                  _SectionLabel(label: 'Account', theme: theme),
                  const SizedBox(height: 12),
                  _MenuCard(
                    colorScheme: colorScheme,
                    items: [
                      _MenuItem(
                        icon: Icons.person_rounded,
                        label: 'Edit Profile',
                        subtitle: 'Update your personal information',
                        color: const Color(0xFF1E88E5),
                        onTap: () => context.push('/profile/edit'),
                      ),
                      if (isArtisan || isBusiness)
                        _MenuItem(
                          icon: isPublicProfileEnabled
                              ? Icons.public_rounded
                              : Icons.public_off_rounded,
                          label: 'Open Public Profile',
                          subtitle: publicProfileSubtitle,
                          color: isPublicProfileEnabled
                              ? const Color(0xFF00897B)
                              : const Color(0xFF757575),
                          onTap: () => isPublicProfileEnabled
                              ? _openPublicProfile(context, user.id)
                              : context.push('/profile/privacy'),
                        ),
                      _MenuItem(
                        icon: Icons.verified_user_rounded,
                        label: 'Identity Verification',
                        subtitle: 'Submit ID for verification',
                        color: const Color(0xFF43A047),
                        onTap: () => context.push('/profile/verify'),
                      ),
                      _MenuItem(
                        icon: Icons.brightness_6_rounded,
                        label: 'Theme',
                        subtitle: _themeModeSubtitle(themeMode),
                        color: const Color(0xFF8E24AA),
                        onTap: () => _showThemePicker(context, ref, themeMode),
                      ),
                      _MenuItem(
                        icon: (isArtisan || isBusiness)
                            ? Icons.person_rounded
                            : Icons.construction_rounded,
                        label: (isArtisan || isBusiness)
                            ? 'Switch to Client'
                            : 'Become a Service Provider',
                        subtitle: (isArtisan || isBusiness)
                            ? 'Browse and book services'
                            : 'Start offering your services',
                        color: const Color(0xFFF4511E),
                        onTap: () => _showSwitchDialog(context, ref, user),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Support section
                  _SectionLabel(label: 'Support', theme: theme),
                  const SizedBox(height: 12),
                  _MenuCard(
                    colorScheme: colorScheme,
                    items: [
                      _MenuItem(
                        icon: Icons.help_rounded,
                        label: 'Help & Support',
                        subtitle: 'Get help when you need it',
                        color: const Color(0xFF00ACC1),
                        onTap: () => _openSupport(context),
                      ),
                      _MenuItem(
                        icon: Icons.info_rounded,
                        label: 'About MSpace',
                        subtitle: 'Version 1.0.0',
                        color: const Color(0xFF607D8B),
                        onTap: () => _showAboutDialog(context, theme),
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),

                  // Sign out
                  _SignOutButton(
                    colorScheme: colorScheme,
                    onTap: () => _showLogoutDialog(context, ref),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── helpers ──────────────────────────────────────────────────────────────────

  void _showSwitchDialog(
      BuildContext context, WidgetRef ref, dynamic user) async {
    final isProvider = user.userType == 'artisan' || user.userType == 'business';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(isProvider ? 'Switch to Client?' : 'Become a Service Provider?'),
        content: Text(isProvider
            ? "You'll browse and book services. You can switch back anytime."
            : "You'll be able to offer services as an artisan or business. You can switch back anytime."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(isProvider ? 'Switch' : 'Continue')),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          const Center(child: CircularProgressIndicator()),
    );
    try {
      await ref.read(authProvider.notifier).switchUserType(
            isProvider ? 'customer' : 'artisan',
            user.id,
          );
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isProvider
              ? 'Switched to Client!'
              : "You're now a Service Provider!"),
          backgroundColor: Colors.green,
        ));
        await Future.delayed(const Duration(milliseconds: 300));
        if (context.mounted) context.go('/home');
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  void _showAboutDialog(BuildContext context, ThemeData theme) {
    showAboutDialog(
      context: context,
      applicationName: 'MSpace',
      applicationVersion: '1.0.0',
      applicationIcon:
          Icon(Icons.construction, size: 48, color: theme.colorScheme.primary),
      children: [
        const Text(
            'Your trusted marketplace for hiring skilled artisans and service businesses in Nigeria.'),
      ],
    );
  }

  String _themeModeSubtitle(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      default:
        return 'System default';
    }
  }

  void _showThemePicker(
      BuildContext context, WidgetRef ref, ThemeMode current) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text('Choose Theme',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
            ...{
              ThemeMode.system: (
                'System default',
                'Follow device setting',
                Icons.settings_suggest_rounded
              ),
              ThemeMode.light: (
                'Light',
                'Always light theme',
                Icons.light_mode_rounded
              ),
              ThemeMode.dark: (
                'Dark',
                'Always dark theme',
                Icons.dark_mode_rounded
              ),
            }.entries.map((e) => RadioListTile<ThemeMode>(
                  value: e.key,
                  groupValue: current,
                  onChanged: (v) {
                    if (v != null) {
                      ref
                          .read(themeModeProvider.notifier)
                          .setThemeMode(v);
                      Navigator.pop(ctx);
                    }
                  },
                  title: Text(e.value.$1),
                  subtitle: Text(e.value.$2),
                  secondary: Icon(e.value.$3),
                )),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    await ref.read(authProvider.notifier).logout();
    await Future.delayed(const Duration(milliseconds: 1500));
    if (context.mounted) {
      Navigator.of(context).pop();
      context.go('/home');
    }
  }

  Future<void> _openSupport(BuildContext context) async {
    final uri = Uri.parse(_supportUrl);
    final mailUri = Uri(
        scheme: 'mailto',
        path: _supportEmail,
        query: 'subject=MSpace Support Request');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!await launchUrl(mailUri) && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open support link.')));
      }
    }
  }

  Future<void> _openPublicProfile(BuildContext context, String userId) async {
    final uri = Uri.parse('https://naco-d2738.web.app/p/$userId');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open public profile.')),
      );
    }
  }
}

// ── User header sliver ────────────────────────────────────────────────────────

class _UserHeader extends StatelessWidget {
  const _UserHeader({
    required this.user,
    required this.isArtisan,
    required this.isBusiness,
    required this.roleLabel,
    required this.fadeAnim,
    required this.colorScheme,
    required this.onSettings,
    required this.onShare,
  });

  final dynamic user;
  final bool isArtisan;
  final bool isBusiness;
  final String roleLabel;
  final Animation<double> fadeAnim;
  final ColorScheme colorScheme;
  final VoidCallback onSettings;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      stretch: true,
      backgroundColor: colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 1,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_rounded,
            color: isDark ? Colors.white : Colors.white),
        onPressed: () => Navigator.of(context).pop(),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.settings_rounded, color: Colors.white),
          onPressed: onSettings,
          tooltip: 'Settings',
        ),
        if (isArtisan)
          IconButton(
            icon: const Icon(Icons.share_rounded, color: Colors.white),
            onPressed: onShare,
            tooltip: 'Share Profile',
          ),
        const SizedBox(width: 4),
      ],
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        background: _HeaderBackground(
          user: user,
          isArtisan: isArtisan,
          isBusiness: isBusiness,
          roleLabel: roleLabel,
          colorScheme: colorScheme,
          fadeAnim: fadeAnim,
        ),
      ),
    );
  }
}

class _HeaderBackground extends StatelessWidget {
  const _HeaderBackground({
    required this.user,
    required this.isArtisan,
    required this.isBusiness,
    required this.roleLabel,
    required this.colorScheme,
    required this.fadeAnim,
  });

  final dynamic user;
  final bool isArtisan;
  final bool isBusiness;
  final String roleLabel;
  final ColorScheme colorScheme;
  final Animation<double> fadeAnim;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Gradient background
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isBusiness
                  ? [
                      const Color(0xFF2E7D32),
                      const Color(0xFF1B5E20),
                    ]
                  : isArtisan
                      ? [
                          const Color(0xFF1565C0),
                          const Color(0xFF0D47A1),
                        ]
                      : [
                          colorScheme.primary,
                          Color.lerp(colorScheme.primary, colorScheme.tertiary, 0.6)!,
                        ],
            ),
          ),
        ),

        // Subtle dot pattern
        Positioned.fill(
          child: CustomPaint(painter: _DotPatternPainter()),
        ),

        // Content
        SafeArea(
          child: FadeTransition(
            opacity: fadeAnim,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Avatar
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border:
                              Border.all(color: Colors.white.withOpacity(0.9), width: 2.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 36,
                          backgroundColor: Colors.white.withOpacity(0.2),
                          backgroundImage: user.photoUrl != null
                              ? NetworkImage(user.photoUrl!)
                              : null,
                          child: user.photoUrl == null
                              ? Icon(Icons.person_rounded,
                                  size: 40,
                                  color: Colors.white.withOpacity(0.9))
                              : null,
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Name + type
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              user.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                                shadows: [
                                  Shadow(color: Colors.black26, blurRadius: 8)
                                ],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.18),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isBusiness
                                        ? Icons.store_mall_directory_rounded
                                        : (isArtisan
                                            ? Icons.construction_rounded
                                            : Icons.person_rounded),
                                    size: 12,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    roleLabel,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Stats row ─────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.bookingCount,
    required this.savedCount,
    required this.isArtisan,
    required this.reviewCount,
    required this.avgRating,
    required this.colorScheme,
    required this.theme,
  });

  final int bookingCount;
  final int savedCount;
  final bool isArtisan;
  final int reviewCount;
  final double? avgRating;
  final ColorScheme colorScheme;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = isDark
        ? Color.alphaBlend(Colors.white.withOpacity(0.05), colorScheme.surface)
        : colorScheme.surface;

    return Row(
      children: [
        _StatTile(
          icon: Icons.calendar_month_rounded,
          value: '$bookingCount',
          label: 'Bookings',
          color: const Color(0xFF5C6BC0),
          cardColor: cardColor,
          theme: theme,
        ),
        const SizedBox(width: 10),
        _StatTile(
          icon: Icons.favorite_rounded,
          value: '$savedCount',
          label: 'Saved',
          color: const Color(0xFFE53935),
          cardColor: cardColor,
          theme: theme,
        ),
        const SizedBox(width: 10),
        _StatTile(
          icon: Icons.star_rounded,
          value: isArtisan
              ? (avgRating != null ? avgRating!.toStringAsFixed(1) : '—')
              : '$reviewCount',
          label: isArtisan ? 'Rating' : 'Reviews',
          color: const Color(0xFFFFA000),
          cardColor: cardColor,
          theme: theme,
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    required this.cardColor,
    required this.theme,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;
  final Color cardColor;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: color,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Menu card ─────────────────────────────────────────────────────────────────

class _MenuItem {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final String? badge;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    this.badge,
    required this.onTap,
  });
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({required this.items, required this.colorScheme});
  final List<_MenuItem> items;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark
        ? Color.alphaBlend(Colors.white.withOpacity(0.05), colorScheme.surface)
        : colorScheme.surface;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Column(
          children: items.asMap().entries.map((e) {
            final isLast = e.key == items.length - 1;
            return Column(
              children: [
                _MenuRow(item: e.value, colorScheme: colorScheme),
                if (!isLast)
                  Divider(
                    height: 1,
                    thickness: 0.5,
                    indent: 64,
                    endIndent: 0,
                    color: colorScheme.outlineVariant.withOpacity(0.5),
                  ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.item, required this.colorScheme});
  final _MenuItem item;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: item.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 13),
          child: Row(
            children: [
              // Icon badge
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: item.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(item.icon, color: item.color, size: 20),
              ),
              const SizedBox(width: 14),

              // Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.label,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      item.subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),

              // Badge or chevron
              if (item.badge != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: item.color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    item.badge!,
                    style: TextStyle(
                      color: item.color,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              else
                Icon(Icons.chevron_right_rounded,
                    size: 20,
                    color: colorScheme.onSurfaceVariant.withOpacity(0.5)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, required this.theme});
  final String label;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: theme.textTheme.labelSmall?.copyWith(
        fontWeight: FontWeight.w700,
        color: theme.colorScheme.onSurfaceVariant,
        letterSpacing: 1.1,
        fontSize: 10,
      ),
    );
  }
}

class _SignOutButton extends StatelessWidget {
  const _SignOutButton({required this.colorScheme, required this.onTap});
  final ColorScheme colorScheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(Icons.logout_rounded, color: colorScheme.error, size: 18),
        label: Text('Sign Out',
            style: TextStyle(
                color: colorScheme.error,
                fontWeight: FontWeight.w600,
                fontSize: 14)),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: colorScheme.error.withOpacity(0.4)),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}

// ── Not logged in ─────────────────────────────────────────────────────────────

class _NotLoggedIn extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: colorScheme.primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child:
                  Icon(Icons.person_off_rounded, size: 56, color: colorScheme.primary),
            ),
            const SizedBox(height: 24),
            Text('Not Signed In',
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Text(
              'Sign in to access your profile and manage your bookings',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: colorScheme.onSurfaceVariant, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () => context.go('/login'),
              icon: const Icon(Icons.login_rounded, size: 18),
              label: const Text('Sign In',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Dot pattern painter ───────────────────────────────────────────────────────

class _DotPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.07)
      ..style = PaintingStyle.fill;
    const spacing = 22.0;
    for (double y = 0; y < size.height; y += spacing) {
      for (double x = 0; x < size.width; x += spacing) {
        canvas.drawCircle(Offset(x, y), 1.5, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

// ── Admin profile screen ──────────────────────────────────────────────────────

class _AdminProfileScreen extends ConsumerWidget {
  const _AdminProfileScreen({
    required this.user,
    required this.themeMode,
    required this.onLogout,
    required this.onThemePicker,
    required this.onSupport,
    required this.onSwitchType,
    required this.onAbout,
  });

  final dynamic user;
  final ThemeMode themeMode;
  final VoidCallback onLogout;
  final VoidCallback onThemePicker;
  final VoidCallback onSupport;
  final VoidCallback onSwitchType;
  final VoidCallback onAbout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final pendingVerifications = ref
        .watch(adminIdentityQueueProvider)
        .maybeWhen(data: (i) => i.length, orElse: () => 0);
    final openDisputes = ref
        .watch(adminDisputesProvider)
        .maybeWhen(data: (i) => i.length, orElse: () => 0);
    final pendingReports = ref
        .watch(adminReportsProvider)
        .maybeWhen(data: (i) => i.length, orElse: () => 0);
    final analytics = ref.watch(platformAnalyticsProvider);
    final totalUsers =
        analytics.maybeWhen(data: (s) => s.totalUsers, orElse: () => 0);
    final totalArtisans =
        analytics.maybeWhen(data: (s) => s.totalArtisans, orElse: () => 0);

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Admin header
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            stretch: true,
            backgroundColor: const Color(0xFF1A237E),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings_rounded, color: Colors.white),
                onPressed: () => context.push('/profile/settings'),
              ),
              const SizedBox(width: 4),
            ],
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF1A237E),
                          Color(0xFF283593),
                          Color(0xFF1565C0),
                        ],
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: CustomPaint(
                        painter: _AdminHexPainter()),
                  ),
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 56, 24, 28),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                      color: Colors.white.withOpacity(0.3),
                                      width: 1.5),
                                ),
                                child: const Icon(Icons.shield_rounded,
                                    size: 36, color: Colors.white),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.withOpacity(0.2),
                                        borderRadius:
                                            BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        'ADMINISTRATOR',
                                        style: TextStyle(
                                          color: Colors.amber,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 1.5,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      user.name,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.3,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Admin stats
                  Row(children: [
                    _AdminStatCard(
                      icon: Icons.verified_user_rounded,
                      label: 'Verifications',
                      value: '$pendingVerifications',
                      gradient: const [Color(0xFF3949AB), Color(0xFF5C6BC0)],
                      glow: const Color(0xFF3949AB),
                    ),
                    const SizedBox(width: 10),
                    _AdminStatCard(
                      icon: Icons.gavel_rounded,
                      label: 'Disputes',
                      value: '$openDisputes',
                      gradient: const [Color(0xFFE65100), Color(0xFFFF7043)],
                      glow: const Color(0xFFE65100),
                    ),
                    const SizedBox(width: 10),
                    _AdminStatCard(
                      icon: Icons.flag_rounded,
                      label: 'Reports',
                      value: '$pendingReports',
                      gradient: const [Color(0xFFC62828), Color(0xFFEF5350)],
                      glow: const Color(0xFFC62828),
                    ),
                  ]),

                  const SizedBox(height: 28),
                  _SectionLabel(label: 'Admin Controls', theme: theme),
                  const SizedBox(height: 12),

                  _MenuCard(
                    colorScheme: colorScheme,
                    items: [
                      _MenuItem(
                        icon: Icons.verified_user_rounded,
                        label: 'Identity Verifications',
                        subtitle: 'Review pending ID submissions',
                        color: const Color(0xFF3949AB),
                        badge: pendingVerifications > 0
                            ? '$pendingVerifications'
                            : null,
                        onTap: () => context.push('/admin/identity'),
                      ),
                      _MenuItem(
                        icon: Icons.gavel_rounded,
                        label: 'Dispute Resolution',
                        subtitle: 'Resolve booking disputes',
                        color: const Color(0xFFE65100),
                        badge: openDisputes > 0 ? '$openDisputes' : null,
                        onTap: () => context.push('/admin/disputes'),
                      ),
                      _MenuItem(
                        icon: Icons.flag_rounded,
                        label: 'Content Moderation',
                        subtitle: 'Review reported content',
                        color: const Color(0xFFC62828),
                        badge: pendingReports > 0 ? '$pendingReports' : null,
                        onTap: () => context.push('/admin/reports'),
                      ),
                      _MenuItem(
                        icon: Icons.people_rounded,
                        label: 'User Management',
                        subtitle: 'View and moderate users',
                        color: const Color(0xFF1565C0),
                        badge: totalUsers > 0 ? '$totalUsers' : null,
                        onTap: () => context.push('/admin/users'),
                      ),
                      _MenuItem(
                        icon: Icons.analytics_rounded,
                        label: 'Platform Analytics',
                        subtitle:
                            'Users: $totalUsers · Artisans: $totalArtisans',
                        color: const Color(0xFF00695C),
                        onTap: () => context.push('/admin/analytics'),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),
                  _SectionLabel(label: 'System', theme: theme),
                  const SizedBox(height: 12),

                  _MenuCard(
                    colorScheme: colorScheme,
                    items: [
                      _MenuItem(
                        icon: Icons.person_rounded,
                        label: 'Edit Profile',
                        subtitle: 'Update admin information',
                        color: const Color(0xFF1E88E5),
                        onTap: () => context.push('/profile/edit'),
                      ),
                      _MenuItem(
                        icon: Icons.brightness_6_rounded,
                        label: 'Theme',
                        subtitle: _themeModeSubtitle(themeMode),
                        color: const Color(0xFF8E24AA),
                        onTap: onThemePicker,
                      ),
                      _MenuItem(
                        icon: Icons.help_rounded,
                        label: 'Help & Support',
                        subtitle: 'Get assistance',
                        color: const Color(0xFF00ACC1),
                        onTap: onSupport,
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),
                  _SignOutButton(
                      colorScheme: colorScheme, onTap: onLogout),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _themeModeSubtitle(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      default:
        return 'System default';
    }
  }
}

class _AdminStatCard extends StatelessWidget {
  const _AdminStatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.gradient,
    required this.glow,
  });

  final IconData icon;
  final String label;
  final String value;
  final List<Color> gradient;
  final Color glow;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradient),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: glow.withOpacity(0.3),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(height: 8),
            Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 9,
                    fontWeight: FontWeight.w500),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// ── Admin hex painter ─────────────────────────────────────────────────────────

class _AdminHexPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.04)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    const r = 28.0;
    const w = r * 2;
    const h = r * 1.732;

    for (double row = 0; row * h < size.height + h; row++) {
      for (double col = 0; col * w * 0.75 < size.width + w; col++) {
        final cx = col * w * 0.75;
        final cy = row * h + (col.toInt().isOdd ? h / 2 : 0);
        final path = Path();
        for (int i = 0; i < 6; i++) {
          final angle = (60 * i - 30) * pi / 180;
          final x = cx + r * cos(angle);
          final y = cy + r * sin(angle);
          i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
        }
        path.close();
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}




