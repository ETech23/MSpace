// lib/features/notifications/presentation/screens/notifications_screen.dart
// FIXED: Proper navigation for job notifications

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/job_notification_provider.dart';
import '../../domain/entities/notification_entity.dart';
import '../../../../core/ads/ad_widgets.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(authProvider).user;
      if (user != null) {
        // ✅ Start watching for real-time updates
        ref.read(bookingNotificationProvider.notifier).watchNotifications(user.id);
        ref.read(systemNotificationProvider.notifier).watchNotifications(user.id);
        ref.read(jobNotificationProvider.notifier).watchNotifications(user.id);
        
        print('✅ Started watching all notification channels');
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ✅ FIXED: Proper navigation for job notifications
  Future<void> _handleNotificationTap(NotificationEntity notification) async {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    switch (notification.type) {
      case NotificationType.system:
        ref.read(systemNotificationProvider.notifier)
            .markAsRead(notification.id, user.id);
        break;
        
      case NotificationType.booking:
        ref.read(bookingNotificationProvider.notifier)
            .markAsRead(notification.id, user.id);
        
        if (notification.relatedId != null && mounted) {
          context.push('/bookings/${notification.relatedId}');
        }
        break;
        
      case NotificationType.message:
        ref.read(messageNotificationProvider.notifier)
            .markAsRead(notification.id, user.id);
        
        if (mounted) {
          context.push('/messages');
        }
        break;
        
      case NotificationType.job:
        // ✅ Mark as read
        ref.read(jobNotificationProvider.notifier)
            .markAsRead(notification.id, user.id);
        
        if (notification.relatedId != null && mounted) {
          final data = notification.data ?? {};
          final subType = data['subType'] as String?;
          
          print('📱 Job notification tapped: $subType');
          
          // ✅ FIXED: Navigate to job matches screen (not job detail)
          if (subType == 'job_match' || subType == 'new_job') {
            // Navigate to artisan's job matches/requests screen
            // This screen should show all available jobs they can accept
            context.push('/artisan/job-matches');
          } else if (subType == 'job_accepted') {
            // Navigate to the specific job detail (customer view)
            context.push('/jobs/${notification.relatedId}');
          } else {
            // Default: go to job matches
            context.push('/artisan/job-matches');
          }
        }
        break;
        
      case NotificationType.payment:
        break;
    }
  }

  void _markAllAsRead(NotificationType? type) {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark all as read?'),
        content: Text(
          type == null
              ? 'This will mark all notifications as read.'
              : 'This will mark all ${type.name} notifications as read.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              if (type == null) {
                ref.read(bookingNotificationProvider.notifier).markAllAsRead(user.id);
                ref.read(systemNotificationProvider.notifier).markAllAsRead(user.id);
                ref.read(jobNotificationProvider.notifier).markAllAsRead(user.id);
              } else {
                switch (type) {
                  case NotificationType.system:
                    ref.read(systemNotificationProvider.notifier).markAllAsRead(user.id);
                    break;
                  case NotificationType.booking:
                    ref.read(bookingNotificationProvider.notifier).markAllAsRead(user.id);
                    break;
                  case NotificationType.job:
                    ref.read(jobNotificationProvider.notifier).markAllAsRead(user.id);
                    break;
                  default:
                    break;
                }
              }
            },
            child: const Text('Mark as read'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final systemUnread = ref.watch(systemUnreadCountProvider);
    final bookingUnread = ref.watch(bookingUnreadCountProvider);
    final jobUnread = ref.watch(jobUnreadCountProvider);
    final totalUnread = systemUnread + bookingUnread + jobUnread;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        centerTitle: true,
        actions: [
          if (totalUnread > 0)
            IconButton(
              icon: const Icon(Icons.done_all),
              onPressed: () => _markAllAsRead(null),
              tooltip: 'Mark all as read',
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('All'),
                  if (totalUnread > 0) ...[
                    const SizedBox(width: 4),
                    _UnreadBadge(count: totalUnread),
                  ],
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.work, size: 16),
                  const SizedBox(width: 4),
                  const Text('Jobs'),
                  if (jobUnread > 0) ...[
                    const SizedBox(width: 4),
                    _UnreadBadge(count: jobUnread),
                  ],
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.calendar_today, size: 16),
                  const SizedBox(width: 4),
                  const Text('Bookings'),
                  if (bookingUnread > 0) ...[
                    const SizedBox(width: 4),
                    _UnreadBadge(count: bookingUnread),
                  ],
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.info, size: 16),
                  const SizedBox(width: 4),
                  const Text('System'),
                  if (systemUnread > 0) ...[
                    const SizedBox(width: 4),
                    _UnreadBadge(count: systemUnread),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _CombinedNotificationsTab(onTap: _handleNotificationTap),
          _JobNotificationsTab(onTap: _handleNotificationTap),
          _BookingNotificationsTab(onTap: _handleNotificationTap),
          _SystemNotificationsTab(onTap: _handleNotificationTap),
        ],
      ),
    );
  }
}

