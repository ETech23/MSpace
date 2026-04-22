import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'ad_runtime_config.dart';

class AdRemoteConfigService {
  AdRemoteConfigService._();

  static final AdRemoteConfigService instance = AdRemoteConfigService._();

  final ValueNotifier<AdRuntimeConfig> _config =
      ValueNotifier<AdRuntimeConfig>(AdRuntimeConfig.defaults());

  ValueListenable<AdRuntimeConfig> get configListenable => _config;
  AdRuntimeConfig get currentConfig => _config.value;

  Timer? _pollTimer;
  RealtimeChannel? _realtimeChannel;
  bool _initialized = false;
  bool _isRefreshing = false;
  bool? _isDevPackage;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    await refresh();
    _subscribeRealtime();
    _pollTimer = Timer.periodic(
      const Duration(minutes: 2),
      (_) => refresh(),
    );
  }

  Future<void> dispose() async {
    _pollTimer?.cancel();
    _pollTimer = null;
    _realtimeChannel?.unsubscribe();
    _realtimeChannel = null;
    _initialized = false;
  }

  Future<void> refresh() async {
    if (_isRefreshing) return;
    _isRefreshing = true;
    try {
      final isDev = await _isDevApp();
      if (isDev) {
        // Force test ads on dev package, regardless of remote config.
        _config.value = AdRuntimeConfig(
          enabled: true,
          fetchedAt: DateTime.now(),
        );
        return;
      }
      final config = await _loadConfigFromSupabase();
      if (config != null) {
        _config.value = config;
      }
    } catch (e) {
      debugPrint('Ads remote config refresh failed: $e');
    } finally {
      _isRefreshing = false;
    }
  }

  Future<AdRuntimeConfig?> _loadConfigFromSupabase() async {
    final client = Supabase.instance.client;

    try {
      final directRow = await client
          .from('app_runtime_config')
          .select(
            'ads_enabled, banner_android, banner_ios, native_android, native_ios',
          )
          .eq('config_key', 'ads')
          .maybeSingle();

      if (directRow != null) {
        return _parseDirectRow(directRow);
      }
    } catch (e) {
      debugPrint('app_runtime_config lookup failed: $e');
    }

    try {
      final kvRow = await client
          .from('app_settings')
          .select('value')
          .eq('key', 'ads')
          .maybeSingle();

      if (kvRow != null) {
        return _parseKvRow(kvRow);
      }
    } catch (e) {
      debugPrint('app_settings lookup failed: $e');
    }

    return null;
  }

  void _subscribeRealtime() {
    final client = Supabase.instance.client;
    _realtimeChannel?.unsubscribe();
    _realtimeChannel = client
        .channel('app_runtime_config:ads')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'app_runtime_config',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'config_key',
            value: 'ads',
          ),
          callback: (_) {
            unawaited(refresh());
          },
        )
        .subscribe();
  }

  AdRuntimeConfig _parseDirectRow(Map<String, dynamic> row) {
    return AdRuntimeConfig(
      enabled: row['ads_enabled'] as bool? ?? true,
      bannerAndroid: row['banner_android'] as String?,
      bannerIos: row['banner_ios'] as String?,
      nativeAndroid: row['native_android'] as String?,
      nativeIos: row['native_ios'] as String?,
      fetchedAt: DateTime.now(),
    );
  }

  AdRuntimeConfig? _parseKvRow(Map<String, dynamic> row) {
    final value = row['value'];
    if (value is! Map<String, dynamic>) return null;

    return AdRuntimeConfig(
      enabled: value['enabled'] as bool? ?? true,
      bannerAndroid: value['banner_android'] as String?,
      bannerIos: value['banner_ios'] as String?,
      nativeAndroid: value['native_android'] as String?,
      nativeIos: value['native_ios'] as String?,
      fetchedAt: DateTime.now(),
    );
  }

  Future<bool> _isDevApp() async {
    if (_isDevPackage != null) return _isDevPackage!;
    try {
      final info = await PackageInfo.fromPlatform();
      final name = info.packageName.toLowerCase();
      _isDevPackage = name.endsWith('.dev');
    } catch (_) {
      _isDevPackage = false;
    }
    return _isDevPackage!;
  }
}
