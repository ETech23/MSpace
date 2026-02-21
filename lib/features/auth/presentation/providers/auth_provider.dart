import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/services/notification_listener_service.dart'; // ✅ Add this
import '../../domain/usecases/login_usecase.dart';
import '../../domain/usecases/register_usecase.dart';
import '../../domain/usecases/logout_usecase.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../../../core/services/push_notification_service.dart';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

// Provider for use cases
final loginUseCaseProvider = Provider((ref) => getIt<LoginUseCase>());
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
  final RegisterUseCase registerUseCase;
  final LogoutUseCase logoutUseCase;
  final AuthRepository authRepository;
  final NotificationListenerService _notificationListener = NotificationListenerService(); // ✅ Add this

  AuthNotifier({
    required this.loginUseCase,
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


  Future<void> register({
    required String email,
    required String password,
    required String name,
    required String phone,
    required String userType,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    final result = await registerUseCase(
      email: email,
      password: password,
      name: name,
      phone: phone,
      userType: userType,
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
        // ✅ Start notification listener after successful registration
        _startNotificationListener(user.id);
         _saveFCMToken(user.id);
        _listenToTokenRefresh(user.id);
      },
    );
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
        state = AuthState(isInitialized: true);
      },
    );
  }

  Future<void> switchUserType(String newType, String userId) async {
    try {
      print('🔄 Switching user type to: $newType');
      
      // Update user type in users table
      await authRepository.updateUserType(userId, newType);
      
      // If switching to artisan, create artisan profile if it doesn't exist
      if (newType == 'artisan') {
        await authRepository.createArtisanProfileIfNeeded(userId);
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
}

// Auth provider
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(
    loginUseCase: ref.watch(loginUseCaseProvider),
    registerUseCase: ref.watch(registerUseCaseProvider),
    logoutUseCase: ref.watch(logoutUseCaseProvider),
    authRepository: ref.watch(authRepositoryProvider),
  );
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