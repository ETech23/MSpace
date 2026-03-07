import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/location_utils.dart';

/// Structured result returned by [LocationService].
class LocationResult {
  final Position position;
  final String? address;
  final String? city;
  final String? state;
  final String? country;

  /// Whether this position came from a live GPS fix (true) or a cached
  /// / persisted source (false). Callers should surface this distinction
  /// to avoid writing stale data to the backend.
  final bool isLive;

  const LocationResult({
    required this.position,
    required this.isLive,
    this.address,
    this.city,
    this.state,
    this.country,
  });

  double get latitude => position.latitude;
  double get longitude => position.longitude;

  /// Accuracy radius in meters as reported by the OS.
  double get accuracyMeters => position.accuracy;

  @override
  String toString() =>
      'LocationResult(lat=$latitude, lng=$longitude, '
      'accuracy=${accuracyMeters}m, live=$isLive, city=$city)';
}

class LocationService {
  /// Default fallback coordinates (Port Harcourt, Nigeria).
  static const double defaultLatitude = 4.8156;
  static const double defaultLongitude = 7.0498;

  // ---------------------------------------------------------------------------
  // SharedPreferences keys
  // ---------------------------------------------------------------------------
  static const String _kLatKey = 'loc_latitude';
  static const String _kLngKey = 'loc_longitude';
  static const String _kAddressKey = 'loc_address';
  static const String _kCityKey = 'loc_city';
  static const String _kStateKey = 'loc_state';
  static const String _kCountryKey = 'loc_country';
  static const String _kSavedAtKey = 'loc_saved_at_ms';

  /// Maximum age of a persisted location before it is considered too stale
  /// to use as a UI hint. It will never be written to the backend regardless.
  static const Duration _kMaxCacheAge = Duration(hours: 24);

  /// Minimum distance in metres between old and new coordinates before we
  /// bother writing an update to the backend.
  static const double _kMinUpdateDistanceMeters = 100.0;

  /// Geocoding timeout.
  static const Duration _kGeocodingTimeout = Duration(seconds: 5);

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Attempts a live GPS fix and enriches it with a reverse-geocoded address.
  ///
  /// Returns `null` only when:
  ///   - Location services are disabled AND
  ///   - No valid persisted location exists
  ///
  /// The [LocationResult.isLive] flag tells the caller whether the result is
  /// fresh. **Only write to the backend when `isLive == true`.**
  Future<LocationResult?> getLocation() async {
    // 1. Try a live GPS fix.
    final position = await LocationUtils.getCurrentLocation();

    if (position != null) {
      final geo = await _reverseGeocode(position.latitude, position.longitude);
      final result = LocationResult(
        position: position,
        isLive: true,
        address: geo['address'],
        city: geo['city'],
        state: geo['state'],
        country: geo['country'],
      );
      await _persistLocation(result);
      return result;
    }

    // 2. GPS unavailable — return persisted cache as a UI hint only.
    return await _loadPersistedLocation();
  }

  /// Backwards-compatible API: returns the best available [Position] or `null`.
  /// Uses cached data when live GPS is unavailable.
  Future<Position?> getCurrentLocation() async {
    final result = await getLocation();
    return result?.position;
  }

  /// Returns a cached [LocationResult] if one exists and is within
  /// [_kMaxCacheAge], otherwise `null`.
  ///
  /// Use this to pre-populate UI before the live fix resolves.
  Future<LocationResult?> getCachedLocation() => _loadPersistedLocation();

  /// Backwards-compatible API: returns a human-readable address for coordinates.
  Future<String?> getAddressFromCoordinates(double lat, double lng) async {
    final geo = await _reverseGeocode(lat, lng);
    final address = geo['address'];
    if (address != null && address.isNotEmpty) return address;

    final parts = [
      geo['city'],
      geo['state'],
      geo['country'],
    ].where((e) => e != null && e.isNotEmpty).cast<String>().toList();

    return parts.isEmpty ? null : parts.join(', ');
  }

  /// Calculates distance in **kilometres** between two coordinate pairs.
  double distanceKm(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) {
    return Geolocator.distanceBetween(startLat, startLng, endLat, endLng) /
        1000.0;
  }

  /// Backwards-compatible API: returns distance in kilometres.
  double calculateDistance(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) {
    return distanceKm(startLat, startLng, endLat, endLng);
  }

  /// `true` when the new position is far enough from [savedLat]/[savedLng]
  /// to warrant a backend write.
  bool shouldUpdateBackend({
    required double savedLat,
    required double savedLng,
    required double newLat,
    required double newLng,
  }) {
    final distanceMeters = Geolocator.distanceBetween(
      savedLat,
      savedLng,
      newLat,
      newLng,
    );
    return distanceMeters >= _kMinUpdateDistanceMeters;
  }

