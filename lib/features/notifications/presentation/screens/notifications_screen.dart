// lib/features/notifications/presentation/screens/notifications_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
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
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _activeTab = 0;
  String? _watchingUserId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this)
      ..addListener(() {
        if (_tabController.indexIsChanging) {
          setState(() => _activeTab = _tabController.index);
        }
      });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(authProvider).user;
      if (user != null) {
        _startWatchers(user.id);
      }
    });
  }

  void _startWatchers(String userId) {
    if (_watchingUserId == userId) return;
    _watchingUserId = userId;
    ref.read(bookingNotificationProvider.notifier).watchNotifications(userId);
    ref.read(systemNotificationProvider.notifier).watchNotifications(userId);
    ref.read(jobNotificationProvider.notifier).watchNotifications(userId);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _handleNotificationTap(NotificationEntity notification) async {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    switch (notification.type) {
      case NotificationType.system:
        final data = notification.data ?? {};
        final action = data['action'] as String?;
        if (action == null || action.isEmpty) return;
        ref.read(systemNotificationProvider.notifier).markAsRead(notification.id, user.id);
        if (action == 'open_edit_profile' && mounted) context.push('/profile/edit');
        break;

      case NotificationType.booking:
        ref.read(bookingNotificationProvider.notifier).markAsRead(notification.id, user.id);
        if (notification.relatedId != null && mounted) {
          context.push('/bookings/${notification.relatedId}');
        }
        break;

      case NotificationType.message:
        ref.read(messageNotificationProvider.notifier).markAsRead(notification.id, user.id);
        if (mounted) context.push('/messages');
        break;

      case NotificationType.job:
        ref.read(jobNotificationProvider.notifier).markAsRead(notification.id, user.id);
        if (notification.relatedId != null && mounted) {
          final subType = (notification.data ?? {})['subType'] as String?;
          if (subType == 'job_accepted') {
            context.push('/jobs/${notification.relatedId}');
          } else {
            context.push('/artisan/job-matches');
          }
        }
        break;

      case NotificationType.payment:
        break;
    }
  }

  void _markAllAsRead() {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    HapticFeedback.lightImpact();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        final colorScheme = Theme.of(ctx).colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.onSurfaceVariant.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                Text('Mark all as read?',
                    style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(
                  'All notifications in this tab will be marked as read.',
                  style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        ref.read(bookingNotificationProvider.notifier).markAllAsRead(user.id);
                        ref.read(systemNotificationProvider.notifier).markAllAsRead(user.id);
                        ref.read(jobNotificationProvider.notifier).markAllAsRead(user.id);
                      },
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Mark as read'),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    if (user != null) {
      _startWatchers(user.id);
    } else {
      _watchingUserId = null;
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final systemUnread = ref.watch(systemUnreadCountProvider);
    final bookingUnread = ref.watch(bookingUnreadCountProvider);
    final jobUnread = ref.watch(jobUnreadCountProvider);
    final totalUnread = systemUnread + bookingUnread + jobUnread;

    final tabs = [
      _TabItem(label: 'All', icon: Icons.inbox_rounded, count: totalUnread),
      _TabItem(label: 'Jobs', icon: Icons.work_rounded, count: jobUnread),
      _TabItem(label: 'Bookings', icon: Icons.calendar_month_rounded, count: bookingUnread),
      _TabItem(label: 'System', icon: Icons.info_rounded, count: systemUnread),
    ];

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            pinned: true,
            floating: false,
            backgroundColor: colorScheme.surface,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            titleSpacing: 20,
            title: Row(
              children: [
                Text(
                  'Notifications',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: colorScheme.onSurface,
                  ),
                ),
                if (totalUnread > 0) ...[
                  const SizedBox(width: 10),
                  _CountBubble(count: totalUnread, color: colorScheme.primary),
                ],
              ],
            ),
            actions: [
              if (totalUnread > 0)
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: TextButton.icon(
                    onPressed: _markAllAsRead,
                    icon: const Icon(Icons.done_all_rounded, size: 16),
                    label: const Text('Read all'),
                    style: TextButton.styleFrom(
                      foregroundColor: colorScheme.primary,
                      textStyle: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                  ),
                ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(44),
              child: SizedBox(
                height: 44,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minWidth: constraints.maxWidth),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (var i = 0; i < tabs.length; i++) ...[
                              if (i > 0) const SizedBox(width: 8),
                              _TabChip(
                                item: tabs[i],
                                selected: _activeTab == i,
                                onTap: () {
                                  _tabController.animateTo(i);
                                  setState(() => _activeTab = i);
                                },
                                colorScheme: colorScheme,
                                isDark: isDark,
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _CombinedNotificationsTab(onTap: _handleNotificationTap),
            _JobNotificationsTab(onTap: _handleNotificationTap),
            _BookingNotificationsTab(onTap: _handleNotificationTap),
            _SystemNotificationsTab(onTap: _handleNotificationTap),
          ],
        ),
      ),
    );
  }
}

