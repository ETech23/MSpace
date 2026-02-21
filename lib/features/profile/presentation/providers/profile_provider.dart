// lib/features/profile/presentation/providers/profile_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/injection_container.dart';
import '../../../auth/domain/entities/user_entity.dart';

// ✅ FIXED: Import from separate entity files (no hide needed!)
import '../../domain/entities/profile_update_entity.dart';
import '../../domain/entities/notification_settings_entity.dart';
import '../../domain/entities/privacy_settings_entity.dart';
import '../../domain/entities/saved_artisan_entity.dart';

import '../../domain/usecases/update_profile_usecase.dart';
import '../../domain/usecases/upload_profile_photo_usecase.dart';
import '../../domain/usecases/get_notification_settings_usecase.dart';
import '../../domain/usecases/update_notification_settings_usecase.dart';
import '../../domain/usecases/get_privacy_settings_usecase.dart';
import '../../domain/usecases/update_privacy_settings_usecase.dart';
import '../../domain/usecases/get_saved_artisans_usecase.dart';
import '../../domain/usecases/save_artisan_usecase.dart';
import '../../domain/usecases/unsave_artisan_usecase.dart';
import '../../domain/usecases/is_artisan_saved_usecase.dart';

// ✅ ADD THESE USE CASE PROVIDERS
final updateProfileUseCaseProvider = Provider((ref) => getIt<UpdateProfileUseCase>());
final uploadProfilePhotoUseCaseProvider = Provider((ref) => getIt<UploadProfilePhotoUseCase>());
final getNotificationSettingsUseCaseProvider = Provider((ref) => getIt<GetNotificationSettingsUseCase>());
final updateNotificationSettingsUseCaseProvider = Provider((ref) => getIt<UpdateNotificationSettingsUseCase>());
final getPrivacySettingsUseCaseProvider = Provider((ref) => getIt<GetPrivacySettingsUseCase>());
final updatePrivacySettingsUseCaseProvider = Provider((ref) => getIt<UpdatePrivacySettingsUseCase>());
final getSavedArtisansUseCaseProvider = Provider((ref) => getIt<GetSavedArtisansUseCase>());
final saveArtisanUseCaseProvider = Provider((ref) => getIt<SaveArtisanUseCase>());
final unsaveArtisanUseCaseProvider = Provider((ref) => getIt<UnsaveArtisanUseCase>());
final isArtisanSavedUseCaseProvider = Provider((ref) => getIt<IsArtisanSavedUseCase>());


// Profile State
class ProfileState {
  final bool isLoading;
  final String? error;
  final String? successMessage;

  ProfileState({
    this.isLoading = false,
    this.error,
    this.successMessage,
  });

  ProfileState copyWith({
    bool? isLoading,
    String? error,
    String? successMessage,
  }) {
    return ProfileState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      successMessage: successMessage,
    );
  }
}

// Profile Notifier
class ProfileNotifier extends StateNotifier<ProfileState> {
  final UpdateProfileUseCase updateProfileUseCase;
  final UploadProfilePhotoUseCase uploadProfilePhotoUseCase;

  ProfileNotifier({
    required this.updateProfileUseCase,
    required this.uploadProfilePhotoUseCase,
  }) : super(ProfileState());

  Future<UserEntity?> updateProfile(
    String userId,
    ProfileUpdateEntity updates,
  ) async {
    state = state.copyWith(isLoading: true, error: null);

    final result = await updateProfileUseCase(userId, updates);

    return result.fold(
      (failure) {
        state = state.copyWith(
          isLoading: false,
          error: failure.message,
        );
        return null;
      },
      (user) {
        state = state.copyWith(
          isLoading: false,
          successMessage: 'Profile updated successfully',
        );
        return user;
      },
    );
  }

  Future<String?> uploadProfilePhoto(String userId, String filePath) async {
    state = state.copyWith(isLoading: true, error: null);

    final result = await uploadProfilePhotoUseCase(userId, filePath);

    return result.fold(
      (failure) {
        state = state.copyWith(
          isLoading: false,
          error: failure.message,
        );
        return null;
      },
      (photoUrl) {
        state = state.copyWith(
          isLoading: false,
          successMessage: 'Photo uploaded successfully',
        );
        return photoUrl;
      },
    );
  }

