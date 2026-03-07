import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'feature_flags.dart';

class FeatureFlagsService {
  FeatureFlagsService._();

  static final FeatureFlagsService instance = FeatureFlagsService._();

  final ValueNotifier<FeatureFlags> _flags =
      ValueNotifier<FeatureFlags>(FeatureFlags.defaults());

  ValueListenable<FeatureFlags> get flagsListenable => _flags;
  FeatureFlags get currentFlags => _flags.value;

  Timer? _pollTimer;
  RealtimeChannel? _realtimeChannel;
  bool _initialized = false;
  bool _isRefreshing = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    await refresh();
    _subscribeRealtime();
    _pollTimer = Timer.periodic(const Duration(minutes: 2), (_) => refresh());
  }

  Future<void> refresh() async {
    if (_isRefreshing) return;
    _isRefreshing = true;
    try {
      final next = await _loadFlags();
      if (next != null) {
        _flags.value = next;
      }
    } catch (e) {
      debugPrint('Feature flags refresh failed: $e');
    } finally {
      _isRefreshing = false;
    }
  }

  Future<void> dispose() async {
    _pollTimer?.cancel();
    _pollTimer = null;
    _realtimeChannel?.unsubscribe();
    _realtimeChannel = null;
    _initialized = false;
  }

  Future<FeatureFlags?> _loadFlags() async {
    final client = Supabase.instance.client;

    try {
      final row = await client
          .from('app_feature_flags')
          .select(
            'maintenance_mode, disable_post_job, disable_bookings, disable_chat, maintenance_message',
          )
          .eq('config_key', 'global')
          .maybeSingle();
      if (row != null) {
        return FeatureFlags.fromJson(row);
      }
    } catch (e) {
      debugPrint('app_feature_flags lookup failed: $e');
    }

    try {
      final kvRow = await client
          .from('app_settings')
          .select('value')
          .eq('key', 'feature_flags')
          .maybeSingle();
      if (kvRow != null) {
        final value = kvRow['value'];
        if (value is Map<String, dynamic>) {
          return FeatureFlags.fromJson(value);
        }
      }
    } catch (e) {
      debugPrint('app_settings feature_flags lookup failed: $e');
    }

    return null;
  }

  void _subscribeRealtime() {
    final client = Supabase.instance.client;
    _realtimeChannel?.unsubscribe();
    _realtimeChannel = client
        .channel('app_feature_flags:global')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'app_feature_flags',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'config_key',
            value: 'global',
          ),
          callback: (_) => unawaited(refresh()),
        )
        .subscribe();
  }
}
