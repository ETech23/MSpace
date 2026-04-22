import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/services/notification_listener_service.dart'; // ✅ Add this
import '../../domain/usecases/login_usecase.dart';
import '../../domain/usecases/login_with_google_usecase.dart';
import '../../domain/usecases/register_usecase.dart';
import '../../domain/usecases/logout_usecase.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../../../core/services/push_notification_service.dart';
import '../../../../core/services/install_referrer_service.dart';
import '../../../../core/services/analytics_service.dart';
import '../../../../core/providers/connectivity_provider.dart';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

// Provider for use cases
final loginUseCaseProvider = Provider((ref) => getIt<LoginUseCase>());
final loginWithGoogleUseCaseProvider =
    Provider((ref) => getIt<LoginWithGoogleUseCase>());
final registerUseCaseProvider = Provider((ref) => getIt<RegisterUseCase>());
final logoutUseCaseProvider = Provider((ref) => getIt<LogoutUseCase>());
final authRepositoryProvider = Provider((ref) => getIt<AuthRepository>());

// Auth state
class AuthState {
  final bool isLoading;
  final bool isAuthenticated;
  final UserEntity? user;
  final String? error;
  final bool isInitialized;

  AuthState({
    this.isLoading = false,
    this.isAuthenticated = false,
    this.user,
    this.error,
    this.isInitialized = false,
  });

  AuthState copyWith({
    bool? isLoading,
    bool? isAuthenticated,
    UserEntity? user,
    String? error,
    bool? isInitialized,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      user: user ?? this.user,
      error: error,
      isInitialized: isInitialized ?? this.isInitialized,
    );
  }
}

// Auth notifier
class AuthNotifier extends StateNotifier<AuthState> {
  final LoginUseCase loginUseCase;
  final LoginWithGoogleUseCase loginWithGoogleUseCase;
  final RegisterUseCase registerUseCase;
  final LogoutUseCase logoutUseCase;
  final AuthRepository authRepository;
  final NotificationListenerService _notificationListener = NotificationListenerService(); // ✅ Add this

  AuthNotifier({
    required this.loginUseCase,
    required this.loginWithGoogleUseCase,
    required this.registerUseCase,
    required this.logoutUseCase,
    required this.authRepository,
  }) : super(AuthState()) {
    _checkExistingSession();
  }

  Future<void> _saveFCMToken(String userId) async {
  if (kIsWeb) {
    print('⚠️ FCM not supported on web');
    return;
  }

  try {
    print('🔔 Starting FCM token save for user: $userId');
    
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null) {
      print('⚠️ FCM token is null');
      return;
    }

    print('📱 Got FCM token: ${token.substring(0, 30)}...');

    final supabase = Supabase.instance.client;
    
    // ✅ Use .select() to check if upsert worked
    final result = await supabase.from('fcm_tokens').upsert({
      'user_id': userId,
      'token': token,
      'device_type': Platform.isAndroid ? 'android' : 'ios',
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'user_id,token').select(); // ✅ Add onConflict
    
    print('✅ FCM token saved: ${result.length} rows affected');
    
  } on PostgrestException catch (e) {
    // ✅ Ignore duplicate key errors - they're fine
    if (e.code == '23505') {
      print('ℹ️ FCM token already exists (this is OK)');
    } else {
      print('❌ Supabase error saving FCM token:');
      print('   Code: ${e.code}');
      print('   Message: ${e.message}');
    }
  } catch (e) {
    print('❌ Error saving FCM token: $e');
  }
}

Future<void> _deleteFCMToken() async {
  if (kIsWeb) return;

  try {
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null) return;

    final supabase = Supabase.instance.client;
    await supabase.from('fcm_tokens').delete().eq('token', token);

    print('🗑 FCM token deleted');
  } catch (e) {
    print('❌ Error deleting FCM token: $e');
  }
}

