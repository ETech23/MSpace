// lib/features/profile/presentation/providers/user_profile_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/injection_container.dart';
import '../../domain/entities/user_profile_entity.dart';
import '../../domain/usecases/get_user_profile_usecase.dart';
import '../../domain/usecases/get_user_booking_stats_usecase.dart';

// State
class UserProfileState {
  final bool isLoading;
  final UserProfileEntity? userProfile;
  final Map<String, dynamic>? stats;
  final String? error;

  UserProfileState({
    this.isLoading = false,
    this.userProfile,
    this.stats,
    this.error,
  });

  UserProfileState copyWith({
    bool? isLoading,
    UserProfileEntity? userProfile,
    Map<String, dynamic>? stats,
    String? error,
    bool clearError = false,
  }) {
    return UserProfileState(
      isLoading: isLoading ?? this.isLoading,
      userProfile: userProfile ?? this.userProfile,
      stats: stats ?? this.stats,
      error: clearError ? null : error,
    );
  }
}

// Notifier
class UserProfileNotifier extends StateNotifier<UserProfileState> {
  final GetUserProfileUseCase getUserProfileUseCase;
  final GetUserBookingStatsUseCase getUserBookingStatsUseCase;

  UserProfileNotifier({
    required this.getUserProfileUseCase,
    required this.getUserBookingStatsUseCase,
  }) : super(UserProfileState());

  Future<void> loadUserProfile({
    required String userId,
    required String userType,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    // Load profile
    final profileResult = await getUserProfileUseCase(
      userId: userId,
      userType: userType,
    );

    profileResult.fold(
      (failure) {
        state = state.copyWith(
          isLoading: false,
          error: failure.message,
        );
      },
      (profile) async {
        // Load stats
        final statsResult = await getUserBookingStatsUseCase(
          userId: userId,
          userType: userType,
        );

        statsResult.fold(
          (failure) {
            // Continue with profile even if stats fail
            state = state.copyWith(
              isLoading: false,
              userProfile: profile,
            );
          },
          (stats) {
            state = state.copyWith(
              isLoading: false,
              userProfile: profile,
              stats: stats,
            );
          },
        );
      },
    );
  }

  void clearProfile() {
    state = state.copyWith(
      userProfile: null,
      stats: null,
      clearError: true,
    );
  }
}

// Add these providers to your existing provider file or create new ones
final getUserProfileUseCaseProvider = Provider((ref) => getIt<GetUserProfileUseCase>());
final getUserBookingStatsUseCaseProvider = Provider((ref) => getIt<GetUserBookingStatsUseCase>());

final userProfileProvider = StateNotifierProvider<UserProfileNotifier, UserProfileState>((ref) {
  return UserProfileNotifier(
    getUserProfileUseCase: ref.watch(getUserProfileUseCaseProvider),
    getUserBookingStatsUseCase: ref.watch(getUserBookingStatsUseCaseProvider),
  );
});