  /// Continuous position stream. Emits only positions that pass the accuracy
  /// gate and are at least [minDistanceMeters] from the previous emission.
  Stream<Position> getPositionStream({
    LocationAccuracy accuracy = LocationAccuracy.high,
    int minDistanceMeters = 10,
  }) {
    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: accuracy,
        distanceFilter: minDistanceMeters,
      ),
    ).where((p) => p.accuracy <= 50.0); // enforce accuracy gate on stream too
  }

  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();
  Future<bool> openAppSettings() => Geolocator.openAppSettings();

  /// Backwards-compatible API: returns whether location services are enabled.
  Future<bool> isLocationServiceEnabled() =>
      Geolocator.isLocationServiceEnabled();

  /// Read-only permission check for app startup flows.
  Future<LocationPermission> checkPermissionStatus() =>
      LocationUtils.checkPermissionStatus();

  /// One-time permission request. Should be called only after user intent.
  Future<LocationPermission> requestPermissionOnce() =>
      LocationUtils.requestPermissionOnce();

  Future<bool> hasRequestedLocationPermission() =>
      LocationUtils.hasRequestedLocationPermission();

  /// Marks location prompt flow as handled on this device without triggering
  /// the OS permission dialog.
  Future<void> markLocationPromptHandled() =>
      LocationUtils.markPermissionPromptHandled();

  /// Backwards-compatible API: returns a cached/persisted address if available.
  Future<String?> getSavedAddress() async {
    final cached = await _loadPersistedLocation();
    if (cached == null) return null;

    if (cached.address != null && cached.address!.isNotEmpty) {
      return cached.address;
    }

    final parts = [
      cached.city,
      cached.state,
      cached.country,
    ].where((e) => e != null && e.isNotEmpty).cast<String>().toList();

    return parts.isEmpty ? null : parts.join(', ');
  }

  // ---------------------------------------------------------------------------
  // Reverse geocoding
  // ---------------------------------------------------------------------------

  /// Returns a map with keys: address, city, state, country.
  /// All values may be null if geocoding fails.
  Future<Map<String, String?>> reverseGeocode(double lat, double lng) =>
      _reverseGeocode(lat, lng);

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  Future<Map<String, String?>> _reverseGeocode(double lat, double lng) async {
    try {
      // Round to ~11 m precision to prevent address flickering from GPS jitter.
      final rLat = _roundCoord(lat);
      final rLng = _roundCoord(lng);

      final placemarks = await placemarkFromCoordinates(rLat, rLng)
          .timeout(_kGeocodingTimeout, onTimeout: () => <Placemark>[]);

      if (placemarks.isEmpty) return _emptyGeo();

      final p = placemarks.first;

      final addressParts = [
        p.street,
        p.subLocality,
        p.locality,
      ].where((e) => e != null && e.isNotEmpty).join(', ');

      return {
        'address': addressParts.isNotEmpty ? addressParts : null,
        'city': p.locality?.isNotEmpty == true ? p.locality : null,
        'state': p.administrativeArea?.isNotEmpty == true
            ? p.administrativeArea
            : null,
        'country': p.country?.isNotEmpty == true ? p.country : null,
      };
    } catch (_) {
      return _emptyGeo();
    }
  }

  Map<String, String?> _emptyGeo() =>
      {'address': null, 'city': null, 'state': null, 'country': null};

  /// Rounds to 4 decimal places ≈ 11 m precision.
  double _roundCoord(double value) =>
      (value * 10000).round() / 10000.0;

  // ---------------------------------------------------------------------------
  // Persistence
  // ---------------------------------------------------------------------------

  Future<void> _persistLocation(LocationResult result) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_kLatKey, result.latitude);
      await prefs.setDouble(_kLngKey, result.longitude);
      await prefs.setInt(
          _kSavedAtKey, DateTime.now().millisecondsSinceEpoch);
      if (result.address != null) {
        await prefs.setString(_kAddressKey, result.address!);
      }
      if (result.city != null) {
        await prefs.setString(_kCityKey, result.city!);
      }
      if (result.state != null) {
        await prefs.setString(_kStateKey, result.state!);
      }
      if (result.country != null) {
        await prefs.setString(_kCountryKey, result.country!);
      }
    } catch (_) {
      // Non-fatal; app continues without persistence.
    }
  }

  Future<LocationResult?> _loadPersistedLocation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lat = prefs.getDouble(_kLatKey);
      final lng = prefs.getDouble(_kLngKey);
      final savedAtMs = prefs.getInt(_kSavedAtKey);

      if (lat == null || lng == null) return null;

      // Reject if too old.
      if (savedAtMs != null) {
        final age = DateTime.now()
            .difference(DateTime.fromMillisecondsSinceEpoch(savedAtMs));
        if (age > _kMaxCacheAge) return null;
      }

      final position = Position(
        latitude: lat,
        longitude: lng,
        timestamp: savedAtMs != null
            ? DateTime.fromMillisecondsSinceEpoch(savedAtMs)
            : DateTime.now(),
        accuracy: 0,
        altitude: 0,
        heading: 0,
        speed: 0,
        speedAccuracy: 0,
        altitudeAccuracy: 0,
        headingAccuracy: 0,
      );

      return LocationResult(
        position: position,
        isLive: false,
        address: prefs.getString(_kAddressKey),
        city: prefs.getString(_kCityKey),
        state: prefs.getString(_kStateKey),
        country: prefs.getString(_kCountryKey),
      );
    } catch (_) {
      return null;
    }
  }
}
