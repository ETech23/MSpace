// lib/features/jobs/presentation/screens/my_jobs_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/job_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/models/job_model.dart';
import '../../../../core/ads/ad_widgets.dart';

class MyJobsScreen extends ConsumerStatefulWidget {
  const MyJobsScreen({super.key});

  @override
  ConsumerState<MyJobsScreen> createState() => _MyJobsScreenState();
}

class _MyJobsScreenState extends ConsumerState<MyJobsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(authProvider).user;
      if (user != null) {
        ref.read(jobProvider.notifier).loadCustomerJobs(user.id);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final jobState = ref.watch(jobProvider);
    final allJobs = jobState.customerJobs;

    final activeJobs = allJobs
        .where((job) =>
            job.status == 'pending' ||
            job.status == 'matched' ||
            job.status == 'accepted' ||
            job.status == 'in_progress')
        .toList();

    final completedJobs =
        allJobs.where((job) => job.status == 'completed').toList();

    final cancelledJobs =
        allJobs.where((job) => job.status == 'cancelled').toList();

    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        title: Text(
          'My Jobs',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: colorScheme.primary,
          unselectedLabelColor: colorScheme.onSurfaceVariant,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
          indicator: UnderlineTabIndicator(
            borderSide: BorderSide(
              color: colorScheme.primary,
              width: 2,
            ),
          ),
          tabs: [
            Tab(text: 'Active (${activeJobs.length})'),
            Tab(text: 'Completed (${completedJobs.length})'),
            Tab(text: 'Cancelled (${cancelledJobs.length})'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildJobsList(context, jobState, activeJobs, 'active'),
          _buildJobsList(context, jobState, completedJobs, 'completed'),
          _buildJobsList(context, jobState, cancelledJobs, 'cancelled'),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/post-job'),
        icon: const Icon(Icons.add),
        label: const Text('Post Job'),
      ),
    );
  }

  Widget _buildJobsList(
    BuildContext context,
    dynamic jobState,
    List<JobModel> jobs,
    String type,
  ) {
    if (jobState.isLoading && jobs.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (jobs.isEmpty) {
      return _EmptyState(type: type);
    }

    return RefreshIndicator(
      onRefresh: () async {
        final user = ref.read(authProvider).user;
        if (user != null) {
          await ref.read(jobProvider.notifier).loadCustomerJobs(user.id);
        }
      },
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: jobs.isEmpty ? 0 : jobs.length + (jobs.length / 3).floor(),
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          const adInterval = 3;
          final isAdIndex = (index + 1) % (adInterval + 1) == 0;
          if (isAdIndex) {
            return const NativeAdWidget();
          }

          final jobIndex = index - (index ~/ (adInterval + 1));
          return _JobCard(job: jobs[jobIndex]);
        },
      ),
    );
  }
}

class _JobCard extends StatelessWidget {
  final JobModel job;

  const _JobCard({required this.job});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: colorScheme.outlineVariant.withOpacity(0.5),
        ),
      ),
      child: InkWell(
        onTap: () => context.push('/jobs/${job.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  _StatusBadge(status: job.status),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      job.category,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (job.isUrgent)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.priority_high,
                            size: 12,
                            color: colorScheme.onErrorContainer,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            'Urgent',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: colorScheme.onErrorContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 12),

              // Title
              Text(
                job.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 6),

              // Description
              Text(
                job.description,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 12),

              // Info Chips
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _InfoChip(
                    icon: Icons.calendar_today_outlined,
                    label: _formatDate(job.createdAt),
                  ),
                  if (job.budgetMin != null || job.budgetMax != null)
                    _InfoChip(
                      icon: Icons.payments_outlined,
                      label: job.budgetDisplay,
                    ),
                  _InfoChip(
                    icon: Icons.people_outline,
                    label: '${job.notifiedArtisanCount} notified',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      if (diff.inHours == 0) {
        return '${diff.inMinutes}m ago';
      }
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final config = _getStatusConfig(status, colorScheme);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: config.color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: config.color.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(config.icon, size: 12, color: config.color),
          const SizedBox(width: 4),
          Text(
            config.label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: config.color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  _StatusConfig _getStatusConfig(String status, ColorScheme colorScheme) {
    switch (status) {
      case 'pending':
        return _StatusConfig(
          color: Colors.orange.shade700,
          icon: Icons.pending,
          label: 'Pending',
        );
      case 'matched':
        return _StatusConfig(
          color: Colors.blue.shade700,
          icon: Icons.notifications_active,
          label: 'Matched',
        );
      case 'accepted':
        return _StatusConfig(
          color: Colors.green.shade700,
          icon: Icons.check_circle,
          label: 'Accepted',
        );
      case 'in_progress':
        return _StatusConfig(
          color: Colors.purple.shade700,
          icon: Icons.work,
          label: 'In Progress',
        );
      case 'completed':
        return _StatusConfig(
          color: Colors.teal.shade700,
          icon: Icons.done_all,
          label: 'Completed',
        );
      case 'cancelled':
        return _StatusConfig(
          color: colorScheme.error,
          icon: Icons.cancel,
          label: 'Cancelled',
        );
      default:
        return _StatusConfig(
          color: Colors.grey.shade700,
          icon: Icons.info,
          label: status,
        );
    }
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String type;

  const _EmptyState({required this.type});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _getIcon(type),
              size: 64,
              color: colorScheme.onSurfaceVariant.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              _getTitle(type),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _getMessage(type),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (type == 'active') ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => context.push('/post-job'),
                icon: const Icon(Icons.add),
                label: const Text('Post a Job'),
              ),
            ],
            const SizedBox(height: 16),
            const BannerAdWidget(),
          ],
        ),
      ),
    );
  }

  IconData _getIcon(String type) {
    switch (type) {
      case 'active':
        return Icons.work_outline;
      case 'completed':
        return Icons.done_all;
      case 'cancelled':
        return Icons.cancel_outlined;
      default:
        return Icons.inbox_outlined;
    }
  }

  String _getTitle(String type) {
    switch (type) {
      case 'active':
        return 'No active jobs';
      case 'completed':
        return 'No completed jobs';
      case 'cancelled':
        return 'No cancelled jobs';
      default:
        return 'No jobs';
    }
  }

  String _getMessage(String type) {
    switch (type) {
      case 'active':
        return 'Post your first job to find skilled artisans';
      case 'completed':
        return 'Completed jobs will appear here';
      case 'cancelled':
        return 'Cancelled jobs will appear here';
      default:
        return '';
    }
  }
}

class _StatusConfig {
  final Color color;
  final IconData icon;
  final String label;

  _StatusConfig({
    required this.color,
    required this.icon,
    required this.label,
  });
}
