// lib/features/trust/presentation/providers/verification_status_provider.dart
// UNIVERSAL VERSION - Works for both artisans and customers

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// ✅ UNIVERSAL Provider - checks users.verified for ALL users (artisans AND customers)
/// This is the MAIN provider you should use everywhere
final userVerificationStatusProvider = StreamProvider.family<bool, String>((ref, userId) {
  final supabase = Supabase.instance.client;
  
  // Listen to changes in users table (works for everyone!)
  final stream = supabase
      .from('users')
      .stream(primaryKey: ['id'])
      .eq('id', userId)
      .map((data) {
        if (data.isEmpty) return false;
        final user = data.first;
        return user['verified'] as bool? ?? false;
      });
  
  return stream;
});

/// Provider to get full verification details
final userVerificationDetailsProvider = FutureProvider.family<Map<String, dynamic>?, String>((ref, userId) async {
  try {
    final supabase = Supabase.instance.client;
    
    final response = await supabase
        .from('identity_verifications')
        .select()
        .eq('user_id', userId)
        .order('submitted_at', ascending: false)
        .limit(1)
        .maybeSingle();
    
    if (response == null) return null;
    
    return {
      'status': response['status'],
      'submittedAt': response['submitted_at'],
      'reviewedAt': response['reviewed_at'],
      'rejectionReason': response['rejection_reason'],
      'docType': response['doc_type'],
    };
  } catch (e) {
    print('Error fetching verification details: $e');
    return null;
  }
});

/// Provider to check verification status for any user type
final userTypeAndVerificationProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, userId) async {
  try {
    final supabase = Supabase.instance.client;
    
    // Get user info
    final userResponse = await supabase
        .from('users')
        .select('user_type, verified')
        .eq('id', userId)
        .single();
    
    final userType = userResponse['user_type'] as String?;
    final isVerified = userResponse['verified'] as bool? ?? false;
    
    // Check if has artisan profile
    final artisanCheck = await supabase
        .from('artisan_profiles')
        .select('user_id')
        .eq('user_id', userId)
        .maybeSingle();
    
    final hasArtisanProfile = artisanCheck != null;
    
    return {
      'userType': userType ?? 'customer',
      'isVerified': isVerified,
      'hasArtisanProfile': hasArtisanProfile,
      'canVerify': true, // Everyone can verify now!
    };
  } catch (e) {
    print('Error fetching user type and verification: $e');
    return {
      'userType': 'unknown',
      'isVerified': false,
      'hasArtisanProfile': false,
      'canVerify': false,
    };
  }
});