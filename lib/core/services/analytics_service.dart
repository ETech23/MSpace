import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AnalyticsService {
  AnalyticsService._();

  static final AnalyticsService instance = AnalyticsService._();
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  Future<void> setUser({
    required String userId,
    required String userType,
  }) async {
    try {
      await _analytics.setUserId(id: userId);
      await _analytics.setUserProperty(name: 'user_type', value: userType);
    } catch (e) {
      debugPrint('📊 Analytics setUser failed: $e');
    }
  }

  Future<void> clearUser() async {
    try {
      await _analytics.setUserId(id: null);
      await _analytics.setUserProperty(name: 'user_type', value: null);
    } catch (e) {
      debugPrint('📊 Analytics clearUser failed: $e');
    }
  }

  Future<void> logEvent(String name, {Map<String, Object?>? params}) async {
    try {
      Map<String, Object>? sanitized;
      if (params != null) {
        sanitized = <String, Object>{};
        params.forEach((key, value) {
          if (value == null) return;
          if (value is String || value is num || value is bool) {
            sanitized![key] = value;
          }
        });
      }
      await _analytics.logEvent(name: name, parameters: sanitized);
    } catch (e) {
      debugPrint('📊 Analytics event "$name" failed: $e');
    }
  }

  Future<void> logScreen(String screenName) async {
    try {
      await _analytics.logScreenView(screenName: screenName);
    } catch (e) {
      debugPrint('📊 Analytics screen "$screenName" failed: $e');
    }
  }
  Future<void> logProfileView({
    required String profileUserId,
    required String profileType,
    String? category,
    String? viewerName,
    String? viewerPhotoUrl,
    String? viewerUserType,
  }) async {
    await logEvent(
      'profile_view',
      params: {
        'profile_id': profileUserId,
        'profile_type': profileType,
        'category': category,
      },
    );

    try {
      await Supabase.instance.client.rpc(
        'log_profile_view',
        params: {
          'p_profile_user_id': profileUserId,
          'p_profile_user_type': profileType,
          'p_viewer_name': viewerName,
          'p_viewer_photo_url': viewerPhotoUrl,
          'p_viewer_user_type': viewerUserType,
          'p_source': 'app',
        },
      );
    } catch (e) {
      debugPrint('Analytics profile view persistence failed: $e');
    }
  }

  Future<void> maybeSendProfileViewDigest() async {
    try {
      await Supabase.instance.client.rpc('send_my_profile_view_digest');
    } catch (e) {
      debugPrint('Analytics profile view digest skipped: $e');
    }
  }
}
