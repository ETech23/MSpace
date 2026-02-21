// lib/core/services/fcm_token_service.dart
// Service to manage FCM tokens with Supabase

import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class FCMTokenService {
  final SupabaseClient _supabase;
  final FirebaseMessaging _messaging;

  FCMTokenService({
    required SupabaseClient supabase,
    required FirebaseMessaging messaging,
  })  : _supabase = supabase,
        _messaging = messaging;

  /// Save FCM token to Supabase
  Future<void> saveFCMToken(String userId) async {
    if (kIsWeb) {
      print('⚠️ FCM token management not supported on web');
      return;
    }

    try {
      // Get FCM token
      final token = await _messaging.getToken();
      if (token == null) {
        print('⚠️ FCM token is null');
        return;
      }

      print('📱 FCM Token: ${token.substring(0, 20)}...');

      // Determine device type
      final deviceType = Platform.isAndroid ? 'android' : Platform.isIOS ? 'ios' : 'unknown';

      // Save to Supabase
      await _supabase.from('fcm_tokens').upsert({
        'user_id': userId,
        'token': token,
        'device_type': deviceType,
        'updated_at': DateTime.now().toIso8601String(),
      });

      print('✅ FCM token saved to Supabase');
    } catch (e, stackTrace) {
      print('❌ Error saving FCM token: $e');
      print('Stack trace: $stackTrace');
    }
  }

  /// Delete FCM token from Supabase (on logout)
  Future<void> deleteFCMToken() async {
    if (kIsWeb) return;

    try {
      final token = await _messaging.getToken();
      if (token == null) return;

      await _supabase.from('fcm_tokens').delete().eq('token', token);

      print('🗑️ FCM token deleted from Supabase');
    } catch (e) {
      print('❌ Error deleting FCM token: $e');
    }
  }

  /// Listen for token refresh and update in Supabase
  void listenToTokenRefresh(String userId) {
    if (kIsWeb) return;

    _messaging.onTokenRefresh.listen((newToken) {
      print('🔄 FCM token refreshed');
      saveFCMToken(userId);
    });
  }

  /// Get current FCM token
  Future<String?> getCurrentToken() async {
    if (kIsWeb) return null;
    
    try {
      return await _messaging.getToken();
    } catch (e) {
      print('❌ Error getting FCM token: $e');
      return null;
    }
  }

  /// Check if token is registered for user
  Future<bool> isTokenRegistered(String userId) async {
    try {
      final token = await getCurrentToken();
      if (token == null) return false;

      final response = await _supabase
          .from('fcm_tokens')
          .select('id')
          .eq('user_id', userId)
          .eq('token', token)
          .maybeSingle();

      return response != null;
    } catch (e) {
      print('❌ Error checking token registration: $e');
      return false;
    }
  }
}

// ============================================================================
// USAGE IN AUTH PROVIDER
// ============================================================================

/*
// In your auth_provider.dart:

import '../../core/services/fcm_token_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class AuthNotifier extends StateNotifier<AuthState> {
  final SupabaseClient _supabase;
  late final FCMTokenService _fcmTokenService;

  AuthNotifier(this._supabase) : super(AuthState.initial()) {
    _fcmTokenService = FCMTokenService(
      supabase: _supabase,
      messaging: FirebaseMessaging.instance,
    );
    _initAuth();
  }

  // Call after successful login
  Future<void> _onLoginSuccess(String userId) async {
    // Save FCM token
    await _fcmTokenService.saveFCMToken(userId);
    
    // Listen for token refresh
    _fcmTokenService.listenToTokenRefresh(userId);
  }

  // Call on logout
  Future<void> logout() async {
    // Delete FCM token
    await _fcmTokenService.deleteFCMToken();
    
    // Sign out from Supabase
    await _supabase.auth.signOut();
    
    state = AuthState.initial();
  }

  // Example login method
  Future<void> login(String email, String password) async {
    state = state.copyWith(isLoading: true);

    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null) {
        // Save FCM token after successful login
        await _onLoginSuccess(response.user!.id);
        
        state = state.copyWith(
          isAuthenticated: true,
          user: response.user,
          isLoading: false,
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }
}
*/

// ============================================================================
// ALTERNATIVE: SIMPLER APPROACH WITHOUT SERVICE CLASS
// ============================================================================

/*
// Add these methods directly to your AuthNotifier:

Future<void> _saveFCMToken(String userId) async {
  if (kIsWeb) return;
  
  try {
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null) return;

    await _supabase.from('fcm_tokens').upsert({
      'user_id': userId,
      'token': token,
      'device_type': Platform.isAndroid ? 'android' : 'ios',
      'updated_at': DateTime.now().toIso8601String(),
    });

    print('✅ FCM token saved');
  } catch (e) {
    print('❌ Error saving FCM token: $e');
  }
}

Future<void> _deleteFCMToken() async {
  if (kIsWeb) return;
  
  try {
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null) return;

    await _supabase.from('fcm_tokens').delete().eq('token', token);
    print('🗑️ FCM token deleted');
  } catch (e) {
    print('❌ Error deleting FCM token: $e');
  }
}

// Call _saveFCMToken(userId) after login
// Call _deleteFCMToken() before logout
*/