  void clearMessages() {
    state = state.copyWith(error: null, successMessage: null);
  }
}

// Settings State
class SettingsState {
  final bool isLoading;
  final String? error;
  final NotificationSettingsEntity? notificationSettings;
  final PrivacySettingsEntity? privacySettings;

  SettingsState({
    this.isLoading = false,
    this.error,
    this.notificationSettings,
    this.privacySettings,
  });

  SettingsState copyWith({
    bool? isLoading,
    String? error,
    NotificationSettingsEntity? notificationSettings,
    PrivacySettingsEntity? privacySettings,
  }) {
    return SettingsState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      notificationSettings: notificationSettings ?? this.notificationSettings,
      privacySettings: privacySettings ?? this.privacySettings,
    );
  }
}

// Settings Notifier
class SettingsNotifier extends StateNotifier<SettingsState> {
  final GetNotificationSettingsUseCase getNotificationSettingsUseCase;
  final UpdateNotificationSettingsUseCase updateNotificationSettingsUseCase;
  final GetPrivacySettingsUseCase getPrivacySettingsUseCase;
  final UpdatePrivacySettingsUseCase updatePrivacySettingsUseCase;

  SettingsNotifier({
    required this.getNotificationSettingsUseCase,
    required this.updateNotificationSettingsUseCase,
    required this.getPrivacySettingsUseCase,
    required this.updatePrivacySettingsUseCase,
  }) : super(SettingsState());

  Future<void> loadNotificationSettings(String userId) async {
    state = state.copyWith(isLoading: true, error: null);

    final result = await getNotificationSettingsUseCase(userId);

    result.fold(
      (failure) {
        state = state.copyWith(isLoading: false, error: failure.message);
      },
      (settings) {
        state = state.copyWith(
          isLoading: false,
          notificationSettings: settings,
        );
      },
    );
  }

  Future<bool> updateNotificationSettings(
    String userId,
    NotificationSettingsEntity settings,
  ) async {
    state = state.copyWith(isLoading: true, error: null);

    final result = await updateNotificationSettingsUseCase(userId, settings);

    return result.fold(
      (failure) {
        state = state.copyWith(isLoading: false, error: failure.message);
        return false;
      },
      (_) {
        state = state.copyWith(
          isLoading: false,
          notificationSettings: settings,
        );
        return true;
      },
    );
  }

  Future<void> loadPrivacySettings(String userId) async {
    state = state.copyWith(isLoading: true, error: null);

    final result = await getPrivacySettingsUseCase(userId);

    result.fold(
      (failure) {
        state = state.copyWith(isLoading: false, error: failure.message);
      },
      (settings) {
        state = state.copyWith(
          isLoading: false,
          privacySettings: settings,
        );
      },
    );
  }

  Future<bool> updatePrivacySettings(
    String userId,
    PrivacySettingsEntity settings,
  ) async {
    state = state.copyWith(isLoading: true, error: null);

    final result = await updatePrivacySettingsUseCase(userId, settings);

    return result.fold(
      (failure) {
        state = state.copyWith(isLoading: false, error: failure.message);
        return false;
      },
      (_) {
        state = state.copyWith(
          isLoading: false,
          privacySettings: settings,
        );
        return true;
      },
    );
  }
}

// Saved Artisans State
class SavedArtisansState {
  final bool isLoading;
  final String? error;
  final List<SavedArtisanEntity> artisans;
  final Set<String> savedArtisanIds;

  SavedArtisansState({
    this.isLoading = false,
    this.error,
    this.artisans = const [],
    this.savedArtisanIds = const {},
  });

  SavedArtisansState copyWith({
    bool? isLoading,
    String? error,
    List<SavedArtisanEntity>? artisans,
    Set<String>? savedArtisanIds,
  }) {
    return SavedArtisansState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      artisans: artisans ?? this.artisans,
      savedArtisanIds: savedArtisanIds ?? this.savedArtisanIds,
    );
  }
}

