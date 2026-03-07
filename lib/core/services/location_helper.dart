import 'dart:async';

import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocationHelper {
  static const String _kHasRequestedLocationPermissionKey =
      'has_requested_location_permission';

  /// Get current position with fallback strategies.
  /// This method never triggers the OS permission dialog.
  static Future<Position?> getCurrentPosition() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return _getLastKnownPosition();
      }

      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return _getLastKnownPosition();
      }

      try {
        return await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 15),
        ).timeout(const Duration(seconds: 15));
      } on TimeoutException {
        // Fall through to medium accuracy.
      }

      try {
        return await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 10),
        ).timeout(const Duration(seconds: 10));
      } on TimeoutException {
        // Fall through to last known position.
      }

      return _getLastKnownPosition();
    } catch (_) {
      return _getLastKnownPosition();
    }
  }

  static Future<Position?> _getLastKnownPosition() async {
    try {
      return await Geolocator.getLastKnownPosition();
    } catch (_) {
      return null;
    }
  }

  static Future<String?> getAddressFromCoordinates({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final placemarks = await placemarkFromCoordinates(latitude, longitude)
          .timeout(const Duration(seconds: 5), onTimeout: () => <Placemark>[]);

      if (placemarks.isEmpty) return null;

      final place = placemarks.first;
      final address = [
        place.street,
        place.locality,
        place.administrativeArea,
        place.country,
      ].where((e) => e != null && e.isNotEmpty).join(', ');

      return address.isNotEmpty ? address : null;
    } catch (_) {
      return null;
    }
  }

  static Future<bool> isLocationServiceEnabled() =>
      Geolocator.isLocationServiceEnabled();

  static Future<LocationPermission> checkPermission() =>
      Geolocator.checkPermission();

  /// Read-only check for startup/app-open flows.
  static Future<LocationPermission> checkPermissionStatus() =>
      Geolocator.checkPermission();

  /// Request system location permission only once.
  /// On subsequent calls, returns current status without showing OS dialog.
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

  /// Backward-compatible alias.
  static Future<LocationPermission> requestPermission() =>
      requestPermissionOnce();

  static Future<bool> openLocationSettings() => Geolocator.openLocationSettings();

  static Future<bool> openAppSettings() => Geolocator.openAppSettings();

  static Future<Map<String, dynamic>> getLocationData() async {
    final position = await getCurrentPosition();

    if (position == null) {
      return {
        'position': null,
        'latitude': null,
        'longitude': null,
        'address': null,
      };
    }

    final address = await getAddressFromCoordinates(
      latitude: position.latitude,
      longitude: position.longitude,
    );

    return {
      'position': position,
      'latitude': position.latitude,
      'longitude': position.longitude,
      'address': address,
    };
  }
}
