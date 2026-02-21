// lib/core/di/injection_container.dart

import 'package:artisan_marketplace/features/profile/domain/usecases/get_user_booking_stats_usecase.dart';
import 'package:artisan_marketplace/features/profile/domain/usecases/get_user_profile_usecase.dart';

import 'package:artisan_marketplace/features/profile/data/datasources/user_profile_remote_data_source.dart';
import 'package:artisan_marketplace/features/profile/data/repositories/user_profile_repository_impl.dart';
import 'package:artisan_marketplace/features/profile/domain/repositories/user_profile_repository.dart';
import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

// Auth
import '../../features/auth/data/datasources/auth_remote_datasource.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/domain/usecases/login_usecase.dart';
import '../../features/auth/domain/usecases/register_usecase.dart';
import '../../features/auth/domain/usecases/logout_usecase.dart';
import '../../features/auth/domain/usecases/get_current_user_usecase.dart';

// Home/Artisan
import '../../features/home/data/datasources/artisan_remote_datasource.dart';
import '../../features/home/data/repositories/artisan_repository_impl.dart';
import '../../features/home/domain/repositories/artisan_repository.dart';
import '../../features/home/domain/usecases/get_featured_artisans_usecase.dart';
import '../../features/home/domain/usecases/get_nearby_artisans_usecase.dart';
import '../../features/home/domain/usecases/search_artisans_usecase.dart';

// Search
import '../../features/search/data/datasources/search_remote_datasource.dart';
import '../../features/search/data/repositories/search_repository_impl.dart';
import '../../features/search/domain/repositories/search_repository.dart';
import '../../features/search/domain/usecases/fuzzy_search_usecase.dart';
import '../../features/search/domain/usecases/get_suggestions_usecase.dart';
import '../../features/search/domain/usecases/log_search_analytics_usecase.dart';
import '../../features/search/domain/usecases/log_search_click_usecase.dart';

// Booking
import '../../features/booking/data/datasources/booking_remote_datasource.dart';
import '../../features/booking/data/repositories/booking_repository_impl.dart';
import '../../features/booking/domain/repositories/booking_repository.dart';
import '../../features/booking/domain/usecases/create_booking_usecase.dart';
import '../../features/booking/domain/usecases/get_user_bookings_usecase.dart';
import '../../features/booking/domain/usecases/get_booking_by_id_usecase.dart';
import '../../features/booking/domain/usecases/accept_booking_usecase.dart';
import '../../features/booking/domain/usecases/reject_booking_usecase.dart';
import '../../features/booking/domain/usecases/cancel_booking_usecase.dart';
import '../../features/booking/domain/usecases/start_booking_usecase.dart';
import '../../features/booking/domain/usecases/complete_booking_usecase.dart';
import '../../features/booking/domain/usecases/get_booking_stats_usecase.dart';

// Profile
import '../../features/profile/data/datasources/profile_remote_datasource.dart';
import '../../features/profile/data/repositories/profile_repository_impl.dart';
import '../../features/profile/domain/repositories/profile_repository.dart';
import '../../features/profile/domain/usecases/update_profile_usecase.dart';
import '../../features/profile/domain/usecases/upload_profile_photo_usecase.dart';
import '../../features/profile/domain/usecases/get_notification_settings_usecase.dart';
import '../../features/profile/domain/usecases/update_notification_settings_usecase.dart';
import '../../features/profile/domain/usecases/get_privacy_settings_usecase.dart';
import '../../features/profile/domain/usecases/update_privacy_settings_usecase.dart';
import '../../features/profile/domain/usecases/get_saved_artisans_usecase.dart';
import '../../features/profile/domain/usecases/save_artisan_usecase.dart';
import '../../features/profile/domain/usecases/unsave_artisan_usecase.dart';
import '../../features/profile/domain/usecases/is_artisan_saved_usecase.dart';

// Notifications
import '../../features/notifications/data/datasources/notification_remote_datasource.dart';
import '../../features/notifications/data/repositories/notification_repository_impl.dart';
import '../../features/notifications/domain/repositories/notification_repository.dart';

