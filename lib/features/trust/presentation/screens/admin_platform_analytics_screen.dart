import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/trust_provider.dart';

class AdminPlatformAnalyticsScreen extends ConsumerWidget {
  const AdminPlatformAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analyticsAsync = ref.watch(platformAnalyticsProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Platform Analytics'),
      ),
      body: analyticsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (stats) {
          final artisanCoverage = stats.totalUsers == 0
              ? 0
              : ((stats.totalArtisans / stats.totalUsers) * 100).round();
          final verificationCoverage = stats.totalUsers == 0
              ? 0
              : ((stats.verifiedUsers / stats.totalUsers) * 100).round();

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(platformAnalyticsProvider),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0D47A1), Color(0xFF1565C0)],
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Live platform pulse',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Use this dashboard to monitor supply, trust, and operations health across the marketplace.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withOpacity(0.92),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: _HeroBadge(
                              label: 'Artisan Coverage',
                              value: '$artisanCoverage%',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _HeroBadge(
                              label: 'Verified Users',
                              value: '$verificationCoverage%',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 1.18,
                  children: [
                    _MetricCard(
                      icon: Icons.group_rounded,
                      label: 'Total Users',
                      value: stats.totalUsers.toString(),
                      color: const Color(0xFF1565C0),
                    ),
                    _MetricCard(
                      icon: Icons.handyman_rounded,
                      label: 'Total Artisans',
                      value: stats.totalArtisans.toString(),
                      color: const Color(0xFF3949AB),
                    ),
                    _MetricCard(
                      icon: Icons.verified_user_rounded,
                      label: 'Verified Users',
                      value: stats.verifiedUsers.toString(),
                      color: const Color(0xFF2E7D32),
                    ),
                    _MetricCard(
                      icon: Icons.calendar_today_rounded,
                      label: 'Bookings Today',
                      value: stats.bookingsToday.toString(),
                      color: const Color(0xFF00897B),
                    ),
                    _MetricCard(
                      icon: Icons.gavel_rounded,
                      label: 'Open Disputes',
                      value: stats.openDisputes.toString(),
                      color: const Color(0xFFF57C00),
                    ),
                    _MetricCard(
                      icon: Icons.flag_rounded,
                      label: 'Pending Reports',
                      value: stats.pendingReports.toString(),
                      color: const Color(0xFFC62828),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _InsightPanel(
                  title: 'Trust & safety',
                  color: const Color(0xFF2E7D32),
                  body:
                      'Verified users: ${stats.verifiedUsers}. Open disputes: ${stats.openDisputes}. Pending reports: ${stats.pendingReports}. This is your fastest read on marketplace confidence and moderation workload.',
                ),
                const SizedBox(height: 12),
                _InsightPanel(
                  title: 'Operations',
                  color: const Color(0xFF1565C0),
                  body:
                      'Total users: ${stats.totalUsers}. Artisans: ${stats.totalArtisans}. Bookings created today: ${stats.bookingsToday}. Watch this mix to see whether supply is keeping up with client demand.',
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withOpacity(0.45),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Admin notes',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'If disputes or reports spike while bookings today stay flat, it usually points to provider quality or communication friction. If bookings rise but artisan coverage drops, supply acquisition needs attention.',
                        style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _HeroBadge extends StatelessWidget {
  const _HeroBadge({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white.withOpacity(0.86),
                ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color),
          ),
          const Spacer(),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _InsightPanel extends StatelessWidget {
  const _InsightPanel({
    required this.title,
    required this.color,
    required this.body,
  });

  final String title;
  final Color color;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.18)),
        color: color.withOpacity(0.06),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          Text(body, style: theme.textTheme.bodyMedium?.copyWith(height: 1.45)),
        ],
      ),
    );
  }
}
