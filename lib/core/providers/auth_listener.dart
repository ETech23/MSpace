import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/auth/presentation/providers/auth_provider.dart' as app_auth;
import '../../features/auth/domain/entities/user_entity.dart';

final authListenerProvider = Provider<void>((ref) {
  final supabase = Supabase.instance.client;

  // Listen to auth state changes
  supabase.auth.onAuthStateChange.listen((data) {
    final session = data.session;
    
    if (session != null) {
      // User is logged in - update auth state
      final user = session.user;
      
      ref.read(app_auth.authProvider.notifier).state = app_auth.AuthState(
        isAuthenticated: true,
        user: UserEntity(
          id: user.id,
          email: user.email ?? '',
          name: user.userMetadata?['name'] ?? user.email?.split('@').first ?? 'User',
          phone: user.userMetadata?['phone'] as String?,
          photoUrl: user.userMetadata?['photo_url'] as String?,
          userType: user.userMetadata?['role'] as String? ?? 'client',
          createdAt: DateTime.parse(user.createdAt),
        ),
      );
    } else {
      // User is logged out
      ref.read(app_auth.authProvider.notifier).state = app_auth.AuthState();
    }
  });

  return;
});