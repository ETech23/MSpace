import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/trust_provider.dart';

class BlockedUsersScreen extends ConsumerWidget {
  const BlockedUsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(authProvider).user;
    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text('Please sign in to manage blocked users.')),
      );
    }

    final blockedAsync = ref.watch(blockedUsersProvider(currentUser.id));
    final blockActionState = ref.watch(blockActionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Blocked Users'),
      ),
      body: blockedAsync.when(
        data: (items) {
          if (items.isEmpty) {
            return const Center(
              child: Text('No blocked users.'),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = items[index];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundImage: (item.photoUrl != null &&
                            item.photoUrl!.isNotEmpty)
                        ? NetworkImage(item.photoUrl!)
                        : null,
                    child: (item.photoUrl == null || item.photoUrl!.isEmpty)
                        ? const Icon(Icons.person_outline)
                        : null,
                  ),
                  title: Text(item.name ?? 'User'),
                  subtitle: Text(
                    item.reason?.isNotEmpty == true
                        ? 'Reason: ${item.reason}'
                        : 'Blocked',
                  ),
                  trailing: TextButton(
                    onPressed: blockActionState.isLoading
                        ? null
                        : () async {
                            final ok = await ref
                                .read(blockActionProvider.notifier)
                                .unblockUser(
                                  blockerId: currentUser.id,
                                  blockedUserId: item.blockedUserId,
                                );
                            if (!context.mounted) return;
                            if (ok) {
                              ref.invalidate(blockedUsersProvider(currentUser.id));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('User unblocked'),
                                ),
                              );
                            }
                          },
                    child: const Text('Unblock'),
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Failed to load blocked users: $error'),
          ),
        ),
      ),
    );
  }
}