class _JobNotificationsTab extends ConsumerWidget {
  final Future<void> Function(NotificationEntity) onTap;

  const _JobNotificationsTab({required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(jobNotificationProvider);

    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.notifications.isEmpty) {
      return const _EmptyState(
        icon: Icons.work_outline,
        title: 'No job notifications',
        message: 'Job requests will appear here',
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        final user = ref.read(authProvider).user;
        if (user != null) {
          await ref.read(jobNotificationProvider.notifier)
              .loadNotifications(user.id);
        }
      },
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: state.notifications.length +
            (state.notifications.length / 3).floor() +
            1,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          const adInterval = 3;
          final adSlots = (state.notifications.length / adInterval).floor();
          final totalCount = state.notifications.length + adSlots;
          if (index == totalCount) {
            return const Center(child: BannerAdWidget());
          }
          final isAdIndex = (index + 1) % (adInterval + 1) == 0;
          if (isAdIndex) {
            return const Center(child: BannerAdWidget());
          }
          final itemIndex = index - (index ~/ (adInterval + 1));
          final notification = state.notifications[itemIndex];
          return _NotificationTile(
            notification: notification,
            onTap: () => onTap(notification),
            onDelete: () {
              final user = ref.read(authProvider).user;
              if (user != null) {
                ref.read(jobNotificationProvider.notifier)
                    .deleteNotification(notification.id, user.id);
              }
            },
          );
        },
      ),
    );
  }
}

class _UnreadBadge extends StatelessWidget {
  final int count;

  const _UnreadBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.red,
        borderRadius: BorderRadius.circular(10),
      ),
      constraints: const BoxConstraints(minWidth: 18),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _CombinedNotificationsTab extends ConsumerWidget {
  final Future<void> Function(NotificationEntity) onTap;

  const _CombinedNotificationsTab({required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingState = ref.watch(bookingNotificationProvider);
    final systemState = ref.watch(systemNotificationProvider);
    final jobState = ref.watch(jobNotificationProvider);

    final allNotifications = [
      ...bookingState.notifications,
      ...systemState.notifications,
      ...jobState.notifications,
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final isLoading = bookingState.isLoading || systemState.isLoading || jobState.isLoading;

    if (isLoading && allNotifications.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (allNotifications.isEmpty) {
      return const _EmptyState(
        icon: Icons.notifications_none,
        title: 'No notifications',
        message: 'You\'re all caught up!',
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        final user = ref.read(authProvider).user;
        if (user != null) {
          await Future.wait([
            ref.read(bookingNotificationProvider.notifier).loadNotifications(user.id),
            ref.read(systemNotificationProvider.notifier).loadNotifications(user.id),
            ref.read(jobNotificationProvider.notifier).loadNotifications(user.id),
          ]);
        }
      },
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: allNotifications.length +
            (allNotifications.length / 3).floor() +
            1,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          const adInterval = 3;
          final adSlots = (allNotifications.length / adInterval).floor();
          final totalCount = allNotifications.length + adSlots;
          if (index == totalCount) {
            return const Center(child: BannerAdWidget());
          }
          final isAdIndex = (index + 1) % (adInterval + 1) == 0;
          if (isAdIndex) {
            return const Center(child: BannerAdWidget());
          }
          final itemIndex = index - (index ~/ (adInterval + 1));
          final notification = allNotifications[itemIndex];
          return _NotificationTile(
            notification: notification,
            onTap: () => onTap(notification),
            onDelete: () {
              final user = ref.read(authProvider).user;
              if (user != null) {
                if (notification.type == NotificationType.booking) {
                  ref.read(bookingNotificationProvider.notifier)
                      .deleteNotification(notification.id, user.id);
                } else if (notification.type == NotificationType.job) {
                  ref.read(jobNotificationProvider.notifier)
                      .deleteNotification(notification.id, user.id);
                } else {
                  ref.read(systemNotificationProvider.notifier)
                      .deleteNotification(notification.id, user.id);
                }
              }
            },
          );
        },
      ),
    );
  }
}

class _BookingNotificationsTab extends ConsumerWidget {
  final Future<void> Function(NotificationEntity) onTap;

  const _BookingNotificationsTab({required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(bookingNotificationProvider);

    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.notifications.isEmpty) {
      return const _EmptyState(
        icon: Icons.calendar_today_outlined,
        title: 'No booking notifications',
        message: 'Booking updates will appear here',
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        final user = ref.read(authProvider).user;
        if (user != null) {
          await ref.read(bookingNotificationProvider.notifier)
              .loadNotifications(user.id);
        }
      },
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: state.notifications.length +
            (state.notifications.length / 3).floor() +
            1,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          const adInterval = 3;
          final adSlots = (state.notifications.length / adInterval).floor();
          final totalCount = state.notifications.length + adSlots;
          if (index == totalCount) {
            return const Center(child: BannerAdWidget());
          }
          final isAdIndex = (index + 1) % (adInterval + 1) == 0;
          if (isAdIndex) {
            return const Center(child: BannerAdWidget());
          }
          final itemIndex = index - (index ~/ (adInterval + 1));
          final notification = state.notifications[itemIndex];
          return _NotificationTile(
            notification: notification,
            onTap: () => onTap(notification),
            onDelete: () {
              final user = ref.read(authProvider).user;
              if (user != null) {
                ref.read(bookingNotificationProvider.notifier)
                    .deleteNotification(notification.id, user.id);
              }
            },
          );
        },
      ),
    );
  }
}

