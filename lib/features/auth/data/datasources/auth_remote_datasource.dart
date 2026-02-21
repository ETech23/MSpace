import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/error/exceptions.dart'hide AuthException;
import '../models/user_model.dart';

import '../../../../core/services/location_helper.dart';



abstract class AuthRemoteDataSource {
  Future<UserModel> register({
    required String email,
    required String password,
    required String name,
    required String phone,
    required String userType,
  });

  Future<UserModel> login({
    required String email,
    required String password,
  });

  Future<UserModel> loginWithGoogle();
  Future<UserModel> loginWithApple();
  Future<void> logout();
  Future<UserModel?> getCurrentUser();
  Future<bool> isAuthenticated();
  
  Future<UserModel> updateProfile({
    required String userId,
    String? name,
    String? phone,
    double? latitude,
    double? longitude,
    String? address,
  });

  Future<String> uploadProfilePhoto({
    required String userId,
    required String filePath,
  });

  Stream<UserModel?> get authStateChanges;

  Future<void> updateUserType(String userId, String newType);
  Future<void> createArtisanProfileIfNeeded(String userId);
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final SupabaseClient client;

  AuthRemoteDataSourceImpl({required this.client, required Object supabaseClient});

  @override
Future<UserModel> register({
  required String email,
  required String password,
  required String name,
  required String phone,
  required String userType,
}) async {
  try {
    print('📝 Starting registration for: $email');
    
    // 1️⃣ Sign up with Supabase Auth
    final authResponse = await client.auth.signUp(
      email: email,
      password: password,
      data: {
        'name': name,
        'user_type': userType,
      },
    );

    final user = authResponse.user;
    if (user == null) throw const ServerException(message: 'Registration failed');

    final userId = user.id;
    print('✅ Auth user created: $userId');

    // 2️⃣ Wait for trigger to create user record
    await Future.delayed(const Duration(milliseconds: 1000));

    // 3️⃣ Get current location using helper
final locationData = await LocationHelper.getLocationData();
final position = locationData['position'] as Position?;
final address = locationData['address'] as String?;

if (position != null) {
  print('✅ Got location: (${position.latitude}, ${position.longitude})');
  if (address != null) {
    print('✅ Got address: $address');
  }
} 

    // 4️⃣ Create/update user with location data
    final userData = <String, dynamic>{
      'id': userId,
      'name': name,
      'email': email,
      'user_type': userType,
      'phone': phone,
      'created_at': DateTime.now().toIso8601String(),
    };

    // Add location if we got it
    if (position != null) {
      // Store latitude and longitude separately for easier querying
      userData['latitude'] = position.latitude;
      userData['longitude'] = position.longitude;
      
      // Also store as PostGIS point (some queries might need this)
      userData['location'] = 'POINT(${position.longitude} ${position.latitude})';
      print('✅ Saving location: lat=${position.latitude}, lng=${position.longitude}');
    } else {
      print('⚠️ No location data to save');
    }
    
    if (address != null && address.isNotEmpty) {
      userData['address'] = address;
      print('✅ Saving address: $address');
    }

    // Upsert user data
    try {
      await client.from('users').upsert(userData);
      print('✅ User data saved to database');
    } catch (e) {
      print('❌ Error saving user data: $e');
      // Continue even if location save fails
    }

    // 5️⃣ If artisan, create artisan profile
    if (userType == 'artisan') {
      print('👷 Creating artisan profile...');
      
      try {
        final existingProfile = await client
            .from('artisan_profiles')
            .select('id')
            .eq('user_id', userId)
            .maybeSingle();

        if (existingProfile == null) {
          final artisanData = <String, dynamic>{
            'user_id': userId,
            'category': 'General',
            'availability_status': 'available',
          };
          
          // Copy location to artisan profile if available
          if (position != null) {
            artisanData['latitude'] = position.latitude;
            artisanData['longitude'] = position.longitude;
            artisanData['location'] = 'POINT(${position.longitude} ${position.latitude})';
          }
          
          await client.from('artisan_profiles').insert(artisanData);
          print('✅ Artisan profile created with location');
        }
      } catch (e) {
        print('⚠️ Error creating artisan profile: $e');
        // Don't fail registration if profile creation fails
      }
    }

    // 6️⃣ Fetch final user data
    final userResponse = await client
        .from('users')
        .select()
        .eq('id', userId)
        .single();

    print('✅ Registration complete');
    return UserModel.fromJson(userResponse);
    
  } on AuthException catch (e) {
    print('❌ Auth error: ${e.message}');
    throw ServerException(message: e.message);
  } on PostgrestException catch (e) {
    print('❌ Database error: ${e.message}');
    throw ServerException(message: e.message);
  } catch (e) {
    print('❌ Registration error: $e');
    throw ServerException(message: 'Registration failed: ${e.toString()}');
  }
}
  @override
  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    try {
      final authResponse = await client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final user = authResponse.user;
      if (user == null) throw const ServerException(message: 'Login failed');

      final userId = user.id;

      // ✅ Use maybeSingle() to avoid coercion errors
      final userResponse = await client
          .from('users')
          .select()
          .eq('id', userId)
          .maybeSingle();

      // If user profile doesn't exist, create default
      if (userResponse == null) {
        final defaultUser = {
          'id': userId,
          'name': 'User',
          'email': email,
          'user_type': 'customer',  // ✅ CHANGED from 'role' to 'user_type'
          'created_at': DateTime.now().toIso8601String(),
        };
        await client.from('users').insert(defaultUser);

        return UserModel.fromJson(defaultUser);
      }

      return UserModel.fromJson(userResponse);
    } on AuthException catch (e) {
      throw ServerException(message: e.message);
    } on PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      throw ServerException(message: 'Login failed: ${e.toString()}');
    }
  }

  @override
