package com.example.artisan_marketplace_new

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin

class MainActivity : FlutterActivity() {
  private var nativeAdFactory: NativeAdFactory? = null

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    nativeAdFactory = NativeAdFactory(layoutInflater)
    GoogleMobileAdsPlugin.registerNativeAdFactory(
      flutterEngine,
      "listTile",
      nativeAdFactory!!
    )
  }

  override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
    GoogleMobileAdsPlugin.unregisterNativeAdFactory(flutterEngine, "listTile")
    nativeAdFactory = null
    super.cleanUpFlutterEngine(flutterEngine)
  }
}
