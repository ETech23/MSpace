import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/trust_provider.dart';

class AdminPlatformAnalyticsScreen extends ConsumerWidget {
  const AdminPlatformAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analyticsAsync = ref.watch(platformAnalyticsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Platform Analytics'),
      ),
      body: analyticsAsync.when(
        data: (stats) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _MetricCard(
                icon: Icons.group,
                label: 'Total Users',
                value: stats.totalUsers.toString(),
                color: Colors.blue,
              ),
              _MetricCard(
                icon: Icons.handyman,
                label: 'Total Artisans',
                value: stats.totalArtisans.toString(),
                color: Colors.indigo,
              ),
              _MetricCard(
                icon: Icons.verified_user,
                label: 'Verified Users',
                value: stats.verifiedUsers.toString(),
                color: Colors.green,
              ),
              _MetricCard(
                icon: Icons.warning_amber,
                label: 'Open Disputes',
                value: stats.openDisputes.toString(),
                color: Colors.orange,
              ),
              _MetricCard(
                icon: Icons.flag,
                label: 'Pending Reports',
                value: stats.pendingReports.toString(),
                color: Colors.red,
              ),
              _MetricCard(
                icon: Icons.calendar_today,
                label: 'Bookings Today',
                value: stats.bookingsToday.toString(),
                color: Colors.teal,
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.12),
          child: Icon(icon, color: color),
        ),
        title: Text(label),
        trailing: Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
      ),
    );
  }
}
