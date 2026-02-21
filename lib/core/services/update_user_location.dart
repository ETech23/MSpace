import 'package:supabase_flutter/supabase_flutter.dart';

class UpdateUserLocationService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Update user location in database
  Future<bool> updateUserLocation({
    required String userId,
    required double latitude,
    required double longitude,
    String? address,
    String? city,
    String? state,
    bool isArtisan = false,
  }) async {
    try {
      // Update users table
      await _supabase.from('users').update({
        'latitude': latitude,
        'longitude': longitude,
        'address': address,
        'city': city,
        'state': state,
      }).eq('id', userId);

      // If artisan, update artisan_profiles with PostGIS location
      if (isArtisan) {
        // PostGIS format: POINT(longitude latitude)
        await _supabase.from('artisan_profiles').update({
          'location': 'POINT($longitude $latitude)',
          'address': address,
        }).eq('user_id', userId);
      }

      print('✅ Location updated successfully for user $userId');
      return true;
    } catch (e) {
      print('❌ Error updating location: $e');
      return false;
    }
  }

  /// Check if user has location set
  Future<bool> userHasLocation(String userId) async {
    try {
      final response = await _supabase
          .from('users')
          .select('latitude, longitude')
          .eq('id', userId)
          .single();

      return response['latitude'] != null && response['longitude'] != null;
    } catch (e) {
      return false;
    }
  }

  /// Prompt for location if not set
  Future<bool> shouldPromptForLocation(String userId) async {
    return !(await userHasLocation(userId));
  }
}