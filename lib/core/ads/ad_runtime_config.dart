import 'package:flutter/foundation.dart';

import 'ad_helper.dart';

class AdRuntimeConfig {
  final bool enabled;
  final String? bannerAndroid;
  final String? bannerIos;
  final String? nativeAndroid;
  final String? nativeIos;
  final DateTime fetchedAt;

  const AdRuntimeConfig({
    required this.enabled,
    required this.fetchedAt,
    this.bannerAndroid,
    this.bannerIos,
    this.nativeAndroid,
    this.nativeIos,
  });

  factory AdRuntimeConfig.defaults() {
    return AdRuntimeConfig(
      enabled: true,
      fetchedAt: DateTime.now(),
    );
  }

  AdRuntimeConfig copyWith({
    bool? enabled,
    String? bannerAndroid,
    String? bannerIos,
    String? nativeAndroid,
    String? nativeIos,
    DateTime? fetchedAt,
  }) {
    return AdRuntimeConfig(
      enabled: enabled ?? this.enabled,
      bannerAndroid: bannerAndroid ?? this.bannerAndroid,
      bannerIos: bannerIos ?? this.bannerIos,
      nativeAndroid: nativeAndroid ?? this.nativeAndroid,
      nativeIos: nativeIos ?? this.nativeIos,
      fetchedAt: fetchedAt ?? this.fetchedAt,
    );
  }

  String bannerAdUnitIdForCurrentPlatform() {
    if (kIsWeb) return '';
    if (!enabled) return '';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return _sanitizeId(bannerAndroid) ?? AdHelper.bannerAdUnitId;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return _sanitizeId(bannerIos) ?? AdHelper.bannerAdUnitId;
    }
    return '';
  }

  String nativeAdUnitIdForCurrentPlatform() {
    if (kIsWeb) return '';
    if (!enabled) return '';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return _sanitizeId(nativeAndroid) ?? AdHelper.nativeAdUnitId;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return _sanitizeId(nativeIos) ?? AdHelper.nativeAdUnitId;
    }
    return '';
  }

  static String? _sanitizeId(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