void _listenToTokenRefresh(String userId) {
  if (kIsWeb) return;

  FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
    print('🔄 FCM token refreshed');
    _saveFCMToken(userId);
  });
}



  Future<void> _checkExistingSession() async {
    state = state.copyWith(isLoading: true);

    try {
      final isAuth = await authRepository.isAuthenticated();
      
      if (isAuth) {
        final result = await authRepository.getCurrentUser();
        
        result.fold(
          (failure) {
            state = AuthState(isInitialized: true);
          },
          (user) {
            if (user != null) {
              state = AuthState(
                isAuthenticated: true,
                user: user,
                isInitialized: true,
              );
              // ✅ Start notification listener for existing session
              _startNotificationListener(user.id);
               _saveFCMToken(user.id);
              _listenToTokenRefresh(user.id);
              AnalyticsService.instance.setUser(
                userId: user.id,
                userType: user.userType,
              );
              AnalyticsService.instance.logEvent(
                'session_restore',
                params: {'user_type': user.userType},
              );
              AnalyticsService.instance.maybeSendProfileViewDigest();
            } else {
              state = AuthState(isInitialized: true);
            }
          },
        );
      } else {
        state = AuthState(isInitialized: true);
      }
    } catch (e) {
      state = AuthState(isInitialized: true);
    }
  }

  Future<void> recheckSession() async {
    if (state.isLoading) return;
    if (state.isAuthenticated && state.user != null) return;
    await _checkExistingSession();
  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    final result = await loginUseCase(
      email: email,
      password: password,
    );

    result.fold(
      (failure) {
        state = state.copyWith(
          isLoading: false,
          isAuthenticated: false,
          error: failure.message,
        );
      },
      (user) {
        state = state.copyWith(
          isLoading: false,
          isAuthenticated: true,
          user: user,
          error: null,
          isInitialized: true,
        );
        // ✅ Start notification listener after successful login
        _startNotificationListener(user.id);
         // Initialize push notifications after successful login
        _initializePushNotifications(user.id);
        _saveFCMToken(user.id);
        _listenToTokenRefresh(user.id);
        _sendWelcomeNotificationIfNeeded(user.id);
        AnalyticsService.instance.setUser(
          userId: user.id,
          userType: user.userType,
        );
        AnalyticsService.instance.logEvent(
          'login',
          params: {'method': 'email', 'user_type': user.userType},
        );
        AnalyticsService.instance.maybeSendProfileViewDigest();
      },
    );
  }

  Future<void> loginWithGoogle({String? preferredUserType}) async {
    state = state.copyWith(isLoading: true, error: null);

    final result = await loginWithGoogleUseCase(
      preferredUserType: preferredUserType,
    );

    result.fold(
      (failure) {
        state = state.copyWith(
          isLoading: false,
          isAuthenticated: false,
          error: failure.message,
        );
      },
      (user) {
        state = state.copyWith(
          isLoading: false,
          isAuthenticated: true,
          user: user,
          error: null,
          isInitialized: true,
        );
        _startNotificationListener(user.id);
        _initializePushNotifications(user.id);
        _saveFCMToken(user.id);
        _listenToTokenRefresh(user.id);
        _sendWelcomeNotificationIfNeeded(user.id);
        AnalyticsService.instance.setUser(
          userId: user.id,
          userType: user.userType,
        );
        AnalyticsService.instance.logEvent(
          'login',
          params: {'method': 'google', 'user_type': user.userType},
        );
        AnalyticsService.instance.maybeSendProfileViewDigest();
      },
    );
  }

  Future<void> _initializePushNotifications(String userId) async {
    try {
      await PushNotificationService().initialize(
        userId: userId,
        onNotificationTap: (data) {
          // Handle notification tap - navigate to chat
          final conversationId = data['conversation_id'];
          if (conversationId != null) {
            // Navigate to chat screen
            // You can use a global navigator key or state management
            print('📱 Navigate to conversation: $conversationId');
          }
        },
      );
    } catch (e) {
      print('❌ Error initializing push notifications: $e');
    }
  }


  Future<bool> register({
    required String email,
    required String password,
    required String name,
    required String phone,
    required String userType,
    String? referralCode,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    final manualCode = referralCode?.trim();
    final autoCode = manualCode == null || manualCode.isEmpty
        ? await InstallReferrerService().takePendingReferralCode()
        : null;
    final resolvedCode = manualCode != null && manualCode.isNotEmpty
        ? manualCode
        : autoCode;
    final referralSource = manualCode != null && manualCode.isNotEmpty
        ? 'manual'
        : (autoCode != null ? 'install_referrer' : null);

    final result = await registerUseCase(
      email: email,
      password: password,
      name: name,
      phone: phone,
      userType: userType,
      referralCode: resolvedCode,
      referralSource: referralSource,
    );

    bool success = false;
    result.fold(
      (failure) {
        state = state.copyWith(
          isLoading: false,
          isAuthenticated: false,
          error: failure.message,
        );
        success = false;
      },
      (user) {
        // With autoconfirm disabled, no session exists yet —
        // user must confirm email first. Do NOT set isAuthenticated: true.
        state = state.copyWith(
          isLoading: false,
          isAuthenticated: false,
          error: null,
          isInitialized: true,
        );
        AnalyticsService.instance.logEvent(
          'sign_up',
          params: {'method': 'email', 'user_type': userType},
        );
        success = true;
      },
    );
    return success;
  }

  Future<void> _sendWelcomeNotificationIfNeeded(String userId) async {
    try {
      final supabase = Supabase.instance.client;
      final existing = await supabase
          .from('notifications')
          .select('id,data')
          .eq('user_id', userId)
          .eq('type', 'system')
          .order('created_at', ascending: false)
          .limit(20);

      final hasWelcome = (existing as List).any((row) {
        final data = (row as Map<String, dynamic>)['data'];
        if (data is Map<String, dynamic>) {
          return data['subType'] == 'welcome';
        }
        return false;
      });
      if (hasWelcome) return;

      await supabase.from('notifications').insert({
        'user_id': userId,
        'title': 'Welcome to MSpace',
        'body': 'Complete your profile to enjoy the full benefits of the app.',
        'type': 'system',
        'read': false,
        'data': {
          'action': 'open_edit_profile',
          'subType': 'welcome',
        },
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('❌ Failed to send welcome notification: $e');
    }
  }

  Future<void> logout() async {
    state = state.copyWith(isLoading: true, error: null);
    await _deleteFCMToken();

    final result = await logoutUseCase.call();

    result.fold(
      (failure) {
        state = state.copyWith(
          isLoading: false,
          error: failure.message,
        );
      },
      (_) {
        // ✅ Stop notification listener on logout
        _notificationListener.stopListening();
        AnalyticsService.instance.logEvent('logout');
        AnalyticsService.instance.clearUser();
        state = AuthState(isInitialized: true);
      },
    );
  }

  Future<void> switchUserType(String newType, String userId) async {
    try {
      print('🔄 Switching user type to: $newType');
      
      // Update user type in users table
      await authRepository.updateUserType(userId, newType);
      
      // If switching to artisan/business, create profiles if needed
      if (newType == 'artisan' || newType == 'business') {
        await authRepository.createArtisanProfileIfNeeded(userId);
      }
      if (newType == 'business') {
        await authRepository.createBusinessProfileIfNeeded(userId);
      }
      
      // Reload user data
      final result = await authRepository.getCurrentUser();
      
      result.fold(
        (failure) {
          print('❌ Failed to reload user: ${failure.message}');
          throw Exception(failure.message);
        },
        (updatedUser) {
          if (updatedUser != null) {
            state = state.copyWith(user: updatedUser);
            print('✅ Successfully switched to $newType');
            AnalyticsService.instance.setUser(
              userId: updatedUser.id,
              userType: updatedUser.userType,
            );
            AnalyticsService.instance.logEvent(
              'switch_user_type',
              params: {'user_type': updatedUser.userType},
            );
          }
        },
      );
    } catch (e) {
      print('❌ Error switching user type: $e');
      rethrow;
    }
  }

  Future<void> refreshUser() async {
    if (!state.isAuthenticated) return;

    final result = await authRepository.getCurrentUser();
    
    result.fold(
      (failure) {
        state = AuthState(isInitialized: true);
      },
      (user) {
        if (user != null) {
          state = state.copyWith(user: user);
        }
      },
    );
  }

  // ✅ Start notification listener
  void _startNotificationListener(String userId) {
    print('🔔 Starting notification listener for user: $userId');
    _notificationListener.startListening(userId);
  }

  Future<bool> requestAccountDeletion({required String reason}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await authRepository.requestAccountDeletion(reason: reason);
      _notificationListener.stopListening();
      state = AuthState(isInitialized: true);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to process account deletion request.',
      );
      return false;
    }
  }
}

