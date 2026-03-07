import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Accuracy threshold in meters. Positions with a larger error radius are rejected.
const double _kAcceptableAccuracyMeters = 50.0;

/// How long to wait for a single high-accuracy fix before stepping down.
const Duration _kHighAccuracyTimeout = Duration(seconds: 15);
const Duration _kMediumAccuracyTimeout = Duration(seconds: 10);

/// How long to stream positions looking for a fix that meets the accuracy gate.
const Duration _kStreamTimeout = Duration(seconds: 20);

const String _kHasRequestedLocationPermissionKey =
    'has_requested_location_permission';

class LocationUtils {
  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Read-only check for startup/app-open flows. Never triggers system dialogs.
  static Future<LocationPermission> checkPermissionStatus() =>
      Geolocator.checkPermission();

  /// Request location permission once, only when user takes a deliberate action.
  /// Subsequent calls return current status without re-opening the OS dialog.
  static Future<LocationPermission> requestPermissionOnce() async {
    final prefs = await SharedPreferences.getInstance();
    final hasRequested =
        prefs.getBool(_kHasRequestedLocationPermissionKey) ?? false;

    if (hasRequested) {
      return Geolocator.checkPermission();
    }

    await prefs.setBool(_kHasRequestedLocationPermissionKey, true);
    return Geolocator.requestPermission();
  }

  static Future<bool> hasRequestedLocationPermission() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kHasRequestedLocationPermissionKey) ?? false;
  }

  /// Marks the one-time permission prompt as already handled on this device.
  /// Useful when user declines an in-app rationale so we don't keep re-prompting
  /// on every app open.
  static Future<void> markPermissionPromptHandled() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kHasRequestedLocationPermissionKey, true);
  }

  /// Returns the best available [Position] or `null` when location is
  /// unavailable / permission not granted.
  ///
  /// Resolution order:
  ///   1. Stream-based fix that passes the accuracy gate (most reliable)
  ///   2. One-shot high-accuracy call
  ///   3. One-shot medium-accuracy call
  ///   4. `null` - caller must handle gracefully.
  static Future<Position?> getCurrentLocation() async {
    final permissionOk = await _ensurePermission();
    if (!permissionOk) return null;

    final streamFix = await _getAccuratePositionFromStream();
    if (streamFix != null) return streamFix;

    final highFix = await _oneShotPosition(
      accuracy: LocationAccuracy.high,
      timeout: _kHighAccuracyTimeout,
    );
    if (highFix != null) return highFix;

    return _oneShotPosition(
      accuracy: LocationAccuracy.medium,
      timeout: _kMediumAccuracyTimeout,
    );
  }

  static Future<bool> hasLocationPermission() async {
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  static Future<bool> openLocationSettings() => Geolocator.openLocationSettings();

  static Future<bool> openAppSettings() => Geolocator.openAppSettings();

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Check-only. Does not request permissions.
  static Future<bool> _ensurePermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    final permission = await Geolocator.checkPermission();

    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  static Future<Position?> _getAccuratePositionFromStream() async {
    final completer = Completer<Position?>();
    StreamSubscription<Position>? subscription;

    final timer = Timer(_kStreamTimeout, () {
      if (!completer.isCompleted) {
        subscription?.cancel();
        completer.complete(null);
      }
    });

    try {
      subscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 0,
        ),
      ).listen(
        (position) {
          if (position.accuracy <= _kAcceptableAccuracyMeters &&
              !completer.isCompleted) {
            timer.cancel();
            subscription?.cancel();
            completer.complete(position);
          }
        },
        onError: (_) {
          if (!completer.isCompleted) {
            timer.cancel();
            subscription?.cancel();
            completer.complete(null);
          }
        },
        cancelOnError: true,
      );
    } catch (_) {
      timer.cancel();
      if (!completer.isCompleted) completer.complete(null);
    }

    return completer.future;
  }

  static Future<Position?> _oneShotPosition({
    required LocationAccuracy accuracy,
    required Duration timeout,
  }) async {
    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: accuracy,
        timeLimit: timeout,
      );
    } catch (_) {
      return null;
    }
  }
}
