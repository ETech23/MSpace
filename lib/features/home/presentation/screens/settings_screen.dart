// lib/features/home/presentation/screens/settings_screen.dart
import 'dart:convert';

import 'package:artisan_marketplace/core/services/location_service.dart';
import 'package:artisan_marketplace/core/services/update_user_location.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:artisan_marketplace/core/providers/theme_provider.dart';
import 'package:artisan_marketplace/core/ads/ad_widgets.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const String _privacyPolicyUrl = String.fromEnvironment(
    'PRIVACY_POLICY_URL',
    defaultValue: 'https://etech23.github.io/MSpace/privacy-policy.html',
  );
  static const String _termsUrl = String.fromEnvironment(
    'TERMS_OF_SERVICE_URL',
    defaultValue: 'https://etech23.github.io/MSpace/terms-of-service.html',
  );
  static const String _communityGuidelinesUrl = String.fromEnvironment(
    'COMMUNITY_GUIDELINES_URL',
    defaultValue: 'https://etech23.github.io/MSpace/community-guidelines.html',
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          // ── Sliver app bar ────────────────────────────────────────────────
          SliverAppBar(
            pinned: true,
            backgroundColor: colorScheme.surface,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            titleSpacing: 20,
            leading: Padding(
              padding: const EdgeInsets.only(left: 12),
              child: _BackButton(colorScheme: colorScheme, isDark: isDark),
            ),
            title: Text(
              'Settings',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.7,
                color: colorScheme.onSurface,
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Ad
                  Center(child: BannerAdWidget()),
                  const SizedBox(height: 24),

                  // Preferences
                  _SectionLabel(label: 'Preferences'),
                  const SizedBox(height: 10),
                  _SettingsCard(
                    colorScheme: colorScheme,
                    isDark: isDark,
                    items: [
                      _SettingsItem(
                        icon: Icons.notifications_rounded,
                        label: 'Notifications',
                        subtitle: 'Manage push, email, booking, and message alerts',
                        color: const Color(0xFF1565C0),
                        onTap: () => context.push('/profile/notifications'),
                      ),
                      _SettingsItem(
                        icon: Icons.brightness_6_rounded,
                        label: 'Theme',
                        subtitle: _themeModeSubtitle(themeMode),
                        color: const Color(0xFF6A1B9A),
                        onTap: () => _showThemePicker(context, ref, themeMode),
                      ),
                      _SettingsItem(
                        icon: Icons.language_rounded,
                        label: 'Language',
                        subtitle: 'English',
                        color: const Color(0xFF00695C),
                        onTap: () => _showLanguagePicker(context),
                      ),
                      _SettingsItem(
                        icon: Icons.my_location_rounded,
                        label: 'Location Source',
                        subtitle: 'Use saved location or refresh now',
                        color: const Color(0xFFEF6C00),
                        onTap: () => _showLocationSourceSheet(context, ref),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Growth
                  _SectionLabel(label: 'Growth'),
                  const SizedBox(height: 10),
                  _SettingsCard(
                    colorScheme: colorScheme,
                    isDark: isDark,
                    items: [
                      _SettingsItem(
                        icon: Icons.card_giftcard_rounded,
                        label: 'Invite Friends',
                        subtitle: 'Share your referral link',
                        color: const Color(0xFF00897B),
                        onTap: () => context.push('/referrals'),
                      ),
                      _SettingsItem(
                        icon: Icons.leaderboard_rounded,
                        label: 'Referral Leaderboard',
                        subtitle: 'See top referrers',
                        color: const Color(0xFF5E35B1),
                        onTap: () => context.push('/referrals/leaderboard'),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Privacy & Security
                  _SectionLabel(label: 'Privacy & Security'),
                  const SizedBox(height: 10),
                  _SettingsCard(
                    colorScheme: colorScheme,
                    isDark: isDark,
                    items: [
                      _SettingsItem(
                        icon: Icons.lock_rounded,
                        label: 'Change Password',
                        subtitle: 'Update your account password',
                        color: const Color(0xFFC62828),
                        onTap: () => context.push('/profile/privacy'),
                      ),
                      _SettingsItem(
                        icon: Icons.privacy_tip_rounded,
                        label: 'Privacy Settings',
                        subtitle: 'Control who can see your info',
                        color: const Color(0xFF2E7D32),
                        onTap: () => context.push('/profile/privacy'),
                      ),
                      _SettingsItem(
                        icon: Icons.block_rounded,
                        label: 'Blocked Users',
                        subtitle: 'Manage blocked accounts',
                        color: const Color(0xFFE65100),
                        onTap: () => context.push('/profile/blocked'),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Data & Storage
                  _SectionLabel(label: 'Data & Storage'),
                  const SizedBox(height: 10),
                  _SettingsCard(
                    colorScheme: colorScheme,
                    isDark: isDark,
                    items: [
                      _SettingsItem(
                        icon: Icons.download_rounded,
                        label: 'Download My Data',
                        subtitle: 'Export your account data',
                        color: const Color(0xFF1565C0),
                        onTap: () => _exportUserData(context, ref),
                      ),
                      _SettingsItem(
                        icon: Icons.cleaning_services_rounded,
                        label: 'Clear Cache',
                        subtitle: 'Free up storage space',
                        color: const Color(0xFFF57F17),
                        onTap: () => _showClearCacheDialog(context),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Legal
                  _SectionLabel(label: 'Legal'),
                  const SizedBox(height: 10),
                  _SettingsCard(
                    colorScheme: colorScheme,
                    isDark: isDark,
                    items: [
                      _SettingsItem(
                        icon: Icons.description_rounded,
                        label: 'Terms of Service',
                        subtitle: 'Read our terms',
                        color: const Color(0xFF455A64),
                        onTap: () => _openExternalLink(context, _termsUrl),
                      ),
                      _SettingsItem(
                        icon: Icons.shield_rounded,
                        label: 'Privacy Policy',
                        subtitle: 'How we protect your data',
                        color: const Color(0xFF2E7D32),
                        onTap: () => _openExternalLink(context, _privacyPolicyUrl),
                      ),
                      _SettingsItem(
                        icon: Icons.gpp_good_rounded,
                        label: 'Community Guidelines',
                        subtitle: 'Safety and chat rules',
                        color: const Color(0xFF4A148C),
                        onTap: () => _openExternalLink(context, _communityGuidelinesUrl),
                      ),
                      _SettingsItem(
                        icon: Icons.article_rounded,
                        label: 'Licenses',
                        subtitle: 'Open source licenses',
                        color: const Color(0xFF546E7A),
                        onTap: () => showLicensePage(context: context),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Danger zone
                  _SectionLabel(label: 'Account Actions', danger: true),
                  const SizedBox(height: 10),
                  _SettingsCard(
                    colorScheme: colorScheme,
                    isDark: isDark,
                    items: [
                      _SettingsItem(
                        icon: Icons.person_remove_rounded,
                        label: 'Delete Account',
                        subtitle: 'Permanently remove your account',
                        color: colorScheme.error,
                        onTap: () => _showDeleteAccountDialog(context),
                        danger: true,
                      ),
                    ],
                  ),

                  const SizedBox(height: 40),

                  // Footer
                  Center(
                    child: Column(children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withOpacity(0.07),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.construction_rounded,
                            size: 26, color: colorScheme.primary.withOpacity(0.6)),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'MSpace v1.0.2',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Made with ❤️ by Etech23',
                        style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helper dialogs ──────────────────────────────────────────────────────────

  String _themeModeSubtitle(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:  return 'Light';
      case ThemeMode.dark:   return 'Dark';
      default:               return 'System default';
    }
  }

  void _showThemePicker(BuildContext context, WidgetRef ref, ThemeMode current) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const ListTile(title: Text('Choose Theme', style: TextStyle(fontWeight: FontWeight.w700))),
          ...{
            ThemeMode.system: ('System default', 'Follow device setting', Icons.settings_suggest_rounded),
            ThemeMode.light:  ('Light',           'Always light theme',   Icons.light_mode_rounded),
            ThemeMode.dark:   ('Dark',            'Always dark theme',    Icons.dark_mode_rounded),
          }.entries.map((e) => RadioListTile<ThemeMode>(
            value: e.key, groupValue: current,
            onChanged: (v) {
              if (v != null) ref.read(themeModeProvider.notifier).setThemeMode(v);
              Navigator.pop(ctx);
            },
            title: Text(e.value.$1), subtitle: Text(e.value.$2),
            secondary: Icon(e.value.$3),
          )),
          const SizedBox(height: 12),
        ]),
      ),
    );
  }

  void _showLanguagePicker(BuildContext context) {
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
              title: Text('App Language', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
            ListTile(
              leading: const Icon(Icons.language),
              title: const Text('English'),
              subtitle: const Text('Current language'),
              trailing: const Icon(Icons.check),
              onTap: () => Navigator.pop(ctx),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showLocationSourceSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Location Source',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
              const SizedBox(height: 6),
              Text(
                'Choose whether to keep using your saved location or fetch a fresh location now.',
                style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                      color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await _useSavedLocation(context, ref);
                      },
                      child: const Text('Use saved location'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await _updateLocationNow(context, ref);
                      },
                      child: const Text('Update now'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _useSavedLocation(BuildContext context, WidgetRef ref) async {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    final locationService = LocationService();
    await locationService.markLocationPromptHandled();

    final hasSavedProfileLocation =
        user.latitude != null && user.longitude != null;
    if (hasSavedProfileLocation) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Using saved profile location.')),
        );
      }
      return;
    }

    final cached = await locationService.getCachedLocation();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            cached != null
                ? 'Using saved device location.'
                : 'No saved location found. Tap "Update now" to fetch live location.',
          ),
        ),
      );
    }
  }

  Future<void> _updateLocationNow(BuildContext context, WidgetRef ref) async {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    final locationService = LocationService();
    try {
      final serviceEnabled = await locationService.isLocationServiceEnabled();
      if (!serviceEnabled) {
        await _showEnableLocationServicesDialog(context, locationService);
        return;
      }

      var permission = await locationService.checkPermissionStatus();
      var granted = permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;

      if (!granted) {
        if (permission == LocationPermission.deniedForever) {
          await _showEnableAppLocationPermissionDialog(context, locationService);
          return;
        }
        permission = await locationService.requestPermissionOnce();
        granted = permission == LocationPermission.always ||
            permission == LocationPermission.whileInUse;
      }

      if (!granted) {
        await _showEnableAppLocationPermissionDialog(context, locationService);
        return;
      }

      final result = await locationService.getLocation();
      if (result == null || !result.isLive) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not get a fresh location right now.')),
          );
        }
        return;
      }

      await UpdateUserLocationService().updateUserLocation(
        UserLocationPayload(
          userId: user.id,
          locationResult: result,
        isArtisan: user.isArtisan,
        ),
      );
      await ref.read(authProvider.notifier).refreshUser();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.address?.isNotEmpty == true
                  ? 'Location updated: ${result.address}'
                  : 'Location updated successfully.',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update location: $e')),
        );
      }
    }
  }

  Future<void> _showEnableLocationServicesDialog(
    BuildContext context,
    LocationService locationService,
  ) async {
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Turn on location services'),
        content: const Text(
          'Device location is off. Turn it on to fetch your current location.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await locationService.openLocationSettings();
            },
            child: const Text('Open location settings'),
          ),
        ],
      ),
    );
  }

  Future<void> _showEnableAppLocationPermissionDialog(
    BuildContext context,
    LocationService locationService,
  ) async {
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Allow location permission'),
        content: const Text(
          'Location permission is off for this app. Enable it in app settings to update now.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await locationService.openAppSettings();
            },
            child: const Text('Open app settings'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportUserData(BuildContext context, WidgetRef ref) async {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    try {
      final supabase = Supabase.instance.client;
      final profile = await supabase
          .from('users')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      final bookings = await supabase
          .from('bookings')
          .select()
          .or('client_id.eq.${user.id},artisan_id.eq.${user.id}');

      final reviews = await supabase
          .from('reviews')
          .select()
          .or('customer_id.eq.${user.id},artisan_id.eq.${user.id}');

      final exportPayload = {
        'exported_at': DateTime.now().toIso8601String(),
        'user': profile,
        'bookings': bookings,
        'reviews': reviews,
      };

      await Share.share(
        const JsonEncoder.withIndent('  ').convert(exportPayload),
        subject: 'MSpace account data export',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to export data: $e')),
        );
      }
    }
  }

  void _showClearCacheDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Clear Cache'),
        content: const Text('This will delete temporary files. Your account data won\'t be affected.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('Cache cleared!')));
            },
            style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Account'),
        icon: Icon(Icons.warning_amber_rounded, size: 44, color: Theme.of(dCtx).colorScheme.error),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('This will permanently delete your account. Enter a reason to continue.'),
          const SizedBox(height: 12),
          TextField(
            controller: reasonController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Reason',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final reason = reasonController.text.trim();
              if (reason.isEmpty) {
                ScaffoldMessenger.of(dCtx).showSnackBar(
                    const SnackBar(content: Text('Please provide a reason.')));
                return;
              }
              final container = ProviderScope.containerOf(dCtx);
              final ok = await container.read(authProvider.notifier).requestAccountDeletion(reason: reason);
              if (!dCtx.mounted) return;
              Navigator.pop(dCtx);
              ScaffoldMessenger.of(dCtx).showSnackBar(SnackBar(content: Text(
                  ok ? 'Account deletion requested.' : 'Could not process request. Try again.')));
              if (ok && dCtx.mounted) dCtx.go('/login');
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dCtx).colorScheme.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Delete Account'),
          ),
        ],
      ),
    );
  }

  Future<void> _openExternalLink(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not open: $url')));
    }
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _BackButton extends StatelessWidget {
  const _BackButton({required this.colorScheme, required this.isDark});
  final ColorScheme colorScheme;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.pop(),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(Icons.arrow_back_rounded, size: 18, color: colorScheme.onSurface),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, this.danger = false});
  final String label;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.1,
        color: danger ? cs.error.withOpacity(0.8) : cs.onSurfaceVariant,
      ),
    );
  }
}

