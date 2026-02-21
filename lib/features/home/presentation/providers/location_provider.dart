import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import '../../../../core/services/location_service.dart';

// State class for user location
class UserLocationState {
  final double? latitude;
  final double? longitude;
  final String? city;
  final String? locality; // Community/neighborhood
  final String? country;
  final bool isLoading;
  final String? error;

  UserLocationState({
    this.latitude,
    this.longitude,
    this.city,
    this.locality,
    this.country,
    this.isLoading = false,
    this.error,
  });

  UserLocationState copyWith({
    double? latitude,
    double? longitude,
    String? city,
    String? locality,
    String? country,
    bool? isLoading,
    String? error,
  }) {
    return UserLocationState(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      city: city ?? this.city,
      locality: locality ?? this.locality,
      country: country ?? this.country,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  String get displayLocation {
    if (locality != null && city != null) {
      return '$locality, $city';
    } else if (city != null) {
      return city!;
    } else if (country != null) {
      return country!;
    }
    return 'Unknown Location';
  }

  bool get hasLocation => latitude != null && longitude != null;
}

// Notifier for location state
class UserLocationNotifier extends StateNotifier<UserLocationState> {
  final LocationService locationService;

  UserLocationNotifier(this.locationService) : super(UserLocationState());

  Future<void> loadUserLocation() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      // Get position (with fallback strategy)
      final position = await locationService.getCurrentLocation();
      
      if (position != null) {
        state = state.copyWith(
          latitude: position.latitude,
          longitude: position.longitude,
        );

        // Get address details
        await _getAddressFromCoordinates(position.latitude, position.longitude);
        
        state = state.copyWith(isLoading: false);
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Unable to get location',
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> _getAddressFromCoordinates(double lat, double lng) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        
        state = state.copyWith(
          city: place.locality ?? place.administrativeArea,
          locality: place.subLocality ?? place.locality,
          country: place.country,
        );
      }
    } catch (e) {
      print('Error getting address: $e');
      // Set default location name
      state = state.copyWith(
        city: 'Port Harcourt',
        locality: 'Rivers State',
        country: 'Nigeria',
      );
    }
  }

  void clearLocation() {
    state = UserLocationState();
  }
}

// Provider
final userLocationProvider = StateNotifierProvider<UserLocationNotifier, UserLocationState>(
  (ref) => UserLocationNotifier(LocationService()),
);