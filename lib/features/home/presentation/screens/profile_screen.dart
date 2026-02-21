// lib/features/home/presentation/screens/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../booking/presentation/providers/booking_provider.dart';
import '../../../profile/presentation/providers/profile_provider.dart'; 
import '../../../reviews/presentation/providers/review_provider.dart';   
import '../../../../core/ads/ad_widgets.dart';
import '../../../../core/providers/theme_provider.dart';
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  void _loadData() {
    final user = ref.read(authProvider).user;
    if (user != null) {
      // Load bookings
      ref.read(bookingProvider.notifier).loadUserBookings(
        userId: user.id,
        userType: user.userType,
      );
      // ✅ Load saved artisans
      ref.read(savedArtisansProvider.notifier).loadSavedArtisans(user.id);
      
      // ✅ Load reviews
      if (user.userType == 'artisan') {
        // Load reviews received as artisan
        ref.read(reviewProvider.notifier).loadArtisanReviews(user.id);
      } else {
        // Load reviews given as customer
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
    
    if (user == null) {
      return Scaffold(
        body: _buildNotLoggedIn(context, theme),
      );
    }

    // ✅ Declare isArtisan FIRST
    final isArtisan = user.userType == 'artisan';
    
    // ✅ Watch providers AFTER user null check
    final bookingState = ref.watch(bookingProvider);
    final bookingCount = bookingState.bookings.length;
    
    final savedState = ref.watch(savedArtisansProvider);
    final savedCount = savedState.artisans.length;
    
    final reviewState = ref.watch(reviewProvider);
    final reviewCount = reviewState.reviews.length;
    
    // ✅ Calculate average rating for artisans
    double? averageRating;
    if (isArtisan && reviewCount > 0) {
      final totalRating = reviewState.reviews.fold<double>(
        0.0, 
        (sum, review) => sum + review.rating
      );
      averageRating = totalRating / reviewCount;
    }

    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerLowest,
      body: CustomScrollView(
        slivers: [
          // Compact App Bar
          _buildCompactAppBar(context, user, isArtisan, colorScheme),
          
          // Content
          SliverToBoxAdapter(
            child: Column(
              children: [
                const SizedBox(height: 24),
                
                // Stats Cards
                _buildStatsCards(
                  context, 
                  bookingCount, 
                  savedCount, 
                  isArtisan,
                  reviewCount,
                  averageRating,
                ),
                
                const SizedBox(height: 20),
                
                // Main Actions Section
                _buildMainActions(context, user, isArtisan, bookingCount),
                
                const SizedBox(height: 20),
                
                // Account Section
                _buildAccountSection(context, user, isArtisan, themeMode),

                if (user.userType == 'admin') ...[
                  const SizedBox(height: 20),
                  _buildAdminSection(context),
                ],
                
                const SizedBox(height: 32),

                const Center(child: BannerAdWidget()),
                
                const SizedBox(height: 24),
                
                // Logout Button
                _buildLogoutButton(context, colorScheme),
                
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotLoggedIn(BuildContext context, ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.person_off,
                size: 80,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Not Signed In',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Sign in to access your profile and manage your bookings',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () => context.go('/login'),
              icon: const Icon(Icons.login),
              label: const Text('Sign In'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactAppBar(BuildContext context, dynamic user, bool isArtisan, ColorScheme colorScheme) {
    return SliverAppBar(
      expandedHeight: 140, // ✅ INCREASED from 120 to 140
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colorScheme.primary,
                colorScheme.secondary,
              ],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 60, 20, 20), // ✅ FIXED: Changed bottom padding from 16 to 20
              child: Row(
                children: [
                  // Profile Picture
                  Hero(
                    tag: 'profile-photo',
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 40, // ✅ INCREASED: Changed from 32 to 40 (profile picture size)
                        backgroundColor: Colors.white,
                        backgroundImage: user.photoUrl != null
                            ? NetworkImage(user.photoUrl!)
                            : null,
                        child: user.photoUrl == null
                            ? Icon(Icons.person, size: 44, color: colorScheme.primary) // ✅ INCREASED: Changed from 36 to 44
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // User Info
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withOpacity(0.3)),
                          ),
                          child: Text(
                            isArtisan ? '🛠️ Artisan' : '👤 Customer',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => context.pop(),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.settings_outlined),
          onPressed: () => context.push('/profile/settings'),
          tooltip: 'Settings',
        ),
        if (isArtisan)
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              final link = 'https://naco.app/artisan/${user.id}';
              Clipboard.setData(ClipboardData(text: link));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Profile link copied!')),
              );
            },
            tooltip: 'Share Profile',
          ),
      ],
    );
  }

  Widget _buildStatsCards(
    BuildContext context, 
    int bookingCount, 
    int savedCount, 
    bool isArtisan,
    int reviewCount,
    double? averageRating,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              context: context,
              icon: Icons.event_note,
              label: 'Bookings',
              value: bookingCount.toString(),
              color: Colors.purple,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              context: context,
              icon: Icons.favorite,
              label: 'Saved',
              value: savedCount.toString(),
              color: Colors.red,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              context: context,
              icon: Icons.star,
              label: isArtisan ? 'Rating' : 'Reviews',
              value: isArtisan 
                  ? (averageRating != null ? averageRating.toStringAsFixed(1) : '0.0')
                  : reviewCount.toString(),
              color: Colors.amber,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainActions(BuildContext context, dynamic user, bool isArtisan, int bookingCount) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildActionTile(
            context: context,
            icon: Icons.event_note,
            title: 'My Bookings',
            subtitle: 'View and manage your bookings',
            iconColor: Colors.purple,
            badge: bookingCount > 0 ? bookingCount.toString() : null,
            onTap: () => context.push('/bookings'),
          ),
          const Divider(height: 1, indent: 72),
          _buildActionTile(
            context: context,
            icon: Icons.favorite,
            title: 'Saved Artisans',
            subtitle: 'Your favorite professionals',
            iconColor: Colors.red,
            onTap: () => context.push('/profile/saved'),
          ),
          const Divider(height: 1, indent: 72),
          _buildActionTile(
            context: context,
            icon: Icons.star,
            title: 'Reviews & Ratings',
            subtitle: isArtisan ? 'Reviews you received' : 'Your reviews',
            iconColor: Colors.amber,
            onTap: () => context.push('/reviews'), // ✅ Navigate to reviews screen
          ),
        ],
      ),
    );
  }

  Widget _buildAccountSection(
    BuildContext context,
    dynamic user,
    bool isArtisan,
    ThemeMode themeMode,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildActionTile(
            context: context,
            icon: Icons.person_outline,
            title: 'Edit Profile',
            subtitle: 'Update your personal information',
            iconColor: Colors.blue,
            onTap: () => context.push('/profile/edit'),
          ),
          const Divider(height: 1, indent: 72),
          _buildActionTile(
            context: context,
            icon: Icons.verified_user_outlined,
            title: 'Identity Verification',
            subtitle: 'Submit ID for verification',
            iconColor: Colors.green,
            onTap: () => context.push('/profile/verify'),
          ),
          const Divider(height: 1, indent: 72),
          _buildActionTile(
            context: context,
            icon: Icons.dark_mode_outlined,
            title: 'Theme',
            subtitle: _themeModeSubtitle(themeMode),
            iconColor: Colors.purple,
            onTap: () => _showThemePicker(context, ref, themeMode),
          ),
          const Divider(height: 1, indent: 72),
          _buildActionTile(
            context: context,
            icon: isArtisan ? Icons.person : Icons.construction,
            title: isArtisan ? 'Switch to Customer' : 'Become an Artisan',
            subtitle: isArtisan 
                ? 'Browse and book services' 
                : 'Start offering your services',
            iconColor: Colors.orange,
            onTap: () => _showSwitchDialog(context, ref, user),
          ),
          const Divider(height: 1, indent: 72),
          _buildActionTile(
            context: context,
            icon: Icons.help_outline,
            title: 'Help & Support',
            subtitle: 'Get help when you need it',
            iconColor: Colors.cyan,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Help center coming soon!')),
              );
            },
          ),
          const Divider(height: 1, indent: 72),
          _buildActionTile(
            context: context,
            icon: Icons.info_outline,
            title: 'About Naco',
            subtitle: 'Version 1.0.0',
            iconColor: Colors.blueGrey,
            onTap: () => _showAboutDialog(context, theme),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color iconColor,
    String? badge,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: iconColor, size: 24),
      ),
      title: Text(
        title,
        style: theme.textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (badge != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                badge,
                style: TextStyle(
                  color: colorScheme.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
        ],
      ),
    );
  }

  Widget _buildAdminSection(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildActionTile(
            context: context,
            icon: Icons.verified,
            title: 'Admin: Identity',
            subtitle: 'Review pending verifications',
            iconColor: Colors.indigo,
            onTap: () => context.push('/admin/identity'),
          ),
          const Divider(height: 1, indent: 72),
          _buildActionTile(
            context: context,
            icon: Icons.report,
            title: 'Admin: Disputes',
            subtitle: 'Resolve open disputes',
            iconColor: Colors.orange,
            onTap: () => context.push('/admin/disputes'),
          ),
          const Divider(height: 1, indent: 72),
          _buildActionTile(
            context: context,
            icon: Icons.flag,
            title: 'Admin: Reports',
            subtitle: 'Moderation queue',
            iconColor: Colors.red,
            onTap: () => context.push('/admin/reports'),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: OutlinedButton.icon(
        onPressed: () => _showLogoutDialog(context, ref),
        icon: Icon(Icons.logout, color: colorScheme.error),
        label: Text('Sign Out', style: TextStyle(color: colorScheme.error)),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: colorScheme.error.withOpacity(0.5)),
          padding: const EdgeInsets.symmetric(vertical: 16),
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  void _showSwitchDialog(BuildContext context, WidgetRef ref, dynamic user) async {
  final isArtisan = user.userType == 'artisan';
  
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(isArtisan ? 'Switch to Customer?' : 'Become an Artisan?'),
      content: Text(
        isArtisan
            ? 'You\'ll browse and book services. You can switch back anytime.'
            : 'You\'ll be able to offer your services. You can switch back anytime.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(isArtisan ? 'Switch' : 'Continue'),
        ),
      ],
    ),
  );

  if (confirmed == true && context.mounted) {
    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Switch user type
      await ref.read(authProvider.notifier).switchUserType(
        isArtisan ? 'customer' : 'artisan',
        user.id,
      );
      
      if (context.mounted) {
        // Close loading dialog
        Navigator.pop(context);
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isArtisan ? '✅ Switched to Customer!' : '✅ You\'re now an Artisan!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
        
        // ✅ CRITICAL FIX: Navigate to home so FAB appears/disappears
        await Future.delayed(const Duration(milliseconds: 300));
        if (context.mounted) {
          context.go('/home');
        }
      }
    } catch (e) {
      if (context.mounted) {
        // Close loading dialog if it's open
        Navigator.of(context, rootNavigator: true).pop();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}

  void _showAboutDialog(BuildContext context, ThemeData theme) {
    showAboutDialog(
      context: context,
      applicationName: 'Naco',
      applicationVersion: '1.0.0',
      applicationIcon: Icon(Icons.construction, size: 48, color: theme.colorScheme.primary),
      children: [
        const Text('Your trusted marketplace for finding skilled artisans in Nigeria.'),
      ],
    );
  }

  String _themeModeSubtitle(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
      default:
        return 'System default';
    }
  }

  void _showThemePicker(
    BuildContext context,
    WidgetRef ref,
    ThemeMode currentMode,
  ) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(
                title: Text('Theme'),
                subtitle: Text('Follow device settings or choose a theme'),
              ),
              _buildThemeOption(
                context: context,
                ref: ref,
                mode: ThemeMode.system,
                currentMode: currentMode,
                title: 'System default',
                subtitle: 'Match your device theme',
                icon: Icons.settings_suggest_outlined,
              ),
              _buildThemeOption(
                context: context,
                ref: ref,
                mode: ThemeMode.light,
                currentMode: currentMode,
                title: 'Light',
                subtitle: 'Light theme',
                icon: Icons.light_mode_outlined,
              ),
              _buildThemeOption(
                context: context,
                ref: ref,
                mode: ThemeMode.dark,
                currentMode: currentMode,
                title: 'Dark',
                subtitle: 'Dark theme',
                icon: Icons.dark_mode_outlined,
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Widget _buildThemeOption({
    required BuildContext context,
    required WidgetRef ref,
    required ThemeMode mode,
    required ThemeMode currentMode,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return RadioListTile<ThemeMode>(
      value: mode,
      groupValue: currentMode,
      onChanged: (value) {
        if (value == null) return;
        ref.read(themeModeProvider.notifier).setThemeMode(value);
        Navigator.pop(context);
      },
      title: Text(title),
      subtitle: Text(subtitle),
      secondary: Icon(icon),
    );
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
  // show loading dialog
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 12),
          Text('Logging out...'),
        ],
      ),
    ),
  );

  await ref.read(authProvider.notifier).logout();

  await Future.delayed(const Duration(milliseconds: 3000));

  if (context.mounted) {
    Navigator.of(context).pop(); // close dialog
    context.go('/home');
  }
}

  }
}
