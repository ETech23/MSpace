// lib/features/jobs/presentation/screens/artisan_job_matches_screen.dart
// ✅ UPDATED: Navigates to booking after accepting job

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/job_provider.dart';
import '../../data/models/job_model.dart';

class ArtisanJobMatchesScreen extends ConsumerStatefulWidget {
  const ArtisanJobMatchesScreen({super.key});

  @override
  ConsumerState<ArtisanJobMatchesScreen> createState() => _ArtisanJobMatchesScreenState();
}

class _ArtisanJobMatchesScreenState extends ConsumerState<ArtisanJobMatchesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(authProvider).user;
      if (user != null) {
        ref.read(jobProvider.notifier).loadArtisanMatches(user.id);
      }
    });
  }

  // 🆕 UPDATED: Now navigates to booking after accepting
  Future<void> _acceptJob(JobMatchModel match) async {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Accept Job?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Job: ${match.job?.title}'),
            const SizedBox(height: 8),
            Text('Customer: ${match.job?.customerName ?? 'Unknown'}'),
            const SizedBox(height: 8),
            Text('Distance: ${match.distanceKm.toStringAsFixed(1)}km away'),
            const SizedBox(height: 16),
            // 🆕 Better explanation
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: Colors.blue),
                      const SizedBox(width: 8),
                      Text(
                        'What happens next:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• A booking will be created\n'
                    '• Customer will be notified\n'
                    '• Manage it in your bookings',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Accept Job'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    final result = await ref.read(jobProvider.notifier).acceptJob(
      match.jobId,
      user.id,
    );

    if (!mounted) return;
    
    // Close loading dialog
    Navigator.pop(context);

    if (result != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Job accepted! Booking created.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
      
      // 🆕 NAVIGATE TO THE BOOKING
      if (result.bookingId != null) {
        // Wait a moment for the snackbar to show
        await Future.delayed(const Duration(milliseconds: 500));
        
        if (mounted) {
          context.push('/bookings/${result.bookingId}');
        }
      } else {
        // Fallback: booking might not have been created yet
        print('⚠️ Job accepted but booking_id is null');
      }
    } else {
      // Show specific error message
      final errorMsg = ref.read(jobProvider).error ?? 'Failed to accept job';
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMsg),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
      
      // If job was already accepted, refresh the list to remove it
      if (errorMsg.contains('already been accepted')) {
        final user = ref.read(authProvider).user;
        if (user != null) {
          ref.read(jobProvider.notifier).loadArtisanMatches(user.id);
        }
      }
    }
  }

  Future<void> _declineJob(JobMatchModel match) async {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Decline Job?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to decline "${match.job?.title}"?'),
            const SizedBox(height: 12),
            const Text(
              'This job will be removed from your list.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Decline'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await ref.read(jobProvider.notifier).rejectJob(match.jobId, user.id);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Job declined'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final state = ref.watch(jobProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Available Jobs'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              final user = ref.read(authProvider).user;
              if (user != null) {
                ref.read(jobProvider.notifier).loadArtisanMatches(user.id);
              }
            },
          ),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.artisanMatches.isEmpty
              ? _EmptyState()
              : RefreshIndicator(
                  onRefresh: () async {
                    final user = ref.read(authProvider).user;
                    if (user != null) {
                      await ref.read(jobProvider.notifier).loadArtisanMatches(user.id);
                    }
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: state.artisanMatches.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final match = state.artisanMatches[index];
                      return _JobMatchCard(
                        match: match,
                        onAccept: () => _acceptJob(match),
                        onDecline: () => _declineJob(match),
                        onViewDetails: () {
                          context.push('/jobs/${match.jobId}');
                        },
                      );
                    },
                  ),
                ),
    );
  }
}

// ... Rest of the file (JobMatchCard, InfoChip, EmptyState) remains the same ...
class _JobMatchCard extends StatelessWidget {
  final JobMatchModel match;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback onViewDetails;

  const _JobMatchCard({
    required this.match,
    required this.onAccept,
    required this.onDecline,
    required this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final job = match.job;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: match.isPremiumArtisan
              ? Colors.amber
              : colorScheme.outline.withOpacity(0.2),
          width: match.isPremiumArtisan ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with match score
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getMatchScoreColor(match.matchScore).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.star,
                        size: 16,
                        color: _getMatchScoreColor(match.matchScore),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${match.matchScore.toStringAsFixed(0)}% Match',
                        style: TextStyle(
                          color: _getMatchScoreColor(match.matchScore),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                if (match.isPremiumArtisan)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.star, size: 14, color: Colors.amber),
                        SizedBox(width: 4),
                        Text(
                          'Priority',
                          style: TextStyle(
                            color: Colors.amber,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(width: 8),
                Text(
                  timeago.format(job!.createdAt.toLocal()),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Job title and category
            Text(
              job.title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.category,
                  size: 16,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 4),
                Text(
                  job.category,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Description
            Text(
              job.description,
              style: theme.textTheme.bodyMedium,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),

            // Job details
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _InfoChip(
                  icon: Icons.location_on,
                  label: '${match.distanceKm.toStringAsFixed(1)}km away',
                  color: Colors.blue,
                ),
                if (job.budgetMin != null && job.budgetMax != null)
                  _InfoChip(
                    icon: Icons.payments,
                    label: '₦${job.budgetMin}-₦${job.budgetMax}',
                    color: Colors.green,
                  ),
                if (job.isUrgent)
                  _InfoChip(
                    icon: Icons.priority_high,
                    label: 'Urgent',
                    color: Colors.red,
                  ),
                if (job.preferredDate != null)
                  _InfoChip(
                    icon: Icons.calendar_today,
                    label: _formatDate(job.preferredDate!),
                    color: Colors.orange,
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Customer info
            if (job.customerName != null) ...[
              Divider(height: 1, color: colorScheme.outline.withOpacity(0.2)),
              const SizedBox(height: 12),
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: colorScheme.primaryContainer,
                    backgroundImage: job.customerPhotoUrl != null
                        ? NetworkImage(job.customerPhotoUrl!)
                        : null,
                    child: job.customerPhotoUrl == null
                        ? Text(
                            job.customerName![0].toUpperCase(),
                            style: TextStyle(
                              color: colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    job.customerName!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onDecline,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey[700],
                    ),
                    child: const Text('Decline'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: onViewDetails,
                    child: const Text('Details'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: onAccept,
                    icon: const Icon(Icons.check),
                    label: const Text('Accept'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getMatchScoreColor(double score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.orange;
    return Colors.grey;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = date.difference(now).inDays;
    
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    if (diff < 7) return 'In $diff days';
    
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
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
              Icons.work_outline,
              size: 80,
              color: colorScheme.onSurfaceVariant.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No Available Jobs',
              style: theme.textTheme.titleLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'New job requests matching your skills will appear here.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}