import 'dart:io';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class InstallReferrerService {
  static const String _kPendingReferralCode = 'pending_referral_code';
  static const MethodChannel _channel =
      MethodChannel('mspace/install_referrer');

  Future<void> captureIfNeeded() async {
    if (!Platform.isAndroid) return;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(_kPendingReferralCode)) return;

    try {
      final raw = await _channel.invokeMethod<String>('getInstallReferrer');
      if (raw == null || raw.isEmpty) return;

      final decoded = Uri.decodeComponent(raw);
      final params = Uri.splitQueryString(decoded);
      final code = params['ref'] ?? params['referral_code'];
      if (code == null || code.isEmpty) return;

      await prefs.setString(_kPendingReferralCode, code.trim());
    } catch (_) {
      // Silent fallback; referral attribution is optional.
    }
  }

  Future<String?> takePendingReferralCode() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_kPendingReferralCode);
    if (code == null || code.isEmpty) return null;
    await prefs.remove(_kPendingReferralCode);
    return code;
  }

  Future<String?> peekPendingReferralCode() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_kPendingReferralCode);
    if (code == null || code.isEmpty) return null;
    return code;
  }

  Future<void> setPendingReferralCode(String code) async {
    final trimmed = code.trim();
    if (trimmed.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPendingReferralCode, trimmed);
  }
}