// ── Custom tab chip ────────────────────────────────────────────────────────────

class _TabItem {
  final String label;
  final IconData icon;
  final int count;
  const _TabItem({required this.label, required this.icon, required this.count});
}

class _TabChip extends StatelessWidget {
  const _TabChip({
    required this.item,
    required this.selected,
    required this.onTap,
    required this.colorScheme,
    required this.isDark,
  });

  final _TabItem item;
  final bool selected;
  final VoidCallback onTap;
  final ColorScheme colorScheme;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
        height: 30,
        decoration: BoxDecoration(
          color: selected
              ? colorScheme.primary
              : isDark
                  ? Colors.white.withOpacity(0.07)
                  : colorScheme.primary.withOpacity(0.07),
          borderRadius: BorderRadius.circular(20),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: colorScheme.primary.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  )
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              item.icon,
              size: 13,
              color: selected
                  ? colorScheme.onPrimary
                  : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 5),
            Text(
              item.label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected
                    ? colorScheme.onPrimary
                    : colorScheme.onSurfaceVariant,
              ),
            ),
            if (item.count > 0) ...[
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withOpacity(0.25)
                      : colorScheme.error,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  item.count > 99 ? '99+' : '${item.count}',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: selected ? colorScheme.onPrimary : Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CountBubble extends StatelessWidget {
  const _CountBubble({required this.count, required this.color});
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ── Notification list tabs ─────────────────────────────────────────────────────

class _CombinedNotificationsTab extends ConsumerWidget {
  final Future<void> Function(NotificationEntity) onTap;
  const _CombinedNotificationsTab({required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingState = ref.watch(bookingNotificationProvider);
    final systemState = ref.watch(systemNotificationProvider);
    final jobState = ref.watch(jobNotificationProvider);

    final all = [
      ...bookingState.notifications,
      ...systemState.notifications,
      ...jobState.notifications,
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final isLoading = bookingState.isLoading || systemState.isLoading || jobState.isLoading;

    if (isLoading && all.isEmpty) return const _LoadingState();
    if (all.isEmpty) {
      return const _EmptyState(
        icon: Icons.inbox_rounded,
        title: 'All clear',
        message: "You're fully caught up — nothing new here.",
      );
    }

    return _NotificationListView(
      notifications: all,
      onTap: onTap,
      onDelete: (n) {
        final user = ref.read(authProvider).user;
        if (user == null) return;
        if (n.type == NotificationType.booking) {
          ref.read(bookingNotificationProvider.notifier).deleteNotification(n.id, user.id);
        } else if (n.type == NotificationType.job) {
          ref.read(jobNotificationProvider.notifier).deleteNotification(n.id, user.id);
        } else {
          ref.read(systemNotificationProvider.notifier).deleteNotification(n.id, user.id);
        }
      },
      onRefresh: () async {
        final user = ref.read(authProvider).user;
        if (user == null) return;
        await Future.wait([
          ref.read(bookingNotificationProvider.notifier).loadNotifications(user.id),
          ref.read(systemNotificationProvider.notifier).loadNotifications(user.id),
          ref.read(jobNotificationProvider.notifier).loadNotifications(user.id),
        ]);
      },
    );
  }
}

class _JobNotificationsTab extends ConsumerWidget {
  final Future<void> Function(NotificationEntity) onTap;
  const _JobNotificationsTab({required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(jobNotificationProvider);
    if (state.isLoading) return const _LoadingState();
    if (state.notifications.isEmpty) {
      return const _EmptyState(
        icon: Icons.work_outline_rounded,
        title: 'No job alerts',
        message: 'Job requests and updates will appear here.',
      );
    }
    return _NotificationListView(
      notifications: state.notifications,
      onTap: onTap,
      onDelete: (n) {
        final user = ref.read(authProvider).user;
        if (user != null) {
          ref.read(jobNotificationProvider.notifier).deleteNotification(n.id, user.id);
        }
      },
      onRefresh: () async {
        final user = ref.read(authProvider).user;
        if (user != null) {
          await ref.read(jobNotificationProvider.notifier).loadNotifications(user.id);
        }
      },
    );
  }
}

class _BookingNotificationsTab extends ConsumerWidget {
  final Future<void> Function(NotificationEntity) onTap;
  const _BookingNotificationsTab({required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(bookingNotificationProvider);
    if (state.isLoading) return const _LoadingState();
    if (state.notifications.isEmpty) {
      return const _EmptyState(
        icon: Icons.calendar_month_outlined,
        title: 'No bookings yet',
        message: 'Booking confirmations and updates will show here.',
      );
    }
    return _NotificationListView(
      notifications: state.notifications,
      onTap: onTap,
      onDelete: (n) {
        final user = ref.read(authProvider).user;
        if (user != null) {
          ref.read(bookingNotificationProvider.notifier).deleteNotification(n.id, user.id);
        }
      },
      onRefresh: () async {
        final user = ref.read(authProvider).user;
        if (user != null) {
          await ref.read(bookingNotificationProvider.notifier).loadNotifications(user.id);
        }
      },
    );
  }
}

class _SystemNotificationsTab extends ConsumerWidget {
  final Future<void> Function(NotificationEntity) onTap;
  const _SystemNotificationsTab({required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(systemNotificationProvider);
    if (state.isLoading) return const _LoadingState();
    if (state.notifications.isEmpty) {
      return const _EmptyState(
        icon: Icons.info_outline_rounded,
        title: 'No system messages',
        message: 'Announcements and account alerts will appear here.',
      );
    }
    return _NotificationListView(
      notifications: state.notifications,
      onTap: onTap,
      onDelete: (n) {
        final user = ref.read(authProvider).user;
        if (user != null) {
          ref.read(systemNotificationProvider.notifier).deleteNotification(n.id, user.id);
        }
      },
      onRefresh: () async {
        final user = ref.read(authProvider).user;
        if (user != null) {
          await ref.read(systemNotificationProvider.notifier).loadNotifications(user.id);
        }
      },
    );
  }
}

// ── Shared list view ───────────────────────────────────────────────────────────

class _NotificationListView extends StatelessWidget {
  const _NotificationListView({
    required this.notifications,
    required this.onTap,
    required this.onDelete,
    required this.onRefresh,
  });

  final List<NotificationEntity> notifications;
  final Future<void> Function(NotificationEntity) onTap;
  final void Function(NotificationEntity) onDelete;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    const adInterval = 4;
    final adSlots = (notifications.length / adInterval).floor();
    final totalCount = notifications.length + adSlots + 1;

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 8, bottom: 100),
        itemCount: totalCount,
        itemBuilder: (context, index) {
          if (index == totalCount - 1) {
            return Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: BannerAdWidget()),
            );
          }

          final isAdIndex = (index + 1) % (adInterval + 1) == 0;
          if (isAdIndex) {
            return Padding(
              padding: EdgeInsets.symmetric(vertical: 8, horizontal: 20),
              child: BannerAdWidget(),
            );
          }

          final itemIndex = index - (index ~/ (adInterval + 1));
          if (itemIndex >= notifications.length) return const SizedBox.shrink();

          final notification = notifications[itemIndex];
          final isActionable = _isActionable(notification);

          return _NotificationTile(
            notification: notification,
            onTap: isActionable ? () => onTap(notification) : null,
            onDelete: () => onDelete(notification),
          );
        },
      ),
    );
  }
}

bool _isActionable(NotificationEntity n) {
  if (n.type == NotificationType.system) {
    return (n.data ?? {})['action'] == 'open_edit_profile';
  }
  return true;
}

// ── Premium notification tile ──────────────────────────────────────────────────

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.onTap,
    required this.onDelete,
  });

  final NotificationEntity notification;
  final VoidCallback? onTap;
  final VoidCallback onDelete;

  _NotifStyle _style(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    switch (notification.type) {
      case NotificationType.booking:
        return _NotifStyle(
          icon: Icons.calendar_month_rounded,
          color: const Color(0xFF2E7D32),
          bg: const Color(0xFF2E7D32).withOpacity(0.1),
        );
      case NotificationType.system:
        return _NotifStyle(
          icon: Icons.info_rounded,
          color: cs.primary,
          bg: cs.primary.withOpacity(0.1),
        );
      case NotificationType.message:
        return _NotifStyle(
          icon: Icons.chat_bubble_rounded,
          color: const Color(0xFF1565C0),
          bg: const Color(0xFF1565C0).withOpacity(0.1),
        );
      case NotificationType.job:
        return _NotifStyle(
          icon: Icons.work_rounded,
          color: const Color(0xFFE65100),
          bg: const Color(0xFFE65100).withOpacity(0.1),
        );
      case NotificationType.payment:
        return _NotifStyle(
          icon: Icons.payments_rounded,
          color: const Color(0xFF6A1B9A),
          bg: const Color(0xFF6A1B9A).withOpacity(0.1),
        );
    }
  }

  bool get _isAppeal {
    if (notification.type != NotificationType.system) return false;
    final action = (notification.data ?? {})['action'] as String?;
    final subType = (notification.data ?? {})['subType'] as String?;
    return action == 'open_appeal' || subType == 'suspended' || subType == 'blocked';
  }

  Future<void> _openAppeal(BuildContext context) async {
    const email = String.fromEnvironment('SUPPORT_EMAIL', defaultValue: 'support@mspace.app');
    final data = notification.data ?? {};
    final subType = (data['subType'] as String?) ?? 'moderation';
    final reason = (data['reason'] as String?) ?? '';
    final uri = Uri(
      scheme: 'mailto',
      path: email,
      queryParameters: {
        'subject': 'Account appeal - ${notification.userId}',
        'body':
            'Hello Support,\n\nI would like to appeal my account status.\n\n'
            'Status: $subType\nUser ID: ${notification.userId}\n'
            '${reason.isNotEmpty ? 'Reason: $reason\n' : ''}\nAppeal details:\n',
      },
    );
    final opened = await launchUrl(uri);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open email app.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final style = _style(context);
    final isUnread = !notification.read;

    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) {
        HapticFeedback.mediumImpact();
        onDelete();
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: colorScheme.error,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.delete_rounded, color: colorScheme.onError, size: 22),
            const SizedBox(height: 4),
            Text(
              'Delete',
              style: TextStyle(
                color: colorScheme.onError,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              decoration: BoxDecoration(
                color: isUnread
                    ? (isDark
                        ? Color.alphaBlend(
                            style.color.withOpacity(0.08),
                            colorScheme.surface)
                        : Color.alphaBlend(
                            style.color.withOpacity(0.04),
                            colorScheme.surface))
                    : (isDark
                        ? Color.alphaBlend(
                            Colors.white.withOpacity(0.04), colorScheme.surface)
                        : colorScheme.surface),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icon badge
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: style.bg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(style.icon, color: style.color, size: 20),
                    ),
                    const SizedBox(width: 12),

                    // Content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  notification.title,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: isUnread
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: colorScheme.onSurface,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Timestamp
                              Text(
                                timeago.format(notification.createdAt.toLocal()),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant
                                      .withOpacity(0.7),
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            notification.body,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              height: 1.5,
                              fontSize: 12,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),

                          // Appeal button
                          if (_isAppeal) ...[
                            const SizedBox(height: 8),
                            GestureDetector(
                              onTap: () => _openAppeal(context),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: colorScheme.error.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.mail_outline_rounded,
                                        size: 13, color: colorScheme.error),
                                    const SizedBox(width: 5),
                                    Text(
                                      'Send Appeal',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: colorScheme.error,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],

                          // Actionable chevron hint
                          if (onTap != null && !_isAppeal) ...[
                            const SizedBox(height: 6),
                            Row(children: [
                              Text(
                                'Tap to view',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: style.color.withOpacity(0.7),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 3),
                              Icon(Icons.arrow_forward_rounded,
                                  size: 11, color: style.color.withOpacity(0.7)),
                            ]),
                          ],
                        ],
                      ),
                    ),

                    // Unread dot
                    if (isUnread) ...[
                      const SizedBox(width: 10),
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(top: 5),
                        decoration: BoxDecoration(
                          color: style.color,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: style.color.withOpacity(0.4),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NotifStyle {
  final IconData icon;
  final Color color;
  final Color bg;
  const _NotifStyle({required this.icon, required this.color, required this.bg});
}

// ── Supporting widgets ─────────────────────────────────────────────────────────

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final shimmer = isDark
        ? Colors.white.withOpacity(0.06)
        : colorScheme.primary.withOpacity(0.05);

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(6, 8, 16, 8),
      itemCount: 5,
      itemBuilder: (_, i) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Container(
          height: 88,
          decoration: BoxDecoration(
            color: shimmer,
            borderRadius: BorderRadius.circular(16),
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
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: colorScheme.primary.withOpacity(0.07),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 40,
                color: colorScheme.primary.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            BannerAdWidget(),
          ],
        ),
      ),
    );
  }
}




