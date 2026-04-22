import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/services/referral_service.dart';

class ReferralLeaderboardScreen extends ConsumerStatefulWidget {
  const ReferralLeaderboardScreen({super.key});

  @override
  ConsumerState<ReferralLeaderboardScreen> createState() =>
      _ReferralLeaderboardScreenState();
}

class _ReferralLeaderboardScreenState
    extends ConsumerState<ReferralLeaderboardScreen> {
  late final ReferralService _referralService;

  @override
  void initState() {
    super.initState();
    _referralService = ReferralService(Supabase.instance.client);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Referral Leaderboard')),
      body: FutureBuilder<List<ReferralLeaderboardEntry>>(
        future: _referralService.fetchLeaderboard(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final entries = snapshot.data ?? [];
          if (entries.isEmpty) {
            return const Center(child: Text('No referrals yet.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: entries.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final entry = entries[index];
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundImage: entry.photoUrl != null
                          ? NetworkImage(entry.photoUrl!)
                          : null,
                      child: entry.photoUrl == null
                          ? Text(entry.name.isNotEmpty ? entry.name[0] : '?')
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(entry.name,
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                          Text('Rank #${index + 1}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: Colors.grey)),
                        ],
                      ),
                    ),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${entry.totalReferrals}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