class _SettingsItem {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  final bool danger;

  const _SettingsItem({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.danger = false,
  });
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.items,
    required this.colorScheme,
    required this.isDark,
  });
  final List<_SettingsItem> items;
  final ColorScheme colorScheme;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark
        ? Color.alphaBlend(Colors.white.withOpacity(0.05), colorScheme.surface)
        : colorScheme.surface;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Column(
          children: items.asMap().entries.map((e) {
            final isLast = e.key == items.length - 1;
            return Column(children: [
              _SettingsRow(item: e.value, colorScheme: colorScheme),
              if (!isLast)
                Divider(
                  height: 1,
                  thickness: 0.5,
                  indent: 62,
                  color: colorScheme.outlineVariant.withOpacity(0.5),
                ),
            ]);
          }).toList(),
        ),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({required this.item, required this.colorScheme});
  final _SettingsItem item;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: item.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 13),
          child: Row(children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: item.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(item.icon, color: item.color, size: 19),
            ),
            const SizedBox(width: 13),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: item.danger ? colorScheme.error : colorScheme.onSurface,
                  )),
              const SizedBox(height: 1),
              Text(item.subtitle,
                  style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant)),
            ])),
            Icon(Icons.chevron_right_rounded,
                size: 18, color: colorScheme.onSurfaceVariant.withOpacity(0.4)),
          ]),
        ),
      ),
    );
  }
}




