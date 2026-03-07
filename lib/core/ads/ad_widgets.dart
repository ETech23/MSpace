// lib/core/ads/ad_widgets.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'ad_helper.dart';
import 'ad_remote_config_service.dart';
import 'ad_runtime_config.dart';

class BannerAdWidget extends StatefulWidget {
  final EdgeInsetsGeometry padding;

  BannerAdWidget({
    super.key,
    this.padding = const EdgeInsets.fromLTRB(0, 8, 0, 4),
  });

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;
  String _currentAdUnitId = '';

  static const double _adWidth = 360;
  static const double _adHeight = 90;

  @override
  void initState() {
    super.initState();
    AdRemoteConfigService.instance.configListenable
        .addListener(_onRemoteConfigChanged);
    _reloadBanner();
  }

  bool get _shouldLoadAds =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  void dispose() {
    AdRemoteConfigService.instance.configListenable
        .removeListener(_onRemoteConfigChanged);
    _bannerAd?.dispose();
    super.dispose();
  }

  void _onRemoteConfigChanged() {
    if (!mounted) return;
    _reloadBanner();
  }

  void _reloadBanner() {
    final config = AdRemoteConfigService.instance.currentConfig;
    final nextUnitId = _resolveBannerAdUnitId(config);

    if (!_shouldLoadAds || nextUnitId.isEmpty) {
      _currentAdUnitId = '';
      _bannerAd?.dispose();
      _bannerAd = null;
      if (_isLoaded) {
        setState(() => _isLoaded = false);
      }
      return;
    }

    if (_currentAdUnitId == nextUnitId && _bannerAd != null) {
      return;
    }

    _currentAdUnitId = nextUnitId;
    _bannerAd?.dispose();
    _bannerAd = BannerAd(
      size: const AdSize(
        width: _adWidth ~/ 1,
        height: _adHeight ~/ 1,
      ),
      adUnitId: nextUnitId,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (!mounted) return;
          setState(() => _isLoaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          debugPrint('Banner ad failed: ${error.code} ${error.message}');
          if (!mounted) return;
          setState(() => _isLoaded = false);
        },
      ),
    )..load();

    if (_isLoaded) {
      setState(() => _isLoaded = false);
    }
  }

  String _resolveBannerAdUnitId(AdRuntimeConfig config) {
    final remoteOrFallback = config.bannerAdUnitIdForCurrentPlatform();
    if (remoteOrFallback.isNotEmpty) {
      return remoteOrFallback;
    }
    return AdHelper.bannerAdUnitId;
  }

  @override
  Widget build(BuildContext context) {
    if (!_shouldLoadAds || !_isLoaded || _bannerAd == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: widget.padding,
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: _adWidth,
            height: _adHeight,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Theme.of(context)
                    .colorScheme
                    .outlineVariant
                    .withValues(alpha: 0.5),
                width: 1,
              ),
            ),
            child: AdWidget(ad: _bannerAd!),
          ),
        ),
      ),
    );
  }
}

class NativeAdWidget extends StatefulWidget {
  final EdgeInsetsGeometry padding;
  final double height;

  const NativeAdWidget({
    super.key,
    this.padding = const EdgeInsets.symmetric(vertical: 8),
    this.height = 260,
  });

  @override
  State<NativeAdWidget> createState() => _NativeAdWidgetState();
}

class _NativeAdWidgetState extends State<NativeAdWidget> {
  NativeAd? _nativeAd;
  bool _isLoaded = false;
  String _currentAdUnitId = '';

  @override
  void initState() {
    super.initState();
    AdRemoteConfigService.instance.configListenable
        .addListener(_onRemoteConfigChanged);
    _reloadNative();
  }

  bool get _shouldLoadNative =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  void dispose() {
    AdRemoteConfigService.instance.configListenable
        .removeListener(_onRemoteConfigChanged);
    _nativeAd?.dispose();
    super.dispose();
  }

  void _onRemoteConfigChanged() {
    if (!mounted) return;
    _reloadNative();
  }

  void _reloadNative() {
    final config = AdRemoteConfigService.instance.currentConfig;
    final nextUnitId = _resolveNativeAdUnitId(config);

    if (!_shouldLoadNative || nextUnitId.isEmpty) {
      _currentAdUnitId = '';
      _nativeAd?.dispose();
      _nativeAd = null;
      if (_isLoaded) {
        setState(() => _isLoaded = false);
      }
      return;
    }

    if (_currentAdUnitId == nextUnitId && _nativeAd != null) {
      return;
    }

    _currentAdUnitId = nextUnitId;
    _nativeAd?.dispose();
    _nativeAd = NativeAd(
      adUnitId: nextUnitId,
      factoryId: 'listTile',
      request: const AdRequest(),
      listener: NativeAdListener(
        onAdLoaded: (_) {
          if (!mounted) return;
          setState(() => _isLoaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          debugPrint('Native ad failed: ${error.code} ${error.message}');
          if (!mounted) return;
          setState(() => _isLoaded = false);
        },
      ),
    )..load();

    if (_isLoaded) {
      setState(() => _isLoaded = false);
    }
  }

  String _resolveNativeAdUnitId(AdRuntimeConfig config) {
    final remoteOrFallback = config.nativeAdUnitIdForCurrentPlatform();
    if (remoteOrFallback.isNotEmpty) {
      return remoteOrFallback;
    }
    return AdHelper.nativeAdUnitId;
  }

  @override
  Widget build(BuildContext context) {
    if (_shouldLoadNative && _isLoaded && _nativeAd != null) {
      return Padding(
        padding: widget.padding,
        child: SizedBox(
          height: widget.height,
          width: double.infinity,
          child: AdWidget(ad: _nativeAd!),
        ),
      );
    }

    // Fallback to banner on non-Android or if native isn't ready.
    return BannerAdWidget();
  }
}