class _SystemNotificationsTab extends ConsumerWidget {
  final Future<void> Function(NotificationEntity) onTap;

  const _SystemNotificationsTab({required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(systemNotificationProvider);

    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.notifications.isEmpty) {
      return const _EmptyState(
        icon: Icons.info_outline,
        title: 'No system notifications',
        message: 'System announcements will appear here',
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        final user = ref.read(authProvider).user;
        if (user != null) {
          await ref.read(systemNotificationProvider.notifier)
              .loadNotifications(user.id);
        }
      },
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: state.notifications.length +
            (state.notifications.length / 3).floor() +
            1,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          const adInterval = 3;
          final adSlots = (state.notifications.length / adInterval).floor();
          final totalCount = state.notifications.length + adSlots;
          if (index == totalCount) {
            return const Center(child: BannerAdWidget());
          }
          final isAdIndex = (index + 1) % (adInterval + 1) == 0;
          if (isAdIndex) {
            return const Center(child: BannerAdWidget());
          }
          final itemIndex = index - (index ~/ (adInterval + 1));
          final notification = state.notifications[itemIndex];
          return _NotificationTile(
            notification: notification,
            onTap: () => onTap(notification),
            onDelete: () {
              final user = ref.read(authProvider).user;
              if (user != null) {
                ref.read(systemNotificationProvider.notifier)
                    .deleteNotification(notification.id, user.id);
              }
            },
          );
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final NotificationEntity notification;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _NotificationTile({
    required this.notification,
    required this.onTap,
    required this.onDelete,
  });

  IconData _getIcon() {
    switch (notification.type) {
      case NotificationType.booking:
        return Icons.calendar_today;
      case NotificationType.system:
        return Icons.info;
      case NotificationType.message:
        return Icons.message;
      case NotificationType.job:
        return Icons.work;
      case NotificationType.payment:
        return Icons.payment;
    }
  }

  Color _getColor(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    switch (notification.type) {
      case NotificationType.booking:
        return Colors.green;
      case NotificationType.system:
        return colorScheme.primary;
      case NotificationType.message:
        return Colors.blue;
      case NotificationType.job:
        return Colors.orange;
      case NotificationType.payment:
        return Colors.purple;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          color: notification.read 
              ? null 
              : colorScheme.primaryContainer.withOpacity(0.1),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _getColor(context).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _getIcon(),
                  color: _getColor(context),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: notification.read
                                  ? FontWeight.normal
                                  : FontWeight.bold,
                            ),
                          ),
                        ),
                        Text(
                          timeago.format(notification.createdAt.toLocal()),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.body,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (!notification.read) ...[
                const SizedBox(width: 8),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _getColor(context),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 80,
              color: colorScheme.onSurfaceVariant.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            const BannerAdWidget(),
          ],
        ),
      ),
    );
  }
}
