import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geocoding/geocoding.dart';

class LocationService {
  static const String _lastLatKey = 'last_latitude';
  static const String _lastLngKey = 'last_longitude';
  static const String _lastAddressKey = 'last_address';
  
  // Default location: Port Harcourt, Rivers State, Nigeria
  static const double defaultLatitude = 4.8156;
  static const double defaultLongitude = 7.0498;
  
  /// Get current location with comprehensive fallback strategy
  Future<Position?> getCurrentLocation() async {
    try {
      // Strategy 1: Try to get real GPS location
      final position = await _tryGetGPSLocation();
      if (position != null) {
        await _saveLocation(position.latitude, position.longitude);
        return position;
      }

      // Strategy 2: Use last known location
      final lastKnown = await getLastKnownPosition();
      if (lastKnown != null) {
        return lastKnown;
      }

      // Strategy 3: Use saved location from preferences
      final savedPosition = await _getSavedLocation();
      if (savedPosition != null) {
        return savedPosition;
      }

      // Strategy 4: Use default location
      return Position(
        latitude: defaultLatitude,
        longitude: defaultLongitude,
        timestamp: DateTime.now(),
        accuracy: 0,
        altitude: 0,
        heading: 0,
        speed: 0,
        speedAccuracy: 0,
        altitudeAccuracy: 0,
        headingAccuracy: 0,
      );
    } catch (e) {
      print('Location error: $e');
      // Return default location as ultimate fallback
      return Position(
        latitude: defaultLatitude,
        longitude: defaultLongitude,
        timestamp: DateTime.now(),
        accuracy: 0,
        altitude: 0,
        heading: 0,
        speed: 0,
        speedAccuracy: 0,
        altitudeAccuracy: 0,
        headingAccuracy: 0,
      );
    }
  }

  /// Public method to get address from coordinates
  Future<String> getAddressFromCoordinates(double lat, double lng) async {
    return await _getAddressFromCoordinates(lat, lng);
  }

  /// Try to get GPS location with permission handling
  Future<Position?> _tryGetGPSLocation() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('Location services are disabled');
        return null;
      }

      // Check permission status
      LocationPermission permission = await checkPermission();
      
      if (permission == LocationPermission.denied) {
        permission = await requestPermission();
        if (permission == LocationPermission.denied) {
          print('Location permissions denied');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print('Location permissions permanently denied');
        return null;
      }

      // Try to get position with timeout
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      
      return position;
    } catch (e) {
      print('GPS location failed: $e');
      // Try with lower accuracy
      try {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 5),
        );
        return position;
      } catch (e) {
        print('Fallback GPS also failed: $e');
        return null;
      }
    }
  }

  /// Save location to shared preferences
  Future<void> _saveLocation(double latitude, double longitude) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_lastLatKey, latitude);
      await prefs.setDouble(_lastLngKey, longitude);
      await prefs.setString(_lastAddressKey, 
        await _getAddressFromCoordinates(latitude, longitude));
    } catch (e) {
      print('Error saving location: $e');
    }
  }

  /// Get saved location from shared preferences
  Future<Position?> _getSavedLocation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lat = prefs.getDouble(_lastLatKey);
      final lng = prefs.getDouble(_lastLngKey);
      
      if (lat != null && lng != null) {
        return Position(
          latitude: lat,
          longitude: lng,
          timestamp: DateTime.now(),
          accuracy: 0,
          altitude: 0,
          heading: 0,
          speed: 0,
          speedAccuracy: 0,
          altitudeAccuracy: 0,
          headingAccuracy: 0,
        );
      }
    } catch (e) {
      print('Error getting saved location: $e');
    }
    return null;
  }

  /// Get address from coordinates
  Future<String> _getAddressFromCoordinates(double lat, double lng) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        return '${place.locality}, ${place.administrativeArea}';
      }
    } catch (e) {
      print('Error getting address: $e');
    }
    return 'Unknown Location';
  }

  /// Get saved address
  Future<String?> getSavedAddress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_lastAddressKey);
    } catch (e) {
      return null;
    }
  }

  /// Check if location services are enabled
  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  /// Check location permission status
  Future<LocationPermission> checkPermission() async {
    return await Geolocator.checkPermission();
  }

  /// Request location permission
  Future<LocationPermission> requestPermission() async {
    return await Geolocator.requestPermission();
  }

  /// Get last known position from device
  Future<Position?> getLastKnownPosition() async {
    try {
      return await Geolocator.getLastKnownPosition();
    } catch (e) {
      return null;
    }
  }

  /// Calculate distance between two coordinates in kilometers
  double calculateDistance(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) {
    return Geolocator.distanceBetween(
          startLatitude,
          startLongitude,
          endLatitude,
          endLongitude,
        ) /
        1000;
  }

  /// Open location settings
  Future<bool> openLocationSettings() async {
    return await Geolocator.openLocationSettings();
  }

  /// Open app settings
  Future<bool> openAppSettings() async {
    return await Geolocator.openAppSettings();
  }

  /// Listen to position updates
  Stream<Position> getPositionStream({
    LocationAccuracy accuracy = LocationAccuracy.high,
    int distanceFilter = 10,
  }) {
    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilter,
      ),
    );
  }

  /// Check if we have any usable location
  Future<bool> hasUsableLocation() async {
    // Check if GPS is available
    if (await isLocationServiceEnabled()) {
      final permission = await checkPermission();
      if (permission == LocationPermission.always || 
          permission == LocationPermission.whileInUse) {
        return true;
      }
    }

    // Check if we have saved location
    final saved = await _getSavedLocation();
    if (saved != null) return true;

    // We can always use default location
    return true;
  }
}