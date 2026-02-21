// lib/features/profile/presentation/screens/privacy_settings_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/profile_provider.dart';

class PrivacySettingsScreen extends ConsumerStatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  ConsumerState<PrivacySettingsScreen> createState() =>
      _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState
    extends ConsumerState<PrivacySettingsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final user = ref.read(authProvider).user;
      if (user != null) {
        ref.read(settingsProvider.notifier).loadPrivacySettings(user.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final settingsState = ref.watch(settingsProvider);
    final settings = settingsState.privacySettings;

    if (settingsState.isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Privacy & Security'),
          centerTitle: true,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (settings == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Privacy & Security'),
          centerTitle: true,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'Failed to load settings',
                style: theme.textTheme.titleMedium,
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy & Security'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.secondaryContainer.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.security,
                  color: colorScheme.secondary,
                  size: 32,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Control Your Privacy',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Manage who can see your information',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Profile Visibility
          _buildSettingCard(
            context: context,
            title: 'Profile Visible',
            subtitle: 'Make your profile visible to others',
            icon: Icons.visibility,
            value: settings.profileVisible,
            iconColor: colorScheme.primary,
            onChanged: (value) {
              final updated = settings.copyWith(profileVisible: value);
              ref.read(settingsProvider.notifier).updatePrivacySettings(
                    ref.read(authProvider).user!.id,
                    updated,
                  );
            },
          ),

          const SizedBox(height: 16),

          // Section Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Text(
              'INFORMATION VISIBILITY',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          // Show Email
          _buildSettingCard(
            context: context,
            title: 'Show Email',
            subtitle: 'Display your email address on your profile',
            icon: Icons.email_outlined,
            value: settings.showEmail,
            iconColor: Colors.blue,
            onChanged: (value) {
              final updated = settings.copyWith(showEmail: value);
              ref.read(settingsProvider.notifier).updatePrivacySettings(
                    ref.read(authProvider).user!.id,
                    updated,
                  );
            },
          ),

          const SizedBox(height: 12),

          // Show Phone
          _buildSettingCard(
            context: context,
            title: 'Show Phone Number',
            subtitle: 'Display your phone number on your profile',
            icon: Icons.phone_outlined,
            value: settings.showPhone,
            iconColor: Colors.green,
            onChanged: (value) {
              final updated = settings.copyWith(showPhone: value);
              ref.read(settingsProvider.notifier).updatePrivacySettings(
                    ref.read(authProvider).user!.id,
                    updated,
                  );
            },
          ),

          const SizedBox(height: 12),

          // Show Address
          _buildSettingCard(
            context: context,
            title: 'Show Address',
            subtitle: 'Display your address on your profile',
            icon: Icons.location_on_outlined,
            value: settings.showAddress,
            iconColor: Colors.orange,
            onChanged: (value) {
              final updated = settings.copyWith(showAddress: value);
              ref.read(settingsProvider.notifier).updatePrivacySettings(
                    ref.read(authProvider).user!.id,
                    updated,
                  );
            },
          ),

          const SizedBox(height: 24),

          // Security Actions
          _buildActionCard(
            context: context,
            title: 'Change Password',
            subtitle: 'Update your account password',
            icon: Icons.lock_outline,
            iconColor: colorScheme.tertiary,
            onTap: () {
              // TODO: Implement change password
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Password change coming soon!'),
                ),
              );
            },
          ),

          const SizedBox(height: 12),

          _buildActionCard(
            context: context,
            title: 'Two-Factor Authentication',
            subtitle: 'Add an extra layer of security',
            icon: Icons.verified_user_outlined,
            iconColor: Colors.purple,
            onTap: () {
              // TODO: Implement 2FA
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('2FA setup coming soon!'),
                ),
              );
            },
          ),

          const SizedBox(height: 12),

          _buildActionCard(
            context: context,
            title: 'Delete Account',
            subtitle: 'Permanently delete your account',
            icon: Icons.delete_forever,
            iconColor: Colors.red,
            onTap: () => _showDeleteAccountDialog(context),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required Color iconColor,
    required ValueChanged<bool> onChanged,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outlineVariant.withOpacity(0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        secondary: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: iconColor),
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
      ),
    );
  }

  Widget _buildActionCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outlineVariant.withOpacity(0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: iconColor),
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
        trailing: Icon(
          Icons.chevron_right,
          color: colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Account'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'This action cannot be undone. Enter a reason to confirm account deletion.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Reason',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final reason = reasonController.text.trim();
              if (reason.isEmpty) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('Please provide a reason.')),
                );
                return;
              }

              final ok = await ref
                  .read(authProvider.notifier)
                  .requestAccountDeletion(reason: reason);

              if (!dialogContext.mounted) return;
              Navigator.pop(dialogContext);
              ScaffoldMessenger.of(dialogContext).showSnackBar(
                SnackBar(
                  content: Text(
                    ok
                        ? 'Account deletion requested. You have been signed out.'
                        : 'Unable to process deletion request right now.',
                  ),
                ),
              );
              if (ok && dialogContext.mounted) {
                dialogContext.go('/login');
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
