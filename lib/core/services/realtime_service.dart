// ================================================================
// SUPABASE REALTIME SETUP
// lib/core/services/realtime_service.dart
// ================================================================

import 'package:dartz/dartz.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RealtimeService {
  final SupabaseClient _client;
  
  // Channel references
  RealtimeChannel? _jobChannel;
  RealtimeChannel? _matchChannel;
  RealtimeChannel? _feedChannel;

  RealtimeService(this._client);

  // ================================================================
  // 1. ARTISAN: Listen for job matches
  // ================================================================
  SupabaseStreamBuilder listenToJobMatches(String artisanId) {
    _matchChannel = _client
        .channel('job_matches:$artisanId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'job_matches',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'artisan_id',
            value: artisanId,
          ),
          callback: (payload) {
            print('🔔 New job match: ${payload.newRecord}');
          },
        )
        .subscribe();

    return _client
        .from('job_matches')
        .stream(primaryKey: ['id'])
        .eq('artisan_id', artisanId)
        .order('created_at', ascending: false);
  }

  // ================================================================
  // 2. CUSTOMER: Listen for job status changes
  // ================================================================
  SupabaseStreamBuilder listenToJobUpdates(String jobId) {
    _jobChannel = _client
        .channel('job:$jobId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'jobs',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: jobId,
          ),
          callback: (payload) {
            print('📊 Job updated: ${payload.newRecord}');
          },
        )
        .subscribe();

    return _client
        .from('jobs')
        .stream(primaryKey: ['id'])
        .eq('id', jobId);
  }

  // ================================================================
  // 3. CUSTOMER: Listen for all own jobs
  // ================================================================
  Stream<List<Map<String, dynamic>>> listenToCustomerJobs(String customerId) {
    return _client
        .from('jobs')
        .stream(primaryKey: ['id'])
        .eq('customer_id', customerId)
        .order('created_at', ascending: false);
  }

  // ================================================================
  // 4. FEED: Listen for new feed items
  // ================================================================
  Stream<List<Map<String, dynamic>>> listenToFeedUpdates({
    String? category,
    String? itemType,
  }) {
    final stream = _client
        .from('feed_items')
        .stream(primaryKey: ['id'])
        .order('priority', ascending: false)
        .order('published_at', ascending: false)
        .limit(50);

    return stream.map((rows) {
      return rows.where((row) {
        if (row['is_active'] != true) return false;
        if (category != null && row['category'] != category) return false;
        if (itemType != null && row['item_type'] != itemType) return false;
        return true;
      }).toList(growable: false);
    });
  }

  // ================================================================
  // 5. PRESENCE: Track online artisans (future feature)
  // ================================================================
  void trackArtisanPresence(String artisanId) {
    _client
        .channel('presence:artisans')
        .onPresenceSync((state) {
          print('🟢 Online artisans presence sync');
        })
        .subscribe((status, error) async {
          if (status == RealtimeSubscribeStatus.subscribed) {
            await _client.channel('presence:artisans').track({
              'artisan_id': artisanId,
              'online_at': DateTime.now().toIso8601String(),
            });
          }
        });
  }

  // ================================================================
  // Cleanup
  // ================================================================
  void dispose() {
    _jobChannel?.unsubscribe();
    _matchChannel?.unsubscribe();
    _feedChannel?.unsubscribe();
  }
}
