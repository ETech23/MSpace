package com.mspace.app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin
import com.android.installreferrer.api.InstallReferrerClient
import com.android.installreferrer.api.InstallReferrerStateListener
import com.android.installreferrer.api.InstallReferrerClient.InstallReferrerResponse

class MainActivity : FlutterActivity() {
  private var nativeAdFactory: NativeAdFactory? = null
  private val referrerChannel = "mspace/install_referrer"

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    nativeAdFactory = NativeAdFactory(layoutInflater)
    GoogleMobileAdsPlugin.registerNativeAdFactory(
      flutterEngine,
      "listTile",
      nativeAdFactory!!
    )
    setUpInstallReferrerChannel(flutterEngine)
  }

  override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
    GoogleMobileAdsPlugin.unregisterNativeAdFactory(flutterEngine, "listTile")
    nativeAdFactory = null
    super.cleanUpFlutterEngine(flutterEngine)
  }

  private fun setUpInstallReferrerChannel(flutterEngine: FlutterEngine) {
    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, referrerChannel)
      .setMethodCallHandler { call, result ->
        if (call.method != "getInstallReferrer") {
          result.notImplemented()
          return@setMethodCallHandler
        }

        val referrerClient = InstallReferrerClient.newBuilder(this).build()
        referrerClient.startConnection(object : InstallReferrerStateListener {
          override fun onInstallReferrerSetupFinished(responseCode: Int) {
            when (responseCode) {
              InstallReferrerResponse.OK -> {
                try {
                  val response = referrerClient.installReferrer
                  result.success(response.installReferrer)
                } catch (e: Exception) {
                  result.error("referrer_error", e.message, null)
                } finally {
                  referrerClient.endConnection()
                }
              }
              else -> {
                result.success(null)
                referrerClient.endConnection()
              }
            }
          }

          override fun onInstallReferrerServiceDisconnected() {
            // No-op; the next call will re-connect.
          }
        })
      }
  }
}

