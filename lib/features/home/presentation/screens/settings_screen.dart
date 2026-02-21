// lib/features/home/presentation/screens/settings_screen.dart
import 'package:artisan_marketplace/core/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:artisan_marketplace/core/providers/theme_provider.dart';
import 'package:artisan_marketplace/core/ads/ad_widgets.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 20),
        children: [
          // Preferences Section
          _buildSection(
            context: context,
            title: 'Preferences',
            icon: Icons.tune,
            iconColor: Colors.indigo,
            children: [
              _buildSettingTile(
                context: context,
                icon: Icons.notifications_outlined,
                title: 'Notifications',
                subtitle: 'Manage notification preferences',
                iconColor: Colors.blue,
                onTap: () => _showNotificationSettings(context, ref),
              ),
              const Divider(height: 1, indent: 72),
              _buildSettingTile(
                context: context,
                icon: Icons.dark_mode_outlined,
                title: 'Theme',
                subtitle: _themeModeSubtitle(themeMode),
                iconColor: Colors.purple,
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showThemePicker(context, ref, themeMode),
              ),
              const Divider(height: 1, indent: 72),
              _buildSettingTile(
                context: context,
                icon: Icons.language,
                title: 'Language',
                subtitle: 'English',
                iconColor: Colors.teal,
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('More languages coming soon!')),
                  );
                },
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Privacy & Security Section
          _buildSection(
            context: context,
            title: 'Privacy & Security',
            icon: Icons.security,
            iconColor: Colors.green,
            children: [
              _buildSettingTile(
                context: context,
                icon: Icons.lock_outline,
                title: 'Change Password',
                subtitle: 'Update your password',
                iconColor: Colors.red,
                onTap: () => context.push('/profile/privacy'),
              ),
              const Divider(height: 1, indent: 72),
              _buildSettingTile(
                context: context,
                icon: Icons.privacy_tip_outlined,
                title: 'Privacy Settings',
                subtitle: 'Control who can see your info',
                iconColor: Colors.green,
                onTap: () => context.push('/profile/privacy'),
              ),
              const Divider(height: 1, indent: 72),
              _buildSettingTile(
                context: context,
                icon: Icons.block,
                title: 'Blocked Users',
                subtitle: 'Manage blocked accounts',
                iconColor: Colors.orange,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Blocked users coming soon!')),
                  );
                },
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Data & Storage Section
          _buildSection(
            context: context,
            title: 'Data & Storage',
            icon: Icons.storage,
            iconColor: Colors.deepPurple,
            children: [
              _buildSettingTile(
                context: context,
                icon: Icons.download_outlined,
                title: 'Download My Data',
                subtitle: 'Export your account data',
                iconColor: Colors.blue,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Data export coming soon!')),
                  );
                },
              ),
              const Divider(height: 1, indent: 72),
              _buildSettingTile(
                context: context,
                icon: Icons.delete_outline,
                title: 'Clear Cache',
                subtitle: 'Free up storage space',
                iconColor: Colors.amber,
                onTap: () => _showClearCacheDialog(context),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Legal Section
          _buildSection(
            context: context,
            title: 'Legal',
            icon: Icons.policy,
            iconColor: Colors.grey,
            children: [
              _buildSettingTile(
                context: context,
                icon: Icons.description_outlined,
                title: 'Terms of Service',
                subtitle: 'Read our terms',
                iconColor: Colors.blueGrey,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Terms coming soon!')),
                  );
                },
              ),
              const Divider(height: 1, indent: 72),
              _buildSettingTile(
                context: context,
                icon: Icons.shield_outlined,
                title: 'Privacy Policy',
                subtitle: 'How we protect your data',
                iconColor: Colors.green,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Privacy policy coming soon!')),
                  );
                },
              ),
              const Divider(height: 1, indent: 72),
              _buildSettingTile(
                context: context,
                icon: Icons.gavel,
                title: 'Licenses',
                subtitle: 'Open source licenses',
                iconColor: Colors.grey,
                onTap: () {
                  showLicensePage(context: context);
                },
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Danger Zone
          _buildSection(
            context: context,
            title: 'Account Actions',
            icon: Icons.warning_amber,
            iconColor: Colors.red,
            children: [
              _buildSettingTile(
                context: context,
                icon: Icons.person_remove_outlined,
                title: 'Delete Account',
                subtitle: 'Permanently delete your account',
                iconColor: Colors.red,
                onTap: () => _showDeleteAccountDialog(context),
              ),
            ],
          ),
          
          const SizedBox(height: 32),
          
          // App Version
          Center(
            child: Column(
              children: [
                Icon(Icons.construction, size: 48, color: colorScheme.primary.withOpacity(0.5)),
                const SizedBox(height: 8),
                Text(
                  'Naco v1.0.0',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Made with ❤️ in Nigeria',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 32),

          const Center(child: BannerAdWidget()),
          
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSection({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Color iconColor,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
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
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildSettingTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color iconColor,
    Widget? trailing,
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
      trailing: trailing ?? Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
    );
  }

  void _showNotificationSettings(BuildContext context, WidgetRef ref) async {
    final notificationService = NotificationService();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Notification Settings'),
        content: const Text('Enable notifications to get updates about your bookings and messages.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await notificationService.initialize();
              if (success && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Notifications enabled!')),
                );
              } else if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Failed to enable notifications')),
                );
              }
            },
            child: const Text('Enable Notifications'),
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
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.only(bottom: 12),
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
    final theme = Theme.of(context);
    return RadioListTile<ThemeMode>(
      value: mode,
      groupValue: currentMode,
      activeColor: theme.colorScheme.primary,
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

  void _showClearCacheDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Cache'),
        content: const Text('This will delete temporary files and free up storage space. Your account data will not be affected.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Cache cleared successfully!')),
              );
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        icon: Icon(Icons.warning_amber, size: 48, color: Theme.of(context).colorScheme.error),
        content: const Text(
          'This action is permanent and cannot be undone. All your data, bookings, and reviews will be permanently deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Account deletion coming soon. Please contact support.'),
                ),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete Account'),
          ),
        ],
      ),
    );
  }
}
