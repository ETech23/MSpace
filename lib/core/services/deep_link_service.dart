import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';

import 'install_referrer_service.dart';

class DeepLinkService {
  DeepLinkService._();

  static final DeepLinkService instance = DeepLinkService._();

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;

  Future<void> startListening() async {
    await _handleInitialLink();

    _sub?.cancel();
    _sub = _appLinks.uriLinkStream.listen(
      _handleUri,
      onError: (err) {
        if (kDebugMode) {
          print('🔗 Deep link error: $err');
        }
      },
    );
  }

  Future<void> _handleInitialLink() async {
    try {
      final uri = await _appLinks.getInitialLink();
      await _handleUri(uri);
    } catch (err) {
      if (kDebugMode) {
        print('🔗 Initial link error: $err');
      }
    }
  }

  Future<void> _handleUri(Uri? uri) async {
    if (uri == null) return;
    final code = _extractReferralCode(uri);
    if (code == null) return;
    await InstallReferrerService().setPendingReferralCode(code);
  }

  String? _extractReferralCode(Uri uri) {
    final queryCode =
        uri.queryParameters['ref'] ??
        uri.queryParameters['referral_code'] ??
        uri.queryParameters['code'];
    if (queryCode != null && queryCode.trim().isNotEmpty) {
      return queryCode.trim();
    }

    final segments = uri.pathSegments;
    if (segments.isEmpty) return null;

    final first = segments.first.toLowerCase();
    if ((first == 'r' || first == 'ref') && segments.length >= 2) {
      final pathCode = segments[1].trim();
      return pathCode.isEmpty ? null : pathCode;
    }

    return null;
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
  }
}
