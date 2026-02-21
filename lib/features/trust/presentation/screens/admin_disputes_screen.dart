// lib/features/trust/presentation/screens/admin_disputes_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/trust_provider.dart';
import '../../domain/entities/dispute_entity.dart';

class AdminDisputesScreen extends ConsumerWidget {
  const AdminDisputesScreen({super.key});

  Future<void> _resolve(
    WidgetRef ref,
    DisputeEntity dispute,
    String status,
  ) async {
    final repo = ref.read(trustRepositoryProvider);
    await repo.adminResolveDispute(
      disputeId: dispute.id,
      status: status,
    );
    ref.invalidate(adminDisputesProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(adminDisputesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Disputes'),
        centerTitle: true,
      ),
      body: data.when(
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('No open disputes.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final dispute = items[index];
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Booking: ${dispute.bookingId}'),
                      const SizedBox(height: 6),
                      Text('Opened by: ${dispute.openedBy}'),
                      const SizedBox(height: 6),
                      Text('Reason: ${dispute.reason}'),
                      const SizedBox(height: 10),
                      if (dispute.evidenceUrls.isNotEmpty)
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: dispute.evidenceUrls.map((url) {
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                url,
                                width: 90,
                                height: 90,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    width: 90,
                                    height: 90,
                                    color: Colors.grey.shade200,
                                    child: const Icon(Icons.broken_image),
                                  );
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _resolve(
                                ref,
                                dispute,
                                'resolved_refund',
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                side: const BorderSide(color: Colors.red),
                              ),
                              child: const Text('Refund'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              onPressed: () => _resolve(
                                ref,
                                dispute,
                                'resolved_release',
                              ),
                              child: const Text('Release'),
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
