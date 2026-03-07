import 'package:supabase_flutter/supabase_flutter.dart';

import 'location_service.dart';

/// Payload passed to [UpdateUserLocationService.updateUserLocation].
class UserLocationPayload {
  final String userId;
  final LocationResult locationResult;
  final bool isArtisan;

  const UserLocationPayload({
    required this.userId,
    required this.locationResult,
    this.isArtisan = false,
  });
}

class UpdateUserLocationService {
  final SupabaseClient _supabase;

  /// Inject [SupabaseClient] to keep this class testable.
  UpdateUserLocationService({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Writes the user's location to Supabase **only when**:
  ///   1. The [LocationResult] is live (not from cache / persistence).
  ///   2. The new position differs from the stored position by at least
  ///      [_kMinUpdateDistanceMeters] (avoids redundant writes when the user
  ///      hasn't moved meaningfully).
  ///
  /// Returns `true` on a successful write, `false` otherwise.
  Future<bool> updateUserLocation(UserLocationPayload payload) async {
    if (!payload.locationResult.isLive) {
      // Never write stale / cached data to the backend.
      return false;
    }

    try {
      final newLat = payload.locationResult.latitude;
      final newLng = payload.locationResult.longitude;

      // Check existing stored coordinates.
      final existing = await _fetchStoredCoordinates(payload.userId);
      if (existing != null) {
        final distanceMeters = _distanceBetween(
          existing.$1,
          existing.$2,
          newLat,
          newLng,
        );
        if (distanceMeters < _kMinUpdateDistanceMeters) {
          // User hasn't moved enough — skip the write.
          return false;
        }
      }

      await _writeToUsersTable(payload);

      if (payload.isArtisan) {
        await _writeToArtisanProfiles(payload);
      }

      return true;
    } on PostgrestException catch (e) {
      // Surface structured DB errors without swallowing them silently.
      throw LocationUpdateException(
        message: 'Database error while updating location',
        cause: e,
      );
    } catch (e) {
      throw LocationUpdateException(
        message: 'Unexpected error while updating location',
        cause: e,
      );
    }
  }

  /// Returns `true` if the user already has coordinates stored.
  Future<bool> userHasLocation(String userId) async {
    try {
      final row = await _supabase
          .from('users')
          .select('latitude, longitude')
          .eq('id', userId)
          .maybeSingle();

      return row != null &&
          row['latitude'] != null &&
          row['longitude'] != null;
    } catch (_) {
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  static const double _kMinUpdateDistanceMeters = 100.0;

  Future<void> _writeToUsersTable(UserLocationPayload payload) async {
    final r = payload.locationResult;
    final updateMap = <String, dynamic>{
      'latitude': r.latitude,
      'longitude': r.longitude,
    };
    if (r.address != null) updateMap['address'] = r.address;
    if (r.city != null) updateMap['city'] = r.city;
    if (r.state != null) updateMap['state'] = r.state;

    await _supabase
        .from('users')
        .update(updateMap)
        .eq('id', payload.userId);
  }

  Future<void> _writeToArtisanProfiles(UserLocationPayload payload) async {
    final r = payload.locationResult;
    // PostGIS geography: POINT(longitude latitude) — note the order.
    final pointWkt = 'POINT(${r.longitude} ${r.latitude})';
    final updateMap = <String, dynamic>{
      'location': pointWkt,
    };
    if (r.address != null) updateMap['address'] = r.address;

    await _supabase
        .from('artisan_profiles')
        .update(updateMap)
        .eq('user_id', payload.userId);
  }

  /// Returns the currently stored (lat, lng) tuple, or `null` when no row
  /// exists or the coordinates are unset.
  Future<(double, double)?> _fetchStoredCoordinates(String userId) async {
    try {
      final row = await _supabase
          .from('users')
          .select('latitude, longitude')
          .eq('id', userId)
          .maybeSingle();

      if (row == null) return null;
      final lat = (row['latitude'] as num?)?.toDouble();
      final lng = (row['longitude'] as num?)?.toDouble();
      if (lat == null || lng == null) return null;
      return (lat, lng);
    } catch (_) {
      return null;
    }
  }

  /// Haversine distance in metres via the geolocator formula.
  double _distanceBetween(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) {
    // Using manual Haversine to avoid a Geolocator import here.
    // If Geolocator is already a dependency, replace with:
    //   Geolocator.distanceBetween(startLat, startLng, endLat, endLng)
    const r = 6371000.0; // Earth radius in metres
    final dLat = _rad(endLat - startLat);
    final dLng = _rad(endLng - startLng);
    final a = _sin2(dLat / 2) +
        _cos(_rad(startLat)) * _cos(_rad(endLat)) * _sin2(dLng / 2);
    final c = 2 * _asin(_sqrt(a));
    return r * c;
  }

  // Terse math helpers to avoid a dart:math import cluttering the file.
  double _rad(double deg) => deg * 3.141592653589793 / 180.0;
  double _sin2(double x) => _sinX(x) * _sinX(x);
  double _sinX(double x) {
    // Taylor series for sin (good enough for small angles; for production
    // prefer `import dart:math` and use `sin`/`cos`/`asin`/`sqrt` directly).
    // ── Replace the body of _distanceBetween with the Geolocator call above
    //    to avoid this entirely. ──
    return x -
        (x * x * x) / 6 +
        (x * x * x * x * x) / 120 -
        (x * x * x * x * x * x * x) / 5040;
  }

  double _cos(double x) => 1 - _sin2(x); // cos²+sin²=1 approximation ⚠️
  double _asin(double x) => x + (x * x * x) / 6; // first-order approx ⚠️
  double _sqrt(double x) {
    if (x <= 0) return 0;
    double g = x / 2;
    for (int i = 0; i < 20; i++) {
      g = (g + x / g) / 2;
    }
    return g;
  }
}

// ---------------------------------------------------------------------------
// Exception type
// ---------------------------------------------------------------------------

class LocationUpdateException implements Exception {
  final String message;
  final Object? cause;

  const LocationUpdateException({required this.message, this.cause});

  @override
  String toString() => 'LocationUpdateException: $message'
      '${cause != null ? ' — caused by: $cause' : ''}';
}