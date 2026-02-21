import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/models/job_model.dart';
import '../providers/job_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class JobDetailsScreen extends ConsumerStatefulWidget {
  final String jobId;

  const JobDetailsScreen({super.key, required this.jobId});

  @override
  ConsumerState<JobDetailsScreen> createState() => _JobDetailsScreenState();
}

class _JobDetailsScreenState extends ConsumerState<JobDetailsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final jobs = ref.read(jobProvider).customerJobs;
      final job = jobs.where((j) => j.id == widget.jobId).isNotEmpty
          ? jobs.where((j) => j.id == widget.jobId).first
          : null;

      if (job == null) {
        await ref.read(jobProvider.notifier).loadJobById(widget.jobId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final jobs = ref.watch(jobProvider).customerJobs;
    final job = jobs.where((j) => j.id == widget.jobId).isNotEmpty
        ? jobs.where((j) => j.id == widget.jobId).first
        : null;

    final user = ref.read(authProvider).user;
    final isOwner = user != null && job?.customerId == user.id;
    final isArtisan = user != null && user.userType == 'artisan';
    final jobState = ref.watch(jobProvider);
    final artisanMatch = (isArtisan && job != null)
        ? (jobState.artisanMatches
                .where((m) => m.jobId == job.id && m.artisanId == user.id)
                .isNotEmpty
            ? jobState.artisanMatches
                .where((m) => m.jobId == job.id && m.artisanId == user.id)
                .first
            : null)
        : null;

    if (job == null) {
      final state = ref.watch(jobProvider);
      if (state.isLoading) {
        return Scaffold(
          appBar: AppBar(title: const Text('Job Details')),
          body: const Center(child: CircularProgressIndicator()),
        );
      }

      return Scaffold(
        appBar: AppBar(title: const Text('Job Details')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.search_off,
                  size: 64,
                  color: colorScheme.onSurfaceVariant.withOpacity(0.3),
                ),
                const SizedBox(height: 24),
                Text(
                  'Job not found',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'This job may have been removed or is unavailable.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () async {
                    await ref
                        .read(jobProvider.notifier)
                        .loadJobById(widget.jobId);
                  },
                  child: const Text('Retry'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => context.pop(),
                  child: const Text('Go Back'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        title: const Text('Job Details'),
        actions: [
          if (isOwner && (job.isPending || job.status == 'matched'))
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                // TODO: Edit job
              },
            ),
          if (isOwner && !job.isCompleted && !job.isCancelled)
            IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: () => _showOptionsMenu(context, job),
            ),
          if (!isOwner)
            IconButton(
              icon: const Icon(Icons.flag_outlined),
              onPressed: () {
                context.push('/report', extra: {
                  'targetType': 'job',
                  'targetId': job.id,
                  'targetLabel': job.title ?? 'Job',
                });
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status & Category
            Row(
              children: [
                _StatusBadge(status: job.status),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    job.category,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (job.isUrgent) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.priority_high,
                          size: 14,
                          color: colorScheme.onErrorContainer,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Urgent',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: colorScheme.onErrorContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 20),

            // Title
            Text(
              job.title,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 24),

            // Main Info Card
            _InfoSection(
              children: [
                _InfoRow(
                  icon: Icons.description_outlined,
                  label: 'Description',
                  child: Text(
                    job.description,
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
                if (job.budgetMin != null || job.budgetMax != null) ...[
                  const Divider(height: 32),
                  _InfoRow(
                    icon: Icons.payments_outlined,
                    label: 'Budget',
                    child: Text(
                      job.budgetDisplay,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                const Divider(height: 32),
                _InfoRow(
                  icon: Icons.location_on_outlined,
                  label: 'Location',
                  child: Text(job.address ?? 'Not specified'),
                ),
                if (job.preferredDate != null) ...[
                  const Divider(height: 32),
                  _InfoRow(
                    icon: Icons.calendar_today_outlined,
                    label: 'Preferred Date',
                    child: Text(
                      '${job.preferredDate!.day}/${job.preferredDate!.month}/${job.preferredDate!.year}'
                      '${job.preferredTimeStart != null ? ' at ${job.preferredTimeStart}' : ''}',
                    ),
                  ),
                ],
                const Divider(height: 32),
                _InfoRow(
                  icon: Icons.people_outline,
                  label: 'Notified Artisans',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${job.notifiedArtisanCount} artisan${job.notifiedArtisanCount != 1 ? 's' : ''}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (isOwner && job.notifiedArtisanCount == 0) ...[
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () => _expandSearch(job),
                          icon: const Icon(Icons.search, size: 18),
                          label: const Text('Search Wider Area'),
                        ),
                      ],
                    ],
                  ),
                ),
                const Divider(height: 32),
                _InfoRow(
                  icon: Icons.access_time,
                  label: 'Posted',
                  child: Text(_getTimeAgo(job.createdAt)),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Actions
            if (!job.isCompleted && !job.isCancelled) ...[
              if (isOwner)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _cancelJob(job),
                    icon: Icon(Icons.cancel_outlined,
                        color: colorScheme.error),
                    label: Text(
                      'Cancel Job',
                      style: TextStyle(color: colorScheme.error),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: colorScheme.error),
                    ),
                  ),
                ),
              if (isArtisan &&
                  artisanMatch != null &&
                  (artisanMatch.response == null ||
                      artisanMatch.response == 'pending') &&
                  job.status == 'pending')
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Decline Job?'),
                              content: const Text(
                                  'Are you sure you want to decline this job request?'),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text('No'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Yes, Decline'),
                                ),
                              ],
                            ),
                          );

                          if (confirmed == true && mounted) {
                            await ref
                                .read(jobProvider.notifier)
                                .rejectJob(job.id, user.id);
                            if (mounted) {
                              context.pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('Job declined')));
                            }
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Decline'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: () async {
                          final result = await ref
                              .read(jobProvider.notifier)
                              .acceptJob(job.id, user.id);
                          if (result != null) {
                            if (mounted) {
                              context.pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('Job accepted')));
                            }
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(ref.read(jobProvider).error ??
                                    'Failed to accept job'),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('Accept Job'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return '${difference.inSeconds}s ago';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  void _showOptionsMenu(BuildContext context, JobModel job) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('Edit Job'),
            onTap: () {
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.search),
            title: const Text('Expand Search'),
            onTap: () {
              Navigator.pop(context);
              _expandSearch(job);
            },
          ),
          ListTile(
            leading: Icon(Icons.cancel,
                color: Theme.of(context).colorScheme.error),
            title: Text('Cancel Job',
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
            onTap: () {
              Navigator.pop(context);
              _cancelJob(job);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _expandSearch(JobModel job) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Expanding search to 50km...')),
    );
  }

  Future<void> _cancelJob(JobModel job) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Job?'),
        content:
            const Text('Are you sure you want to cancel this job request?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await ref.read(jobProvider.notifier).cancelJob(job.id);
      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Job cancelled')),
        );
      }
    }
  }
}

class _InfoSection extends StatelessWidget {
  final List<Widget> children;

  const _InfoSection({required this.children});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outlineVariant.withOpacity(0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget child;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: config.color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: config.color.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(config.icon, size: 14, color: config.color),
          const SizedBox(width: 6),
          Text(
            config.label,
            style: theme.textTheme.labelMedium?.copyWith(
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