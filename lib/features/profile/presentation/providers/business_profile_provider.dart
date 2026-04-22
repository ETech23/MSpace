import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BusinessProfileState {
  final Map<String, dynamic>? profile;
  final List<Map<String, dynamic>> items;
  final bool isLoading;
  final String? error;

  const BusinessProfileState({
    this.profile,
    this.items = const [],
    this.isLoading = false,
    this.error,
  });

  BusinessProfileState copyWith({
    Map<String, dynamic>? profile,
    List<Map<String, dynamic>>? items,
    bool? isLoading,
    String? error,
  }) {
    return BusinessProfileState(
      profile: profile ?? this.profile,
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class BusinessProfileNotifier extends StateNotifier<BusinessProfileState> {
  BusinessProfileNotifier(this.userId) : super(const BusinessProfileState()) {
    _loadProfile();
  }

  final String userId;

  Future<void> _loadProfile() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final supabase = Supabase.instance.client;
      final profile = await supabase
          .from('business_profiles')
          .select('*')
          .eq('user_id', userId)
          .maybeSingle();

      final items = await supabase
          .from('business_items')
          .select('*')
          .eq('business_id', userId)
          .order('created_at', ascending: false);

      state = state.copyWith(
        profile: profile,
        items: (items as List).cast<Map<String, dynamic>>(),
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load business profile: $e',
      );
    }
  }

  Future<bool> updateBusinessProfile(Map<String, dynamic> updates) async {
    try {
      final supabase = Supabase.instance.client;
      updates.removeWhere((key, value) => value == null);
      if (updates.isEmpty) return true;
      await supabase
          .from('business_profiles')
          .update(updates)
          .eq('user_id', userId);
      await _loadProfile();
      return true;
    } catch (e) {
      state = state.copyWith(error: 'Failed to update business profile: $e');
      return false;
    }
  }

  Future<void> addBusinessItem({
    required String name,
    String? description,
    String? price,
  }) async {
    final supabase = Supabase.instance.client;
    await supabase.from('business_items').insert({
      'business_id': userId,
      'name': name,
      'description': description,
      'price': price,
    });
    await _loadProfile();
  }

  Future<void> deleteBusinessItem(int itemId) async {
    final supabase = Supabase.instance.client;
    await supabase
        .from('business_items')
        .delete()
        .eq('id', itemId);
    await _loadProfile();
  }

  Future<void> toggleItemActive(int itemId, bool next) async {
    final supabase = Supabase.instance.client;
    await supabase
        .from('business_items')
        .update({'is_active': next})
        .eq('id', itemId);
    await _loadProfile();
  }

  Future<void> refresh() async => _loadProfile();
}

final businessProfileProvider = StateNotifierProvider.family<
    BusinessProfileNotifier, BusinessProfileState, String>(
  (ref, userId) => BusinessProfileNotifier(userId),
);