// Auth provider
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final notifier = AuthNotifier(
    loginUseCase: ref.watch(loginUseCaseProvider),
    loginWithGoogleUseCase: ref.watch(loginWithGoogleUseCaseProvider),
    registerUseCase: ref.watch(registerUseCaseProvider),
    logoutUseCase: ref.watch(logoutUseCaseProvider),
    authRepository: ref.watch(authRepositoryProvider),
  );

  ref.listen<AsyncValue<bool>>(isOnlineStreamProvider, (previous, next) {
    final isOnline = next.value;
    if (isOnline == true) {
      notifier.recheckSession();
    }
  });

  return notifier;
});

// Current user provider
final currentUserProvider = Provider<UserEntity?>((ref) {
  final authState = ref.watch(authProvider);
  return authState.user;
});

// Is initialized provider
final isAuthInitializedProvider = Provider<bool>((ref) {
  final authState = ref.watch(authProvider);
  return authState.isInitialized;
});

// Current user's moderation status (active/suspended/blocked)
final currentUserModerationStatusProvider = StreamProvider<String?>((ref) {
  final authState = ref.watch(authProvider);
  final user = authState.user;
  if (user == null) {
    return Stream.value(null);
  }

  final supabase = Supabase.instance.client;
  return supabase
      .from('users')
      .stream(primaryKey: ['id'])
      .eq('id', user.id)
      .map((rows) {
        if (rows.isEmpty) return null;
        final row = rows.first;
        return (row['moderation_status'] as String?) ?? 'active';
      });
});