// Messaging
import '../../features/messaging/data/datasources/message_remote_data_source.dart';
import '../../features/messaging/data/repositories/message_repository_impl.dart';
import '../../features/messaging/domain/repositories/message_repository.dart';
import '../../features/messaging/domain/usecases/get_conversations_usecase.dart';
import '../../features/messaging/domain/usecases/get_messages_usecase.dart';
import '../../features/messaging/domain/usecases/send_message_usecase.dart';
import '../../features/messaging/domain/usecases/get_or_create_conversation_usecase.dart';
import '../../features/messaging/domain/usecases/mark_messages_as_read_usecase.dart';
import '../../features/messaging/domain/usecases/get_unread_count_usecase.dart';
import '../../features/messaging/domain/usecases/send_voice_message_usecase.dart';
import '../../features/messaging/domain/usecases/send_file_message_usecase.dart';

// Reviews import
import '../../features/reviews/data/repositories/review_repository_impl.dart';
import '../../features/reviews/domain/repositories/review_repository.dart';

// Trust & Safety
import '../../features/trust/data/repositories/trust_repository_impl.dart';
import '../../features/trust/domain/repositories/trust_repository.dart';

// Core
import '../network/network_info.dart';

final getIt = GetIt.instance;
final sl = GetIt.instance;

Future<void> init() async {
  // ============================================
  // External Dependencies
  // ============================================
  final supabase = Supabase.instance.client;
  getIt.registerLazySingleton<SupabaseClient>(() => supabase);

  getIt.registerLazySingleton<Connectivity>(() => Connectivity());

  getIt.registerLazySingleton<NetworkInfo>(
    () => NetworkInfoImpl(getIt<Connectivity>()),
  );

  // ============================================
  // AUTH FEATURE
  // ============================================

  // Data Sources
  getIt.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(
      client: getIt<SupabaseClient>(),
      supabaseClient: getIt<SupabaseClient>(),
    ),
  );

  // Repositories
  getIt.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(
      remoteDataSource: getIt<AuthRemoteDataSource>(),
      networkInfo: getIt<NetworkInfo>(),
    ),
  );

  // Use Cases
  getIt.registerLazySingleton<LoginUseCase>(
    () => LoginUseCase(getIt<AuthRepository>()),
  );
  getIt.registerLazySingleton<RegisterUseCase>(
    () => RegisterUseCase(getIt<AuthRepository>()),
  );
  getIt.registerLazySingleton<LogoutUseCase>(
    () => LogoutUseCase(getIt<AuthRepository>()),
  );
  getIt.registerLazySingleton<GetCurrentUserUseCase>(
    () => GetCurrentUserUseCase(getIt<AuthRepository>()),
  );

  // ============================================
  // ARTISAN/HOME FEATURE
  // ============================================

  // Data Sources
  getIt.registerLazySingleton<ArtisanRemoteDataSource>(
    () => ArtisanRemoteDataSourceImpl(supabaseClient: getIt<SupabaseClient>()),
  );

  // Repositories
  getIt.registerLazySingleton<ArtisanRepository>(
    () => ArtisanRepositoryImpl(
      remoteDataSource: getIt<ArtisanRemoteDataSource>(),
      networkInfo: getIt<NetworkInfo>(),
    ),
  );

  // Use Cases
  getIt.registerLazySingleton<GetFeaturedArtisansUseCase>(
    () => GetFeaturedArtisansUseCase(getIt<ArtisanRepository>()),
  );
  getIt.registerLazySingleton<GetNearbyArtisansUseCase>(
    () => GetNearbyArtisansUseCase(getIt<ArtisanRepository>()),
  );
  getIt.registerLazySingleton<SearchArtisansUseCase>(
    () => SearchArtisansUseCase(getIt<ArtisanRepository>()),
  );

  // ============================================
  // BOOKING FEATURE
  // ============================================

  // Data Sources
  getIt.registerLazySingleton<BookingRemoteDataSource>(
    () => BookingRemoteDataSourceImpl(
      client: getIt<SupabaseClient>(),
    ),
  );

  // Repositories
  getIt.registerLazySingleton<BookingRepository>(
    () => BookingRepositoryImpl(
      remoteDataSource: getIt<BookingRemoteDataSource>(),
      networkInfo: getIt<NetworkInfo>(),
    ),
  );

  // Use Cases
  getIt.registerLazySingleton<CreateBookingUseCase>(
    () => CreateBookingUseCase(getIt<BookingRepository>()),
  );
  getIt.registerLazySingleton<GetUserBookingsUseCase>(
    () => GetUserBookingsUseCase(getIt<BookingRepository>()),
  );
  getIt.registerLazySingleton<GetBookingByIdUseCase>(
    () => GetBookingByIdUseCase(getIt<BookingRepository>()),
  );
  getIt.registerLazySingleton<AcceptBookingUseCase>(
    () => AcceptBookingUseCase(getIt<BookingRepository>()),
  );
  getIt.registerLazySingleton<RejectBookingUseCase>(
    () => RejectBookingUseCase(getIt<BookingRepository>()),
  );
  getIt.registerLazySingleton<CancelBookingUseCase>(
    () => CancelBookingUseCase(getIt<BookingRepository>()),
  );
  getIt.registerLazySingleton<StartBookingUseCase>(
    () => StartBookingUseCase(getIt<BookingRepository>()),
  );
  getIt.registerLazySingleton<CompleteBookingUseCase>(
    () => CompleteBookingUseCase(getIt<BookingRepository>()),
  );
  getIt.registerLazySingleton<GetBookingStatsUseCase>(
    () => GetBookingStatsUseCase(getIt<BookingRepository>()),
  );

  // ==========================================
  // SEARCH FEATURE
  // ==========================================

  // Data sources
  getIt.registerLazySingleton<SearchRemoteDataSource>(
    () => SearchRemoteDataSourceImpl(getIt()),
  );

  // Repository
  getIt.registerLazySingleton<SearchRepository>(
    () => SearchRepositoryImpl(
      remoteDataSource: getIt(),
      networkInfo: getIt(),
    ),
  );

  // Use cases
  getIt.registerLazySingleton(() => FuzzySearchUseCase(getIt()));
  getIt.registerLazySingleton(() => GetSuggestionsUseCase(getIt()));
  getIt.registerLazySingleton(() => LogSearchAnalyticsUseCase(getIt()));
  getIt.registerLazySingleton(() => LogSearchClickUseCase(getIt()));

  // ============================================
  // NOTIFICATION FEATURE
  // ============================================

  // Data Sources
  getIt.registerLazySingleton<NotificationRemoteDataSource>(
    () => NotificationRemoteDataSourceImpl(
      supabaseClient: getIt<SupabaseClient>(),
    ),
  );

  // Data Sources