// Saved Artisans Notifier
class SavedArtisansNotifier extends StateNotifier<SavedArtisansState> {
  final GetSavedArtisansUseCase getSavedArtisansUseCase;
  final SaveArtisanUseCase saveArtisanUseCase;
  final UnsaveArtisanUseCase unsaveArtisanUseCase;
  final IsArtisanSavedUseCase isArtisanSavedUseCase;

  SavedArtisansNotifier({
    required this.getSavedArtisansUseCase,
    required this.saveArtisanUseCase,
    required this.unsaveArtisanUseCase,
    required this.isArtisanSavedUseCase,
  }) : super(SavedArtisansState());

  Future<void> loadSavedArtisans(String userId) async {
  print('📥 Loading saved artisans for user: $userId');
  state = state.copyWith(isLoading: true, error: null);

  final result = await getSavedArtisansUseCase(userId);

  result.fold(
    (failure) {
      print('❌ Error loading saved artisans: ${failure.message}');
      state = state.copyWith(
        isLoading: false, 
        error: failure.message,
        artisans: [],
      );
    },
    (artisans) {
      print('✅ Loaded ${artisans.length} saved artisans');
      // ✅ FIX: Handle null safely
      final artisansList = artisans ?? [];
      final ids = artisansList.map((a) => a.artisanId).toSet();
      state = state.copyWith(
        isLoading: false,
        artisans: artisansList,
        savedArtisanIds: ids,
        error: null,
      );
    },
  );
}

  Future<bool> toggleSaveArtisan(String userId, String artisanId) async {
    final isSaved = state.savedArtisanIds.contains(artisanId);

    if (isSaved) {
      final result = await unsaveArtisanUseCase(userId, artisanId);
      return result.fold(
        (failure) => false,
        (_) {
          final newIds = Set<String>.from(state.savedArtisanIds)
            ..remove(artisanId);
          final newArtisans = state.artisans
              .where((a) => a.artisanId != artisanId)
              .toList();
          state = state.copyWith(
            savedArtisanIds: newIds,
            artisans: newArtisans,
          );
          return true;
        },
      );
    } else {
      final result = await saveArtisanUseCase(userId, artisanId);
      return result.fold(
        (failure) => false,
        (_) {
          final newIds = Set<String>.from(state.savedArtisanIds)
            ..add(artisanId);
          state = state.copyWith(savedArtisanIds: newIds);
          // Reload the full list to get artisan details
          loadSavedArtisans(userId);
          return true;
        },
      );
    }
  }

  bool isArtisanSaved(String artisanId) {
    return state.savedArtisanIds.contains(artisanId);
  }
}

// Providers
final profileProvider = StateNotifierProvider<ProfileNotifier, ProfileState>((ref) {
  return ProfileNotifier(
    updateProfileUseCase: ref.watch(updateProfileUseCaseProvider),
    uploadProfilePhotoUseCase: ref.watch(uploadProfilePhotoUseCaseProvider),
  );
});

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  return SettingsNotifier(
    getNotificationSettingsUseCase: ref.watch(getNotificationSettingsUseCaseProvider),
    updateNotificationSettingsUseCase: ref.watch(updateNotificationSettingsUseCaseProvider),
    getPrivacySettingsUseCase: ref.watch(getPrivacySettingsUseCaseProvider),
    updatePrivacySettingsUseCase: ref.watch(updatePrivacySettingsUseCaseProvider),
  );
});

final savedArtisansProvider = StateNotifierProvider<SavedArtisansNotifier, SavedArtisansState>((ref) {
  return SavedArtisansNotifier(
    getSavedArtisansUseCase: ref.watch(getSavedArtisansUseCaseProvider),
    saveArtisanUseCase: ref.watch(saveArtisanUseCaseProvider),
    unsaveArtisanUseCase: ref.watch(unsaveArtisanUseCaseProvider),
    isArtisanSavedUseCase: ref.watch(isArtisanSavedUseCaseProvider),
  );
});