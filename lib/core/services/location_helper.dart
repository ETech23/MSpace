import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class LocationHelper {
  /// Get current position with fallback strategies
  static Future<Position?> getCurrentPosition() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('⚠️ Location services are disabled');
        return await _getLastKnownPosition();
      }

      // Check and request permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('⚠️ Location permissions denied');
          return await _getLastKnownPosition();
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        print('⚠️ Location permissions permanently denied');
        return await _getLastKnownPosition();
      }

      // Strategy 1: Try high accuracy with timeout
      try {
        print('📍 Trying high accuracy GPS...');
        return await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 15),
        ).timeout(const Duration(seconds: 15));
      } on TimeoutException {
        print('⏰ High accuracy timeout');
      }

      // Strategy 2: Try medium accuracy
      try {
        print('📍 Trying medium accuracy GPS...');
        return await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 10),
        ).timeout(const Duration(seconds: 10));
      } on TimeoutException {
        print('⏰ Medium accuracy timeout');
      }

      // Strategy 3: Last known position
      return await _getLastKnownPosition();
      
    } catch (e) {
      print('❌ Location error: $e');
      return await _getLastKnownPosition();
    }
  }

  /// Get last known position as fallback
  static Future<Position?> _getLastKnownPosition() async {
    try {
      print('📍 Trying last known position...');
      final position = await Geolocator.getLastKnownPosition();
      if (position != null) {
        print('✅ Using last known position: (${position.latitude}, ${position.longitude})');
        return position;
      }
    } catch (e) {
      print('⚠️ Could not get last known position: $e');
    }
    return null;
  }

  /// Get address from coordinates
  static Future<String?> getAddressFromCoordinates({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final placemarks = await placemarkFromCoordinates(
        latitude,
        longitude,
      ).timeout(
        const Duration(seconds: 5),
        onTimeout: () => <Placemark>[],
      );
      
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        final address = [
          place.street,
          place.locality,
          place.administrativeArea,
          place.country,
        ].where((e) => e != null && e.isNotEmpty).join(', ');
        
        return address.isNotEmpty ? address : null;
      }
    } catch (e) {
      print('⚠️ Could not get address: $e');
    }
    return null;
  }

  /// Check if location services are available
  static Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  /// Check location permission status
  static Future<LocationPermission> checkPermission() async {
    return await Geolocator.checkPermission();
  }

  /// Request location permission
  static Future<LocationPermission> requestPermission() async {
    return await Geolocator.requestPermission();
  }

  /// Open location settings
  static Future<bool> openLocationSettings() async {
    return await Geolocator.openLocationSettings();
  }

  /// Get location with both position and address
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