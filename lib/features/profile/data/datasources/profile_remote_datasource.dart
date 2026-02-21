// lib/features/profile/data/datasources/profile_remote_datasource.dart
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/error/exceptions.dart';
import '../../../auth/data/models/user_model.dart';
import '../models/notification_settings_model.dart';
import '../models/privacy_settings_model.dart';
import '../models/saved_artisan_model.dart';
import '../../domain/entities/profile_update_entity.dart';

abstract class ProfileRemoteDataSource {
  Future<UserModel> updateProfile(String userId, ProfileUpdateEntity updates);
  Future<String> uploadProfilePhoto(String userId, String filePath);
  Future<NotificationSettingsModel> getNotificationSettings(String userId);
  Future<void> updateNotificationSettings(String userId, NotificationSettingsModel settings);
  Future<PrivacySettingsModel> getPrivacySettings(String userId);
  Future<void> updatePrivacySettings(String userId, PrivacySettingsModel settings);
  Future<List<SavedArtisanModel>> getSavedArtisans(String userId);
  Future<void> saveArtisan(String userId, String artisanId);
  Future<void> unsaveArtisan(String userId, String artisanId);
  Future<bool> isArtisanSaved(String userId, String artisanId);
}

class ProfileRemoteDataSourceImpl implements ProfileRemoteDataSource {
  final SupabaseClient supabaseClient;

  ProfileRemoteDataSourceImpl({required this.supabaseClient});

  @override
  Future<UserModel> updateProfile(
    String userId,
    ProfileUpdateEntity updates,
  ) async {
    try {
      final updateData = <String, dynamic>{};
      
      if (updates.name != null) updateData['name'] = updates.name;
      if (updates.phone != null) updateData['phone'] = updates.phone;
      if (updates.address != null) updateData['address'] = updates.address;
      if (updates.photoUrl != null) updateData['photo_url'] = updates.photoUrl;
      
      // Handle location
      if (updates.latitude != null && updates.longitude != null) {
        updateData['latitude'] = updates.latitude;
        updateData['longitude'] = updates.longitude;
        updateData['location'] = 'POINT(${updates.longitude} ${updates.latitude})';
      }
      
      updateData['updated_at'] = DateTime.now().toIso8601String();

      final response = await supabaseClient
          .from('users')
          .update(updateData)
          .eq('id', userId)
          .select()
          .single();

      return UserModel.fromJson(response);
    } catch (e) {
      throw ServerException(message: 'Failed to update profile: $e');
    }
  }

  @override
  Future<String> uploadProfilePhoto(String userId, String filePath) async {
    try {
      final file = File(filePath);
      final bytes = await file.readAsBytes();
      final fileExt = filePath.split('.').last;
      final fileName = '${userId}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      final storagePath = 'profiles/$fileName';

      await supabaseClient.storage.from('avatars').uploadBinary(
            storagePath,
            bytes,
            fileOptions: FileOptions(
              contentType: 'image/$fileExt',
              upsert: true,
            ),
          );

      final publicUrl = supabaseClient.storage.from('avatars').getPublicUrl(storagePath);

      // Update user photo_url
      await supabaseClient
          .from('users')
          .update({'photo_url': publicUrl})
          .eq('id', userId);

      return publicUrl;
    } catch (e) {
      throw ServerException(message: 'Failed to upload photo: $e');
    }
  }

