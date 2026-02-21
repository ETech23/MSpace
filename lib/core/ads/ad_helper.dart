// lib/core/ads/ad_helper.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AdHelper {
  static String get bannerAdUnitId {
    if (kIsWeb) {
      return '';
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'ca-app-pub-3940256099942544/6300978111';
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return 'ca-app-pub-3940256099942544/2934735716';
    }
    return '';
  }

  static String get nativeAdUnitId {
    if (kIsWeb) {
      return '';
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'ca-app-pub-3940256099942544/2247696110';
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return 'ca-app-pub-3940256099942544/3986624511';
    }
    return '';
  }
}
