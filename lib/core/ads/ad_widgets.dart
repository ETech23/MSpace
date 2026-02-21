// lib/core/ads/ad_widgets.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'ad_helper.dart';

class BannerAdWidget extends StatefulWidget {
  final EdgeInsetsGeometry padding;

  const BannerAdWidget({
    super.key,
    this.padding = const EdgeInsets.symmetric(vertical: 8),
  });

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    if (_shouldLoadAds) {
      _bannerAd = BannerAd(
        size: AdSize.banner,
        adUnitId: AdHelper.bannerAdUnitId,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (_) => setState(() => _isLoaded = true),
          onAdFailedToLoad: (ad, _) {
            ad.dispose();
            setState(() => _isLoaded = false);
          },
        ),
      )..load();
    }
  }

  bool get _shouldLoadAds =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_shouldLoadAds || !_isLoaded || _bannerAd == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: widget.padding,
      child: SizedBox(
        width: _bannerAd!.size.width.toDouble(),
        height: _bannerAd!.size.height.toDouble(),
        child: AdWidget(ad: _bannerAd!),
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

  @override
  void initState() {
    super.initState();
    if (_shouldLoadNative) {
      _nativeAd = NativeAd(
        adUnitId: AdHelper.nativeAdUnitId,
        factoryId: 'listTile',
        request: const AdRequest(),
        listener: NativeAdListener(
          onAdLoaded: (_) => setState(() => _isLoaded = true),
          onAdFailedToLoad: (ad, _) {
            ad.dispose();
            setState(() => _isLoaded = false);
          },
        ),
      )..load();
    }
  }

  bool get _shouldLoadNative =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  void dispose() {
    _nativeAd?.dispose();
    super.dispose();
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
    return const BannerAdWidget();
  }
}
