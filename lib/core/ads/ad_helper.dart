// lib/core/ads/ad_helper.dart
import 'package:flutter/foundation.dart';

class AdHelper {
  static const String _bannerAndroidProd = String.fromEnvironment(
    'ADMOB_BANNER_ANDROID',
    defaultValue: '',
  );
  static const String _bannerIosProd = String.fromEnvironment(
    'ADMOB_BANNER_IOS',
    defaultValue: '',
  );
  static const String _nativeAndroidProd = String.fromEnvironment(
    'ADMOB_NATIVE_ANDROID',
    defaultValue: '',
  );
  static const String _nativeIosProd = String.fromEnvironment(
    'ADMOB_NATIVE_IOS',
    defaultValue: '',
  );

  static const String _testBannerAndroid = 'ca-app-pub-3940256099942544/6300978111';
  static const String _testBannerIos = 'ca-app-pub-3940256099942544/2934735716';
  static const String _testNativeAndroid = 'ca-app-pub-3940256099942544/2247696110';
  static const String _testNativeIos = 'ca-app-pub-3940256099942544/3986624511';

  static String get bannerAdUnitId {
    if (kIsWeb) {
      return '';
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return kReleaseMode ? _bannerAndroidProd : _testBannerAndroid;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return kReleaseMode ? _bannerIosProd : _testBannerIos;
    }
    return '';
  }

  static String get nativeAdUnitId {
    if (kIsWeb) {
      return '';
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return kReleaseMode ? _nativeAndroidProd : _testNativeAndroid;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return kReleaseMode ? _nativeIosProd : _testNativeIos;
    }
    return '';
  }
}
