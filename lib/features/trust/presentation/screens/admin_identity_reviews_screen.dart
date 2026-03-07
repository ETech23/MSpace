// lib/features/trust/presentation/screens/admin_identity_reviews_screen_with_duplicates.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/trust_provider.dart';
import '../../domain/entities/identity_verification_entity.dart';

// Provider to get verification with duplicate info
final verificationWithDuplicateInfoProvider = 
    FutureProvider.family<Map<String, dynamic>, String>((ref, verificationId) async {
  try {
    final supabase = Supabase.instance.client;
    
    // Get verification details
    final verification = await supabase
        .from('identity_verifications')
        .select()
        .eq('id', verificationId)
        .single();
    
    final userId = verification['user_id'] as String;
    
    // Get user's verification history
    final history = await supabase
        .from('identity_verifications')
        .select()
        .eq('user_id', userId)
        .order('submitted_at', ascending: false);
    
    // Count previous submissions
    final totalSubmissions = history.length;
    final verifiedCount = history.where((v) => v['status'] == 'verified').length;
    final rejectedCount = history.where((v) => v['status'] == 'rejected').length;
    final pendingCount = history.where((v) => v['status'] == 'pending').length;
    
    // Get recent rejections
    final recentRejections = history.where((v) {
      if (v['status'] != 'rejected') return false;
      final reviewedAt = DateTime.parse(v['reviewed_at'] as String);
      return DateTime.now().difference(reviewedAt).inDays <= 7;
    }).toList();
    
    // Determine risk level
    String? riskFlag;
    String? warningMessage;
    
    if (recentRejections.length >= 3) {
      riskFlag = 'HIGH_RISK';
      warningMessage = '⚠️ HIGH RISK: ${recentRejections.length} rejections in last 7 days!';
    } else if (verifiedCount > 0) {
      riskFlag = 'DUPLICATE';
      warningMessage = '⚠️ WARNING: User already has ${verifiedCount} verified account(s)!';
    } else if (rejectedCount >= 5) {
      riskFlag = 'SUSPICIOUS';
      warningMessage = 'ℹ️ SUSPICIOUS: ${rejectedCount} total rejections. Review carefully.';
    } else if (totalSubmissions > 1) {
      riskFlag = 'INFO';
      warningMessage = 'ℹ️ INFO: User has submitted ${totalSubmissions} times.';
    }
    
    return {
      'verification': verification,
      'totalSubmissions': totalSubmissions,
      'verifiedCount': verifiedCount,
      'rejectedCount': rejectedCount,
      'pendingCount': pendingCount,
      'recentRejectionsCount': recentRejections.length,
      'history': history,
      'riskFlag': riskFlag,
      'warningMessage': warningMessage,
    };
  } catch (e) {
    print('Error fetching duplicate info: $e');
    rethrow;
  }
});

class ReviewedLogFilters {
  final String status;
  final bool last7DaysOnly;
  final String? adminId;
  final String? userId;

  const ReviewedLogFilters({
    this.status = 'all',
    this.last7DaysOnly = false,
    this.adminId,
    this.userId,
  });

  ReviewedLogFilters copyWith({
    String? status,
    bool? last7DaysOnly,
    String? adminId,
    String? userId,
  }) {
    return ReviewedLogFilters(
      status: status ?? this.status,
      last7DaysOnly: last7DaysOnly ?? this.last7DaysOnly,
      adminId: adminId ?? this.adminId,
      userId: userId ?? this.userId,
    );
  }
}

final reviewedLogFiltersProvider =
    StateProvider<ReviewedLogFilters>((ref) => const ReviewedLogFilters());

// Reviewed log provider (most recent reviewed verifications)
final reviewedVerificationsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = Supabase.instance.client;
  final filters = ref.watch(reviewedLogFiltersProvider);

  var query = supabase
      .from('identity_verifications')
      .select('id, user_id, status, reviewed_at, reviewed_by, doc_type')
      .not('reviewed_at', 'is', null);

  final adminId = filters.adminId;
  final userId = filters.userId;

  if (filters.status != 'all') {
    query = query.eq('status', filters.status);
  }
  if (filters.last7DaysOnly) {
    final cutoff = DateTime.now().subtract(const Duration(days: 7)).toIso8601String();
    query = query.gte('reviewed_at', cutoff);
  }
  if (adminId != null && adminId.isNotEmpty) {
    query = query.eq('reviewed_by', adminId);
  }
  if (userId != null && userId.isNotEmpty) {
    query = query.eq('user_id', userId);
  }

  final response = await query
      .order('reviewed_at', ascending: false)
      .limit(50);

  return (response as List)
      .cast<Map<String, dynamic>>();
});

