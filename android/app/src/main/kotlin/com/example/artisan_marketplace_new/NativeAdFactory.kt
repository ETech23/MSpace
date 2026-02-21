package com.example.artisan_marketplace_new

import android.view.LayoutInflater
import android.widget.Button
import android.widget.ImageView
import android.widget.TextView
import com.google.android.gms.ads.nativead.NativeAd
import com.google.android.gms.ads.nativead.NativeAdView
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin.NativeAdFactory

class NativeAdFactory(private val layoutInflater: LayoutInflater) : NativeAdFactory {
  override fun createNativeAd(
    nativeAd: NativeAd,
    customOptions: MutableMap<String, Any>?
  ): NativeAdView {
    val adView =
      layoutInflater.inflate(R.layout.native_ad, null) as NativeAdView

    adView.mediaView = adView.findViewById(R.id.ad_media)
    adView.headlineView = adView.findViewById(R.id.ad_headline)
    adView.bodyView = adView.findViewById(R.id.ad_body)
    adView.callToActionView = adView.findViewById(R.id.ad_call_to_action)
    adView.iconView = adView.findViewById(R.id.ad_app_icon)
    adView.advertiserView = adView.findViewById(R.id.ad_advertiser)

    (adView.headlineView as TextView).text = nativeAd.headline

    val body = nativeAd.body
    if (body == null) {
      adView.bodyView?.visibility = android.view.View.GONE
    } else {
      adView.bodyView?.visibility = android.view.View.VISIBLE
      (adView.bodyView as TextView).text = body
    }

    val cta = nativeAd.callToAction
    if (cta == null) {
      adView.callToActionView?.visibility = android.view.View.GONE
    } else {
      adView.callToActionView?.visibility = android.view.View.VISIBLE
      (adView.callToActionView as Button).text = cta
    }

    val icon = nativeAd.icon
    if (icon == null) {
      adView.iconView?.visibility = android.view.View.GONE
    } else {
      adView.iconView?.visibility = android.view.View.VISIBLE
      (adView.iconView as ImageView).setImageDrawable(icon.drawable)
    }

    val advertiser = nativeAd.advertiser
    if (advertiser == null) {
      adView.advertiserView?.visibility = android.view.View.GONE
    } else {
      adView.advertiserView?.visibility = android.view.View.VISIBLE
      (adView.advertiserView as TextView).text = advertiser
    }

    adView.setNativeAd(nativeAd)
    return adView
  }
}
