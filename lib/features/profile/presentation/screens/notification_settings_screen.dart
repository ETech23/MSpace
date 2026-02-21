// lib/features/profile/presentation/screens/notification_settings_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/profile_provider.dart';

class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends ConsumerState<NotificationSettingsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final user = ref.read(authProvider).user;
      if (user != null) {
        ref.read(settingsProvider.notifier).loadNotificationSettings(user.id);
      }
    });
  }

  Future<void> _updateSettings() async {
    final user = ref.read(authProvider).user;
    final settings = ref.read(settingsProvider).notificationSettings;

    if (user != null && settings != null) {
      final success = await ref
          .read(settingsProvider.notifier)
          .updateNotificationSettings(user.id, settings);

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final settingsState = ref.watch(settingsProvider);
    final settings = settingsState.notificationSettings;

    if (settingsState.isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Notifications'),
          centerTitle: true,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (settings == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Notifications'),
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
        title: const Text('Notifications'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.notifications_active,
                  color: colorScheme.primary,
                  size: 32,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Notification Preferences',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Manage how you receive notifications',
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

          // Push Notifications
          _buildSettingCard(
            context: context,
            title: 'Push Notifications',
            subtitle: 'Receive push notifications on your device',
            icon: Icons.phone_android,
            value: settings.pushNotifications,
            onChanged: (value) {
              final updated = settings.copyWith(pushNotifications: value);
              ref.read(settingsProvider.notifier).updateNotificationSettings(
                    ref.read(authProvider).user!.id,
                    updated,
                  );
            },
          ),

          const SizedBox(height: 12),

          // Email Notifications
          _buildSettingCard(
            context: context,
            title: 'Email Notifications',
            subtitle: 'Receive notifications via email',
            icon: Icons.email_outlined,
            value: settings.emailNotifications,
            onChanged: (value) {
              final updated = settings.copyWith(emailNotifications: value);
              ref.read(settingsProvider.notifier).updateNotificationSettings(
                    ref.read(authProvider).user!.id,
                    updated,
                  );
            },
          ),

          const SizedBox(height: 24),

          // Section Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Text(
              'NOTIFICATION TYPES',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          // Booking Updates
          _buildSettingCard(
            context: context,
            title: 'Booking Updates',
            subtitle: 'Get notified about booking status changes',
            icon: Icons.event_note,
            value: settings.bookingUpdates,
            onChanged: (value) {
              final updated = settings.copyWith(bookingUpdates: value);
              ref.read(settingsProvider.notifier).updateNotificationSettings(
                    ref.read(authProvider).user!.id,
                    updated,
                  );
            },
          ),

          const SizedBox(height: 12),

          // New Messages
          _buildSettingCard(
            context: context,
            title: 'New Messages',
            subtitle: 'Be notified when you receive new messages',
            icon: Icons.message_outlined,
            value: settings.newMessages,
            onChanged: (value) {
              final updated = settings.copyWith(newMessages: value);
              ref.read(settingsProvider.notifier).updateNotificationSettings(
                    ref.read(authProvider).user!.id,
                    updated,
                  );
            },
          ),

          const SizedBox(height: 12),

          // Promotions
          _buildSettingCard(
            context: context,
            title: 'Promotions & Offers',
            subtitle: 'Receive special offers and promotional content',
            icon: Icons.local_offer_outlined,
            value: settings.promotions,
            onChanged: (value) {
              final updated = settings.copyWith(promotions: value);
              ref.read(settingsProvider.notifier).updateNotificationSettings(
                    ref.read(authProvider).user!.id,
                    updated,
                  );
            },
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
            color: colorScheme.primaryContainer.withOpacity(0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: colorScheme.primary),
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
}