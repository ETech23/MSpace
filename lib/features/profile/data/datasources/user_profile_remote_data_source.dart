// lib/features/profile/data/datasources/user_profile_remote_data_source.dart
// FINAL FIXED VERSION

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/error/exceptions.dart';
import '../../domain/entities/user_profile_entity.dart';

abstract class UserProfileRemoteDataSource {
  Future<UserProfileEntity> getUserProfile({
    required String userId,
    required String userType,
  });
  
  Future<Map<String, dynamic>> getUserBookingStats({
    required String userId,
    required String userType,
  });
}

class UserProfileRemoteDataSourceImpl implements UserProfileRemoteDataSource {
  final SupabaseClient supabaseClient;

  UserProfileRemoteDataSourceImpl({
    required this.supabaseClient,
  });

 @override
Future<UserProfileEntity> getUserProfile({
  required String userId,
  required String userType,
}) async {
  try {
    print('🔄 Fetching profile for user: $userId, suggested type: $userType');
    
    // ALWAYS check if user has artisan profile first
    try {
      final artisanProfile = await supabaseClient
          .from('artisan_profiles')
          .select('''
            *,
            users(
              name,
              email,
              photo_url,
              phone,
              address,
              latitude,
              longitude,
              created_at
            )
          ''')
          .eq('user_id', userId)
          .maybeSingle();
      
      if (artisanProfile != null) {
        print('✅ User HAS artisan profile - fetching as artisan');
        return _parseArtisanProfile(artisanProfile);
      }
    } catch (e) {
      print('⚠️ No artisan profile found: $e');
    }
    
    // If no artisan profile, fetch as client
    print('📝 Fetching as client from users table');
    return await _getClientProfile(userId);
    
  } catch (e) {
    print('❌ Error in getUserProfile: $e');
    throw ServerException(message: 'Failed to load user profile: $e');
  }
}

  Future<UserProfileEntity> _getArtisanProfile(String userId) async {
    try {
      // OPTION 1: Try with explicit foreign key name (if you know it)
      // Check your database to find the exact foreign key constraint name
      // In Supabase dashboard: Table Editor → artisan_profiles → user_id column → View foreign key
      
      var response = await supabaseClient
          .from('artisan_profiles')
          .select('''
            *,
            users!artisan_profiles_user_id_fkey(
              name,
              email,
              photo_url,
              phone,
              address,
              latitude,
              longitude,
              created_at
            )
          ''')
          .eq('user_id', userId)
          .maybeSingle();
      
      // If the foreign key name is different, try without specifying it
      if (response == null) {
        print('⚠️ Trying alternate JOIN syntax...');
        response = await supabaseClient
            .from('artisan_profiles')
            .select('''
              *,
              users(
                name,
                email,
                photo_url,
                phone,
                address,
                latitude,
                longitude,
                created_at
              )
            ''')
            .eq('user_id', userId)
            .maybeSingle();
      }
      
      if (response != null) {
        print('✅ Found artisan profile with user data');
        print('📊 Response: $response');
        return _parseArtisanProfile(response);
      }
      
      // Fallback: Get from users table
      print('⚠️ Artisan profile not found, trying users table...');
      final userResponse = await supabaseClient
          .from('users')
          .select()
          .eq('id', userId)
          .maybeSingle();
      
      if (userResponse != null) {
        print('✅ Found user in users table');
        return _parseUserAsProfile(userResponse, 'artisan');
      }
      
      throw ServerException(message: 'Artisan profile not found');
      
    } catch (e) {
      print('❌ Error fetching artisan profile: $e');
      rethrow;
    }
  }

  Future<UserProfileEntity> _getClientProfile(String userId) async {
    try {
      // Clients are stored in users table
      final response = await supabaseClient
          .from('users')
          .select()
          .eq('id', userId)
          .maybeSingle();
      
      if (response != null) {
        print('✅ Found client profile');
        print('📊 Response: $response');
        return _parseUserAsProfile(response, 'client');
      }
      
      throw ServerException(message: 'Client profile not found');
      
    } catch (e) {
      print('❌ Error fetching client profile: $e');
      rethrow;
    }
  }