class AdminIdentityReviewsScreen extends ConsumerWidget {
  const AdminIdentityReviewsScreen({super.key});

  Future<void> _approve(
    BuildContext context,
    WidgetRef ref,
    IdentityVerificationEntity item,
  ) async {
    final repo = ref.read(trustRepositoryProvider);
    final result = await repo.adminReviewIdentityVerification(
      verificationId: item.id,
      status: 'verified',
    );
    result.fold(
      (failure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Verification failed: ${failure.message}')),
        );
      },
      (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User verified successfully')),
        );
      },
    );
    ref.invalidate(adminIdentityQueueProvider);
  }

  Future<void> _reject(
    BuildContext context,
    WidgetRef ref,
    IdentityVerificationEntity item,
  ) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Reject Verification'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Please provide a reason for rejection:'),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Reason',
                  border: OutlineInputBorder(),
                  hintText: 'e.g., Document unclear, photo blurry, etc.',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Reject'),
            ),
          ],
        );
      },
    );

    if (reason == null || reason.isEmpty) return;

    final repo = ref.read(trustRepositoryProvider);
    final result = await repo.adminReviewIdentityVerification(
      verificationId: item.id,
      status: 'rejected',
      rejectionReason: reason,
    );
    result.fold(
      (failure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Rejection failed: ${failure.message}')),
        );
      },
      (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verification rejected')),
        );
      },
    );
    ref.invalidate(adminIdentityQueueProvider);
  }

  /// Show verification history modal
  void _showHistoryModal(BuildContext context, List<dynamic> history) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.history, size: 28),
                    const SizedBox(width: 12),
                    const Text(
                      'Verification History',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: history.length,
                    itemBuilder: (context, index) {
                      final item = history[index];
                      return _buildHistoryItem(item, context);
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHistoryItem(Map<String, dynamic> item, BuildContext context) {
    final status = item['status'] as String;
    final submittedAt = DateTime.parse(item['submitted_at'] as String);
    final reviewedAt = item['reviewed_at'] != null 
        ? DateTime.parse(item['reviewed_at'] as String)
        : null;
    
    Color statusColor;
    IconData statusIcon;
    
    switch (status) {
      case 'verified':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      case 'pending':
        statusColor = Colors.orange;
        statusIcon = Icons.pending;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help;
    }
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(statusIcon, color: statusColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  item['doc_type'] as String,
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Submitted: ${_formatDate(submittedAt)}',
              style: const TextStyle(fontSize: 12),
            ),
            if (reviewedAt != null)
              Text(
                'Reviewed: ${_formatDate(reviewedAt)}',
                style: const TextStyle(fontSize: 12),
              ),
            if (item['rejection_reason'] != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info, size: 16, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item['rejection_reason'] as String,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  /// Show full-screen image viewer
  void _viewFullImage(BuildContext context, String url, String title) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            title: Text(title),
            backgroundColor: Colors.black87,
            foregroundColor: Colors.white,
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.network(
                url,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.broken_image, size: 64, color: Colors.white54),
                        SizedBox(height: 16),
                        Text(
                          'Failed to load image',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  );
                },
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                      color: Colors.white,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showReviewedLogModal(
    BuildContext context,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            padding: const EdgeInsets.all(16),
            child: Consumer(
              builder: (context, ref, _) {
                final reviewedAsync = ref.watch(reviewedVerificationsProvider);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.history, size: 28),
                        const SizedBox(width: 12),
                        const Text(
                          'Reviewed Log',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          tooltip: 'Filters',
                          icon: const Icon(Icons.filter_list),
                          onPressed: () => _showReviewedLogFilters(context),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    Expanded(
                      child: reviewedAsync.when(
                        data: (reviewed) => ListView.separated(
                          controller: scrollController,
                          itemCount: reviewed.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final item = reviewed[index];
                            final reviewedAt = DateTime.parse(
                              item['reviewed_at'] as String,
                            );
                            final status = item['status'] as String? ?? 'unknown';
                            final userId = item['user_id'] as String? ?? '';
                            final docType = item['doc_type'] as String? ?? 'Document';

                            return ListTile(
                              dense: true,
                              leading: Icon(
                                status == 'verified'
                                    ? Icons.check_circle
                                    : status == 'rejected'
                                        ? Icons.cancel
                                        : Icons.help,
                                color: status == 'verified'
                                    ? Colors.green
                                    : status == 'rejected'
                                        ? Colors.red
                                        : Colors.grey,
                                size: 20,
                              ),
                              title: Text(
                                '${status.toUpperCase()} · ${userId.substring(0, 8)}...',
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text(
                                '$docType · ${_formatDate(reviewedAt)}',
                              ),
                            );
                          },
                        ),
                        loading: () => const Center(
                          child: CircularProgressIndicator(),
                        ),
                        error: (err, _) => Center(
                          child: Text(
                            'Failed to load log: $err',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _showReviewedLogFilters(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Consumer(
            builder: (context, ref, _) {
              final filters = ref.watch(reviewedLogFiltersProvider);
              final adminController = TextEditingController(text: filters.adminId ?? '');
              final userController = TextEditingController(text: filters.userId ?? '');

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.filter_list),
                      const SizedBox(width: 8),
                      const Text(
                        'Filters',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () {
                          ref.read(reviewedLogFiltersProvider.notifier).state =
                              const ReviewedLogFilters();
                          Navigator.pop(context);
                        },
                        child: const Text('Reset'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text('Status'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('All'),
                        selected: filters.status == 'all',
                        onSelected: (_) => ref
                            .read(reviewedLogFiltersProvider.notifier)
                            .state = filters.copyWith(status: 'all'),
                      ),
                      ChoiceChip(
                        label: const Text('Verified'),
                        selected: filters.status == 'verified',
                        onSelected: (_) => ref
                            .read(reviewedLogFiltersProvider.notifier)
                            .state = filters.copyWith(status: 'verified'),
                      ),
                      ChoiceChip(
                        label: const Text('Rejected'),
                        selected: filters.status == 'rejected',
                        onSelected: (_) => ref
                            .read(reviewedLogFiltersProvider.notifier)
                            .state = filters.copyWith(status: 'rejected'),
                      ),
                      ChoiceChip(
                        label: const Text('Pending'),
                        selected: filters.status == 'pending',
                        onSelected: (_) => ref
                            .read(reviewedLogFiltersProvider.notifier)
                            .state = filters.copyWith(status: 'pending'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Last 7 days only'),
                    value: filters.last7DaysOnly,
                    onChanged: (value) => ref
                        .read(reviewedLogFiltersProvider.notifier)
                        .state = filters.copyWith(last7DaysOnly: value),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: adminController,
                    decoration: const InputDecoration(
                      labelText: 'Admin ID (reviewed_by)',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) => ref
                        .read(reviewedLogFiltersProvider.notifier)
                        .state = filters.copyWith(adminId: value.trim()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: userController,
                    decoration: const InputDecoration(
                      labelText: 'User ID',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) => ref
                        .read(reviewedLogFiltersProvider.notifier)
                        .state = filters.copyWith(userId: value.trim()),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Apply'),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(adminIdentityQueueProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Identity Reviews'),
        centerTitle: true,
        actions: [
          Consumer(
            builder: (context, ref, _) {
              return IconButton(
                tooltip: 'Reviewed Log',
                icon: const Icon(Icons.history),
                onPressed: () {
                  _showReviewedLogModal(context);
                },
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Review Guidelines'),
                  content: const SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('✅ Approve if:', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text('• Document is clear and readable'),
                        Text('• Photo matches selfie'),
                        Text('• No signs of tampering'),
                        SizedBox(height: 12),
                        Text('❌ Reject if:', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text('• Document is blurry or unclear'),
                        Text('• Face doesn\'t match between ID and selfie'),
                        Text('• Document appears fake or edited'),
                        Text('• User has multiple verified accounts'),
                        SizedBox(height: 12),
                        Text('⚠️ Watch for:', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text('• Multiple recent rejections'),
                        Text('• Same documents used by different users'),
                        Text('• Suspicious resubmission patterns'),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Got it'),
                    ),
                  ],
                ),
              );
            },
            tooltip: 'Review Guidelines',
          ),
        ],
      ),
      body: data.when(
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.verified_user,
                    size: 80,
                    color: theme.colorScheme.outline,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No pending verifications',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }
          
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final item = items[index];
              
              // Get duplicate info for this verification
              final duplicateInfoAsync = ref.watch(
                verificationWithDuplicateInfoProvider(item.id)
              );
              
              return duplicateInfoAsync.when(
                data: (duplicateInfo) => _buildVerificationCard(
                  context,
                  theme,
                  item,
                  duplicateInfo,
                  ref,
                ),
                loading: () => _buildVerificationCard(
                  context,
                  theme,
                  item,
                  null,
                  ref,
                ),
                error: (_, __) => _buildVerificationCard(
                  context,
                  theme,
                  item,
                  null,
                  ref,
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Error loading verifications',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                err.toString(),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => ref.invalidate(adminIdentityQueueProvider),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVerificationCard(
    BuildContext context,
    ThemeData theme,
    IdentityVerificationEntity item,
    Map<String, dynamic>? duplicateInfo,
    WidgetRef ref,
  ) {
    final colorScheme = theme.colorScheme;
    final riskFlag = duplicateInfo?['riskFlag'] as String?;
    final warningMessage = duplicateInfo?['warningMessage'] as String?;
    final history = duplicateInfo?['history'] as List?;
    
    Color? borderColor;
    if (riskFlag == 'HIGH_RISK') {
      borderColor = Colors.red;
    } else if (riskFlag == 'DUPLICATE') {
      borderColor = Colors.orange;
    } else if (riskFlag == 'SUSPICIOUS') {
      borderColor = Colors.amber;
    }
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: borderColor ?? colorScheme.outline.withOpacity(0.2),
          width: borderColor != null ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Warning Banner (if any)
            if (warningMessage != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (riskFlag == 'HIGH_RISK' ? Colors.red : Colors.orange)
                      .withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: riskFlag == 'HIGH_RISK' ? Colors.red : Colors.orange,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning,
                      color: riskFlag == 'HIGH_RISK' ? Colors.red : Colors.orange,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        warningMessage,
                        style: TextStyle(
                          color: riskFlag == 'HIGH_RISK' ? Colors.red[700] : Colors.orange[700],
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            
            // Header with user info
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.person,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'User ID: ${item.userId.substring(0, 8)}...',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.badge,
                            size: 16,
                            color: colorScheme.secondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            item.docType,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.secondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // History button
                if (history != null && history.length > 1)
                  OutlinedButton.icon(
                    onPressed: () => _showHistoryModal(context, history),
                    icon: const Icon(Icons.history, size: 18),
                    label: Text('History (${history.length})'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                    ),
                  ),
              ],
            ),
            
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),

            // Images Section (rest remains the same as before)
            Text(
              'Submitted Documents',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ID Document',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () => _viewFullImage(
                          context,
                          item.docUrl,
                          'ID Document - ${item.docType}',
                        ),
                        child: _imagePreview(item.docUrl, colorScheme),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Selfie Photo',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () => _viewFullImage(
                          context,
                          item.selfieUrl,
                          'Selfie Photo',
                        ),
                        child: _imagePreview(item.selfieUrl, colorScheme),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _reject(context, ref, item),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.cancel, size: 20),
                    label: const Text(
                      'Reject',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _approve(context, ref, item),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.check_circle, size: 20),
                    label: const Text(
                      'Approve',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _imagePreview(String url, ColorScheme colorScheme) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 160,
            width: double.infinity,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: colorScheme.outline.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.broken_image,
                        size: 40,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Failed to load',
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                );
              },
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Center(
                  child: CircularProgressIndicator(
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                        : null,
                  ),
                );
              },
            ),
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.zoom_in,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      ],
    );
  }
}


