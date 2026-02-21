// lib/features/profile/presentation/providers/artisan_profile_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../home/domain/entities/artisan_entity.dart';
import '../../../home/data/models/artisan_model.dart';

// State class for artisan profile
class ArtisanProfileState {
  final ArtisanEntity? profile;
  final bool isLoading;
  final String? error;

  const ArtisanProfileState({
    this.profile,
    this.isLoading = false,
    this.error,
  });

  ArtisanProfileState copyWith({
    ArtisanEntity? profile,
    bool? isLoading,
    String? error,
  }) {
    return ArtisanProfileState(
      profile: profile ?? this.profile,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// Notifier for managing artisan profile
class ArtisanProfileNotifier extends StateNotifier<ArtisanProfileState> {
  final String userId;
  
  ArtisanProfileNotifier(this.userId) : super(const ArtisanProfileState()) {
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final supabase = Supabase.instance.client;
      
      final artisanResponse = await supabase
          .from('artisan_profiles')
          .select('*')
          .eq('user_id', userId)
          .maybeSingle();
      
      if (artisanResponse == null) {
        state = state.copyWith(isLoading: false, profile: null);
        return;
      }
      
      // Get user data
      final userResponse = await supabase.rpc(
        'get_users_with_location',
        params: {'user_ids': [userId]},
      );
      
      if ((userResponse as List).isEmpty) {
        state = state.copyWith(isLoading: false, profile: null);
        return;
      }
      
      final userMap = (userResponse).first as Map<String, dynamic>;
      
      final mergedJson = <String, dynamic>{
        ...artisanResponse,
        'users': userMap,
      };
      
      final profile = ArtisanModel.fromJson(mergedJson).toEntity();
      
      state = state.copyWith(
        profile: profile,
        isLoading: false,
        error: null,
      );
    } catch (e) {
      print('Error loading artisan profile: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load profile: $e',
      );
    }
  }

  Future<bool> updateArtisanProfile(Map<String, dynamic> updates) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final supabase = Supabase.instance.client;
      
      // Remove null values
      updates.removeWhere((key, value) => value == null);
      
      if (updates.isEmpty) {
        state = state.copyWith(isLoading: false);
        return true; // Nothing to update
      }
      
      // Update artisan_profiles table
      await supabase
          .from('artisan_profiles')
          .update(updates)
          .eq('user_id', userId);
      
      print('✅ Artisan profile updated successfully');
      
      // Reload the profile
      await _loadProfile();
      
      return true;
    } catch (e) {
      print('❌ Error updating artisan profile: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to update profile: $e',
      );
      return false;
    }
  }

  Future<void> refresh() async {
    await _loadProfile();
  }
}

// StateNotifierProvider for artisan profile
final artisanProfileProvider = 
    StateNotifierProvider.family<ArtisanProfileNotifier, ArtisanProfileState, String>(
  (ref, userId) => ArtisanProfileNotifier(userId),
);