  UserProfileEntity _parseArtisanProfile(Map<String, dynamic> data) {
    print('📊 Parsing artisan profile data keys: ${data.keys.toList()}');
    
    // Extract user data from JOIN
    Map<String, dynamic>? userData;
    if (data['users'] != null) {
      if (data['users'] is Map) {
        userData = data['users'] as Map<String, dynamic>;
      } else if (data['users'] is List && (data['users'] as List).isNotEmpty) {
        userData = (data['users'] as List).first as Map<String, dynamic>;
      }
    }
    
    print('📊 User data: $userData');
    
    // Extract location from user data
    String? location = userData?['address']?.toString();
    
    // Parse skills
    List<String>? skills;
    if (data['skills'] != null) {
      if (data['skills'] is List) {
        skills = (data['skills'] as List).map((s) => s.toString()).toList();
      } else if (data['skills'] is String) {
        skills = (data['skills'] as String).split(',').map((s) => s.trim()).toList();
      }
    }
    
    // Parse experience years
    int? yearsOfExperience;
    final expData = data['experience_years'] ?? data['years_of_experience'];
    if (expData != null) {
      if (expData is int) {
        yearsOfExperience = expData;
      } else if (expData is String) {
        yearsOfExperience = int.tryParse(expData);
      }
    }
    
    // Extract rating data
    final rating = (data['rating'] as num?)?.toDouble();
    final reviewCount = data['reviews_count'] as int? ?? 
                       data['review_count'] as int? ?? 
                       data['total_reviews'] as int? ?? 
                       0;
    
    // Extract verification status
    final isVerified = data['verified'] as bool? ?? 
                      data['is_verified'] as bool? ?? 
                      false;
    
    print('✨ Parsed artisan data: rating=$rating, reviews=$reviewCount, verified=$isVerified');
    
    return UserProfileEntity(
      id: data['user_id']?.toString() ?? data['id']?.toString() ?? '',
      displayName: userData?['name']?.toString() ?? 'Unknown Artisan',
      userType: 'artisan',
      profilePhotoUrl: userData?['photo_url']?.toString(),
      phone: userData?['phone']?.toString(),
      email: userData?['email']?.toString(),
      location: location,
      rating: rating,
      totalReviews: reviewCount,
      category: data['category']?.toString(),
      yearsOfExperience: yearsOfExperience,
      skills: skills,
      memberSince: _parseDate(userData?['created_at'] ?? data['created_at']),
      bio: data['bio']?.toString(),
      isVerified: isVerified,
    );
  }

  UserProfileEntity _parseUserAsProfile(Map<String, dynamic> data, String userType) {
    print('📊 Parsing user as profile, keys: ${data.keys.toList()}');
    
    // Parse location (handle PostGIS format if present)
    String? location = data['address']?.toString();
    if (location == null || location.isEmpty) {
      final locationData = data['location'];
      if (locationData is String && locationData.isNotEmpty) {
        if (locationData.startsWith('POINT(')) {
          location = 'Location available';
        } else {
          location = locationData;
        }
      }
    }
    
    print('✨ Parsed user data: name=${data['name']}, photo=${data['photo_url']}');
    
    return UserProfileEntity(
      id: data['id']?.toString() ?? '',
      displayName: data['name']?.toString() ?? 'Unknown User',
      userType: userType,
      profilePhotoUrl: data['photo_url']?.toString(),
      phone: data['phone']?.toString(),
      email: data['email']?.toString(),
      location: location,
      rating: null,
      totalReviews: 0,
      category: null,
      yearsOfExperience: null,
      skills: null,
      memberSince: _parseDate(data['created_at']),
      bio: null,
      isVerified: false,
    );
  }

  DateTime _parseDate(dynamic dateData) {
    if (dateData == null) return DateTime.now();
    if (dateData is DateTime) return dateData;
    if (dateData is String) {
      try {
        return DateTime.parse(dateData);
      } catch (_) {
        return DateTime.now();
      }
    }
    return DateTime.now();
  }

  @override
  Future<Map<String, dynamic>> getUserBookingStats({
    required String userId,
    required String userType,
  }) async {
    try {
      print('📊 Getting booking stats for: $userId ($userType)');
      
      final columnName = userType == 'artisan' ? 'artisan_id' : 'client_id';
      
      final bookings = await supabaseClient
          .from('bookings')
          .select('status')
          .eq(columnName, userId);
      
      print('✅ Found ${bookings.length} bookings');
      
      return {
        'totalBookings': bookings.length,
        'completedBookings': _countByStatus(bookings, ['completed']),
        'pendingBookings': _countByStatus(bookings, ['pending']),
        'cancelledBookings': _countByStatus(bookings, ['cancelled']),
      };
      
    } catch (e) {
      print('❌ Error in getUserBookingStats: $e');
      return _getDefaultStats();
    }
  }

  int _countByStatus(List<dynamic> bookings, List<String> statuses) {
    return bookings.where((b) {
      final status = (b['status'] as String?)?.toLowerCase();
      return status != null && statuses.any((s) => status.contains(s.toLowerCase()));
    }).length;
  }

  Map<String, dynamic> _getDefaultStats() {
    return {
      'totalBookings': 0,
      'completedBookings': 0,
      'pendingBookings': 0,
      'cancelledBookings': 0,
    };
  }
}