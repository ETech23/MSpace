// lib/features/trust/presentation/screens/admin_reports_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/trust_provider.dart';
import '../../domain/entities/report_entity.dart';

class AdminReportsScreen extends ConsumerWidget {
  const AdminReportsScreen({super.key});

  Future<void> _actioned(
    BuildContext context,
    WidgetRef ref,
    ReportEntity report,
  ) async {
    final note = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Action Taken'),
          content: TextField(
            controller: controller,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Action',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (note == null || note.isEmpty) return;

    final repo = ref.read(trustRepositoryProvider);
    await repo.adminUpdateReport(
      reportId: report.id,
      status: 'actioned',
      actionTaken: note,
    );
    ref.invalidate(adminReportsProvider);
  }

  Future<void> _dismiss(
    WidgetRef ref,
    ReportEntity report,
  ) async {
    final repo = ref.read(trustRepositoryProvider);
    await repo.adminUpdateReport(
      reportId: report.id,
      status: 'dismissed',
    );
    ref.invalidate(adminReportsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(adminReportsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        centerTitle: true,
      ),
      body: data.when(
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('No reports.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final report = items[index];
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Target: ${report.targetType} ${report.targetId}'),
                      const SizedBox(height: 6),
                      Text('Reason: ${report.reason}'),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _dismiss(ref, report),
                              child: const Text('Dismiss'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              onPressed: () => _actioned(context, ref, report),
                              child: const Text('Actioned'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }
}
