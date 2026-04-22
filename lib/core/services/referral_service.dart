import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class ReferralLeaderboardEntry {
  final String referrerId;
  final String name;
  final String? photoUrl;
  final int totalReferrals;

  const ReferralLeaderboardEntry({
    required this.referrerId,
    required this.name,
    required this.totalReferrals,
    this.photoUrl,
  });
}

class ReferralService {
  ReferralService(this._client);

  final SupabaseClient _client;

  static const _codeLength = 8;

  String _generateCode() {
    final raw = const Uuid().v4().replaceAll('-', '').toUpperCase();
    return raw.substring(0, _codeLength);
  }

  String buildPlayStoreShareLink({
    required String packageName,
    required String code,
  }) {
    final ref = Uri.encodeComponent('ref=$code');
    return 'https://play.google.com/store/apps/details?id=$packageName&referrer=$ref';
  }

  String buildAppReferralLink({
    required String code,
    String baseUrl = 'https://mspace.app',
  }) {
    final trimmedBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    return '$trimmedBase/r/$code';
  }

  Future<String> ensureReferralCode(String userId) async {
    final existing = await _client
        .from('referral_codes')
        .select('code')
        .eq('user_id', userId)
        .maybeSingle();

    if (existing != null && existing['code'] != null) {
      return existing['code'] as String;
    }

    for (var attempt = 0; attempt < 5; attempt++) {
      final code = _generateCode();
      try {
        await _client.from('referral_codes').insert({
          'user_id': userId,
          'code': code,
        });
        return code;
      } catch (_) {
        // Try a new code on conflict
      }
    }

    // Fallback: last attempt using upsert with user_id
    final fallback = _generateCode();
    await _client.from('referral_codes').upsert({
      'user_id': userId,
      'code': fallback,
    });
    return fallback;
  }

  Future<String?> resolveReferrerId(String code) async {
    final row = await _client
        .from('referral_codes')
        .select('user_id')
        .eq('code', code)
        .maybeSingle();
    return row?['user_id'] as String?;
  }

  Future<void> recordAttribution({
    required String referrerId,
    required String referredUserId,
    String? source,
  }) async {
    await _client.from('referral_attributions').insert({
      'referrer_id': referrerId,
      'referred_user_id': referredUserId,
      'source': source,
    });
  }

  Future<List<ReferralLeaderboardEntry>> fetchLeaderboard() async {
    final rows = await _client
        .from('referral_leaderboard')
        .select('referrer_id,total_referrals')
        .limit(100);

    final leaderboardRows = (rows as List)
        .map((row) => row as Map<String, dynamic>)
        .toList(growable: false);

    final ids = leaderboardRows
        .map((row) => row['referrer_id'] as String)
        .toList(growable: false);

    if (ids.isEmpty) return const [];

    final users = await _client
        .from('users')
        .select('id,name,photo_url')
        .inFilter('id', ids);

    final userMap = <String, Map<String, dynamic>>{};
    for (final row in (users as List)) {
      final map = row as Map<String, dynamic>;
      userMap[map['id'] as String] = map;
    }

    return leaderboardRows.map((row) {
      final id = row['referrer_id'] as String;
      final user = userMap[id];
      return ReferralLeaderboardEntry(
        referrerId: id,
        name: (user?['name'] as String?) ?? 'User',
        photoUrl: user?['photo_url'] as String?,
        totalReferrals: (row['total_referrals'] as int?) ?? 0,
      );
    }).toList(growable: false);
  }
}