Future<UserModel> loginWithGoogle() async {
  try {
    await client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: 'io.supabase.artisanmarketplace://login-callback',
    );

    // Wait for auth state to change
    final session = await client.auth.onAuthStateChange.firstWhere(
      (event) => event.session != null,
    );

    final supabaseUser = session.session!.user;
    final userId = supabaseUser.id;

    // Fetch or create user profile
    var userResponse = await client
        .from('users')
        .select()
        .eq('id', userId)
        .maybeSingle();

    if (userResponse == null) {
      final newUser = {
        'id': userId,
        'email': supabaseUser.email!,
        'name': supabaseUser.userMetadata?['full_name'] ??
            supabaseUser.email!.split('@')[0],
        'role': 'client',
        'photo_url': supabaseUser.userMetadata?['avatar_url'],
      };
      await client.from('users').insert(newUser);
      return UserModel.fromJson(newUser);
    }

    return UserModel.fromJson(userResponse);
  } on AuthException catch (e) {
    throw ServerException(message: e.message);
  } catch (e) {
    throw ServerException(message: 'Google login failed: ${e.toString()}');
  }
}

  @override
Future<UserModel> loginWithApple() async {
  try {
    await client.auth.signInWithOAuth(
      OAuthProvider.apple,
      redirectTo: 'io.supabase.artisanmarketplace://login-callback',
    );

    final session = await client.auth.onAuthStateChange.firstWhere(
      (event) => event.session != null,
    );

    final supabaseUser = session.session!.user;
    final userId = supabaseUser.id;

    var userResponse = await client
        .from('users')
        .select()
        .eq('id', userId)
        .maybeSingle();

    if (userResponse == null) {
      final newUser = {
        'id': userId,
        'email': supabaseUser.email!,
        'name': supabaseUser.userMetadata?['full_name'] ?? 'User',
        'role': 'client',
      };
      await client.from('users').insert(newUser);
      return UserModel.fromJson(newUser);
    }

    return UserModel.fromJson(userResponse);
  } on AuthException catch (e) {
    throw ServerException(message: e.message);
  } catch (e) {
    throw ServerException(message: 'Apple login failed: ${e.toString()}');
  }
}


  @override
  Future<void> logout() async {
    try {
      await client.auth.signOut();
    } on AuthException catch (e) {
      throw ServerException(message: e.message);
    }
  }

   @override
  Future<UserModel?> getCurrentUser() async {
    try {
      final user = client.auth.currentUser;
      if (user == null) return null;

      final userResponse = await client
          .from('users')
          .select()
          .eq('id', user.id)
          .maybeSingle(); // ✅ safe

      // If profile missing, create default
      if (userResponse == null) {
        final defaultUser = {
          'id': user.id,
          'name': 'User',
          'email': user.email ?? '',
          'role': 'client',
        };
        await client.from('users').insert(defaultUser);
        return UserModel.fromJson(defaultUser);
      }

      return UserModel.fromJson(userResponse);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool> isAuthenticated() async {
    try {
      final session = client.auth.currentSession;
      return session != null;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<UserModel> updateProfile({
    required String userId,
    String? name,
    String? phone,
    double? latitude,
    double? longitude,
    String? address,
  }) async {
    try {
      final updateData = <String, dynamic>{};

      if (name != null) updateData['name'] = name;
      if (phone != null) updateData['phone'] = phone;
      if (address != null) updateData['address'] = address;
      
      // Handle PostGIS point format
      if (latitude != null && longitude != null) {
        updateData['location'] = 'POINT($longitude $latitude)';
      }

      await client.from('users').update(updateData).eq('id', userId);

      final userResponse = await client
          .from('users')
          .select()
          .eq('id', userId)
          .single();

      return UserModel.fromJson(userResponse);
    } on PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      throw ServerException(message: 'Profile update failed: ${e.toString()}');
    }
  }

  @override
  Future<String> uploadProfilePhoto({
    required String userId,
    required String filePath,
  }) async {
    try {
      final fileName = '$userId/${DateTime.now().millisecondsSinceEpoch}.jpg';
      
      await client.storage.from('profile-images').upload(
            fileName,
            File(filePath),
            fileOptions: const FileOptions(
              upsert: true,
            ),
          );

      final publicUrl = client.storage
          .from('profile-images')
          .getPublicUrl(fileName);

      // Update user profile with new photo URL
      await client.from('users').update({
        'photo_url': publicUrl,
      }).eq('id', userId);

      return publicUrl;
    } on StorageException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      throw ServerException(message: 'Photo upload failed: ${e.toString()}');
    }
  }

  @override
  Stream<UserModel?> get authStateChanges {
    return client.auth.onAuthStateChange.asyncMap((event) async {
      final user = event.session?.user;
      if (user == null) return null;

      final userResponse = await client
          .from('users')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (userResponse == null) {
        // create default profile if missing
        final defaultUser = {
          'id': user.id,
          'name': 'User',
          'email': user.email ?? '',
          'role': 'client',
        };
        await client.from('users').insert(defaultUser);
        return UserModel.fromJson(defaultUser);
      }

      return UserModel.fromJson(userResponse);
    });
  }

  @override
Future<void> updateUserType(String userId, String newType) async {
  try {
    print('📝 Updating user type to: $newType for user: $userId');
    
    await client.from('users').update({
      'user_type': newType,
    }).eq('id', userId);
    
    print('✅ User type updated successfully');
  } on PostgrestException catch (e) {
    print('❌ Database error updating user type: ${e.message}');
    throw ServerException(message: e.message);
  } catch (e) {
    print('❌ Error updating user type: $e');
    throw ServerException(message: 'Failed to update user type: ${e.toString()}');
  }
}

@override
Future<void> createArtisanProfileIfNeeded(String userId) async {
  try {
    print('👷 Checking if artisan profile exists for user: $userId');
    
    // Check if artisan profile already exists
    final existingProfile = await client
        .from('artisan_profiles')
        .select('id')
        .eq('user_id', userId)
        .maybeSingle();
    
    if (existingProfile != null) {
      print('⏭️  Artisan profile already exists');
      return;
    }
    
    print('📝 Creating new artisan profile...');
    
    // Get user's location data
    final userData = await client
        .from('users')
        .select('latitude, longitude, location, address')
        .eq('id', userId)
        .single();
    
    // Create artisan profile with location data
    final artisanData = <String, dynamic>{
      'user_id': userId,
      'category': 'General',
      'availability_status': 'available',
      'rating': 0.0,
      'reviews_count': 0,
      'verified': false,
      'premium': false,
      'completed_jobs': 0,
    };
    
    // Copy location data if available
    if (userData['latitude'] != null && userData['longitude'] != null) {
      artisanData['latitude'] = userData['latitude'];
      artisanData['longitude'] = userData['longitude'];
      artisanData['location'] = userData['location'];
    }
    
    if (userData['address'] != null) {
      artisanData['address'] = userData['address'];
    }
    
    await client.from('artisan_profiles').insert(artisanData);
    
    print('✅ Artisan profile created successfully');
  } on PostgrestException catch (e) {
    print('❌ Database error creating artisan profile: ${e.message}');
    throw ServerException(message: e.message);
  } catch (e) {
    print('❌ Error creating artisan profile: $e');
    throw ServerException(message: 'Failed to create artisan profile: ${e.toString()}');
  }
}
}