getIt.registerLazySingleton<MessageRemoteDataSource>(
  () => MessageRemoteDataSourceImpl(
    supabase: getIt<SupabaseClient>(),
  ),
);

// Repositories
getIt.registerLazySingleton<MessageRepository>(
  () => MessageRepositoryImpl(
    remoteDataSource: getIt<MessageRemoteDataSource>(),
    networkInfo: getIt<NetworkInfo>(),
  ),
);

// Messaging Use Cases

// Use Cases
getIt.registerLazySingleton<GetConversationsUseCase>(
  () => GetConversationsUseCase(getIt<MessageRepository>()),
);
getIt.registerLazySingleton<GetMessagesUseCase>(
  () => GetMessagesUseCase(getIt<MessageRepository>()),
);
getIt.registerLazySingleton<SendVoiceMessageUseCase>(
  () => SendVoiceMessageUseCase(getIt<MessageRepository>()),
);
getIt.registerLazySingleton<SendMessageUseCase>(
  () => SendMessageUseCase(getIt<MessageRepository>()),
);
getIt.registerLazySingleton<GetOrCreateConversationUseCase>(
  () => GetOrCreateConversationUseCase(getIt<MessageRepository>()),
);
getIt.registerLazySingleton<MarkMessagesAsReadUseCase>(
  () => MarkMessagesAsReadUseCase(getIt<MessageRepository>()),
);
getIt.registerLazySingleton<GetUnreadCountUseCase>(
  () => GetUnreadCountUseCase(getIt<MessageRepository>()),
);
getIt.registerLazySingleton<SendFileMessageUseCase>(
  () => SendFileMessageUseCase(getIt<MessageRepository>()),
);


  // Repositories
  getIt.registerLazySingleton<NotificationRepository>(
    () => NotificationRepositoryImpl(
      remoteDataSource: getIt<NotificationRemoteDataSource>(),
      networkInfo: getIt<NetworkInfo>(),
    ),
  );

  // ============================================
  // USER PROFILE FEATURE (Viewing other users' profiles)
  // ============================================
  getIt.registerLazySingleton<UserProfileRemoteDataSource>(
    () => UserProfileRemoteDataSourceImpl(
      supabaseClient: getIt<SupabaseClient>(),
    ),
  );

  getIt.registerLazySingleton<UserProfileRepository>(
    () => UserProfileRepositoryImpl(
      remoteDataSource: getIt<UserProfileRemoteDataSource>(),
      networkInfo: getIt<NetworkInfo>(),
    ),
  );

  getIt.registerLazySingleton<GetUserProfileUseCase>(
    () => GetUserProfileUseCase(repository: getIt<UserProfileRepository>()),
  );

  getIt.registerLazySingleton<GetUserBookingStatsUseCase>(
    () => GetUserBookingStatsUseCase(repository: getIt<UserProfileRepository>()),
  );

  // ============================================
  // PROFILE FEATURE
  // ============================================

  // Data Sources
  getIt.registerLazySingleton<ProfileRemoteDataSource>(
    () => ProfileRemoteDataSourceImpl(supabaseClient: getIt<SupabaseClient>()),
  );

  // Repositories
  getIt.registerLazySingleton<ProfileRepository>(
    () => ProfileRepositoryImpl(
      remoteDataSource: getIt<ProfileRemoteDataSource>(),
      networkInfo: getIt<NetworkInfo>(),
    ),
  );

  // Use Cases
  getIt.registerLazySingleton<UpdateProfileUseCase>(
    () => UpdateProfileUseCase(getIt<ProfileRepository>()),
  );
  getIt.registerLazySingleton<UploadProfilePhotoUseCase>(
    () => UploadProfilePhotoUseCase(getIt<ProfileRepository>()),
  );
  getIt.registerLazySingleton<GetNotificationSettingsUseCase>(
    () => GetNotificationSettingsUseCase(getIt<ProfileRepository>()),
  );
  getIt.registerLazySingleton<UpdateNotificationSettingsUseCase>(
    () => UpdateNotificationSettingsUseCase(getIt<ProfileRepository>()),
  );
  getIt.registerLazySingleton<GetPrivacySettingsUseCase>(
    () => GetPrivacySettingsUseCase(getIt<ProfileRepository>()),
  );
  getIt.registerLazySingleton<UpdatePrivacySettingsUseCase>(
    () => UpdatePrivacySettingsUseCase(getIt<ProfileRepository>()),
  );
  getIt.registerLazySingleton<GetSavedArtisansUseCase>(
    () => GetSavedArtisansUseCase(getIt<ProfileRepository>()),
  );
  getIt.registerLazySingleton<SaveArtisanUseCase>(
    () => SaveArtisanUseCase(getIt<ProfileRepository>()),
  );
  getIt.registerLazySingleton<UnsaveArtisanUseCase>(
    () => UnsaveArtisanUseCase(getIt<ProfileRepository>()),
  );
  getIt.registerLazySingleton<IsArtisanSavedUseCase>(
    () => IsArtisanSavedUseCase(getIt<ProfileRepository>()),
  );

  //Review Repository
  getIt.registerLazySingleton<ReviewRepository>(
    () => ReviewRepositoryImpl(
      supabaseClient: getIt<SupabaseClient>(),
    ),
  );

  // Trust & Safety Repository
  getIt.registerLazySingleton<TrustRepository>(
    () => TrustRepositoryImpl(
      supabaseClient: getIt<SupabaseClient>(),
    ),
  );
}

// Helper to reset GetIt (useful for testing)
void resetGetIt() {
  getIt.reset();
}