  @override
  Future<NotificationSettingsModel> getNotificationSettings(
    String userId,
  ) async {
    try {
      final response = await supabaseClient
          .from('user_settings')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) {
        // Return default settings
        return const NotificationSettingsModel(
          pushNotifications: true,
          emailNotifications: true,
          bookingUpdates: true,
          promotions: false,
          newMessages: true,
        );
      }

      return NotificationSettingsModel.fromJson(response);
    } catch (e) {
      throw ServerException(message: 'Failed to get notification settings: $e');
    }
  }

  @override
  Future<void> updateNotificationSettings(
    String userId,
    NotificationSettingsModel settings,
  ) async {
    try {
      await supabaseClient.from('user_settings').upsert({
        'user_id': userId,
        ...settings.toJson(),
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw ServerException(message: 'Failed to update notification settings: $e');
    }
  }

  @override
  Future<PrivacySettingsModel> getPrivacySettings(String userId) async {
    try {
      final response = await supabaseClient
          .from('user_settings')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) {
        return const PrivacySettingsModel(
          profileVisible: true,
          showEmail: false,
          showPhone: true,
          showAddress: false,
        );
      }

      return PrivacySettingsModel.fromJson(response);
    } catch (e) {
      throw ServerException(message: 'Failed to get privacy settings: $e');
    }
  }

  @override
  Future<void> updatePrivacySettings(
    String userId,
    PrivacySettingsModel settings,
  ) async {
    try {
      await supabaseClient.from('user_settings').upsert({
        'user_id': userId,
        ...settings.toJson(),
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw ServerException(message: 'Failed to update privacy settings: $e');
    }
  }

 @override
Future<List<SavedArtisanModel>> getSavedArtisans(String userId) async {
  try {
    final response = await supabaseClient
        .from('saved_artisans')
        .select('''
          id,
          artisan_id,
          saved_at
        ''')
        .eq('user_id', userId)
        .order('saved_at', ascending: false);

    if (response.isEmpty) return [];

    final artisanIds = (response as List)
        .map((item) => item['artisan_id'] as String)
        .toList();

    // Fetch artisan details
    final artisansResponse = await supabaseClient
        .from('users')
        .select('''
          id,
          name,
          photo_url
        ''')
        .inFilter('id', artisanIds);

    final profilesResponse = await supabaseClient
        .from('artisan_profiles')
        .select('''
          user_id,
          category,
          rating
        ''')
        .inFilter('user_id', artisanIds);

    // Create maps for quick lookup
    final usersMap = {
      for (var item in artisansResponse as List)
        item['id']: item
    };
    
    final profilesMap = {
      for (var item in profilesResponse as List)
        item['user_id']: item
    };

    // Combine the data
    return (response).map((saved) {
      final artisanId = saved['artisan_id'] as String;
      final user = usersMap[artisanId];
      final profile = profilesMap[artisanId];
      
      if (user == null) return null;
      
      return SavedArtisanModel(
        id: saved['id'],
        userId: userId,
        artisanId: artisanId,
        artisanName: user['name'] ?? 'Unknown',
        artisanPhoto: user['photo_url'],
        category: profile?['category'] ?? 'General',
        rating: (profile?['rating'] as num?)?.toDouble() ?? 0.0,
        savedAt: DateTime.parse(saved['saved_at']),
      );
    }).whereType<SavedArtisanModel>().toList();
  } catch (e) {
    print('❌ Error getting saved artisans: $e');
    throw ServerException(message: 'Failed to get saved artisans: $e');
  }
}

 @override
Future<void> saveArtisan(String userId, String artisanId) async {
  try {
    print('🔵 Attempting to save artisan:');
    print('   userId: $userId');
    print('   artisanId: $artisanId');
    
    final response = await supabaseClient
        .from('saved_artisans')
        .insert({
          'user_id': userId,
          'artisan_id': artisanId,
          'saved_at': DateTime.now().toIso8601String(),
        })
        .select();
    
    print('✅ Save successful: $response');
  } catch (e) {
    print('❌ Save error details: $e');
    print('❌ Error type: ${e.runtimeType}');
    throw ServerException(message: 'Failed to save artisan: $e');
  }
}

  @override
  Future<void> unsaveArtisan(String userId, String artisanId) async {
    try {
      await supabaseClient
          .from('saved_artisans')
          .delete()
          .eq('user_id', userId)
          .eq('artisan_id', artisanId);
    } catch (e) {
      throw ServerException(message: 'Failed to unsave artisan: $e');
    }
  }

  @override
  Future<bool> isArtisanSaved(String userId, String artisanId) async {
    try {
      final response = await supabaseClient
          .from('saved_artisans')
          .select()
          .eq('user_id', userId)
          .eq('artisan_id', artisanId)
          .maybeSingle();

      return response != null;
    } catch (e) {
      throw ServerException(message: 'Failed to check saved status: $e');
    }
  }
}