// lib/features/booking/presentation/providers/booking_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/services/notification_service.dart'; // ✅ Add this
import '../../domain/entities/booking_entity.dart';
import '../../domain/usecases/create_booking_usecase.dart';
import '../../domain/usecases/get_user_bookings_usecase.dart';
import '../../domain/usecases/get_booking_by_id_usecase.dart';
import '../../domain/usecases/accept_booking_usecase.dart';
import '../../domain/usecases/reject_booking_usecase.dart';
import '../../domain/usecases/cancel_booking_usecase.dart';
import '../../domain/usecases/start_booking_usecase.dart';
import '../../domain/usecases/complete_booking_usecase.dart';
import '../../domain/usecases/get_booking_stats_usecase.dart';

// Providers for use cases
final createBookingUseCaseProvider = Provider((ref) => getIt<CreateBookingUseCase>());
final getUserBookingsUseCaseProvider = Provider((ref) => getIt<GetUserBookingsUseCase>());
final getBookingByIdUseCaseProvider = Provider((ref) => getIt<GetBookingByIdUseCase>());
final acceptBookingUseCaseProvider = Provider((ref) => getIt<AcceptBookingUseCase>());
final rejectBookingUseCaseProvider = Provider((ref) => getIt<RejectBookingUseCase>());
final cancelBookingUseCaseProvider = Provider((ref) => getIt<CancelBookingUseCase>());
final startBookingUseCaseProvider = Provider((ref) => getIt<StartBookingUseCase>());
final completeBookingUseCaseProvider = Provider((ref) => getIt<CompleteBookingUseCase>());
final getBookingStatsUseCaseProvider = Provider((ref) => getIt<GetBookingStatsUseCase>());

// ✅ Notification service provider
final notificationServiceProvider = Provider((ref) => NotificationService());

// Booking state
class BookingState {
  final bool isLoading;
  final bool isCreating;
  final bool isUpdating;
  final bool isLoadingMore;
  final List<BookingEntity> bookings;
  final BookingEntity? currentBooking;
  final BookingEntity? selectedBooking;
  final Map<String, int>? stats;
  final String? error;
  final int currentPage;
  final bool hasMore;
  final String? successMessage;

  BookingState({
    this.isLoading = false,
    this.isCreating = false,
    this.isUpdating = false,
    this.isLoadingMore = false,
    this.currentPage = 1,
    this.hasMore = true,
    this.bookings = const [],
    this.selectedBooking,
    this.currentBooking,
    this.stats,
    this.error,
    this.successMessage,
  });

  BookingState copyWith({
    bool? isLoading,
    bool? isCreating,
    bool? isUpdating,
    bool? isLoadingMore,
    List<BookingEntity>? bookings,
    BookingEntity? currentBooking,
    BookingEntity? selectedBooking,
    Map<String, int>? stats,
    String? error,
    int? currentPage,
    bool? hasMore,
    String? successMessage,
    bool clearCurrentBooking = false,
    bool clearSelectedBooking = false,
    bool clearError = false,
  }) {
    return BookingState(
      isLoading: isLoading ?? this.isLoading,
      isCreating: isCreating ?? this.isCreating,
      isUpdating: isUpdating ?? this.isUpdating,
      bookings: bookings ?? this.bookings,
      selectedBooking: clearSelectedBooking 
          ? null 
          : (selectedBooking ?? this.selectedBooking),
      currentPage: currentPage ?? this.currentPage,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      currentBooking: clearCurrentBooking 
          ? null 
          : (currentBooking ?? this.currentBooking),
      stats: stats ?? this.stats,
      error: clearError ? null : error,
      successMessage: successMessage,
    );
  }
}

// Booking notifier
class BookingNotifier extends StateNotifier<BookingState> {
  final CreateBookingUseCase createBookingUseCase;
  final GetUserBookingsUseCase getUserBookingsUseCase;
  final GetBookingByIdUseCase getBookingByIdUseCase;
  final AcceptBookingUseCase acceptBookingUseCase;
  final RejectBookingUseCase rejectBookingUseCase;
  final CancelBookingUseCase cancelBookingUseCase;
  final StartBookingUseCase startBookingUseCase;
  final CompleteBookingUseCase completeBookingUseCase;
  final GetBookingStatsUseCase getBookingStatsUseCase;
  final NotificationService notificationService; // ✅ Add this
  
  BookingNotifier({
    required this.createBookingUseCase,
    required this.getUserBookingsUseCase,
    required this.getBookingByIdUseCase,
    required this.acceptBookingUseCase,
    required this.rejectBookingUseCase,
    required this.cancelBookingUseCase,
    required this.startBookingUseCase,
    required this.completeBookingUseCase,
    required this.getBookingStatsUseCase,
    required this.notificationService, // ✅ Add this
  }) : super(BookingState());

  // Create a new booking
  Future<bool> createBooking({
    required String customerId,
    required String artisanId,
    required String artisanProfileId,
    required String serviceType,
    required String description,
    required DateTime preferredDate,
    required String preferredTime,
    required String locationAddress,
    double? locationLatitude,
    double? locationLongitude,
    double? estimatedPrice,
    String? customerNotes,
  }) async {
    state = state.copyWith(isCreating: true, clearError: true, successMessage: null);

    final result = await createBookingUseCase(
      customerId: customerId,
      artisanId: artisanId,
      artisanProfileId: artisanProfileId,
      serviceType: serviceType,
      description: description,
      preferredDate: preferredDate,
      preferredTime: preferredTime,
      locationAddress: locationAddress,
      locationLatitude: locationLatitude,
      locationLongitude: locationLongitude,
      estimatedPrice: estimatedPrice,
      customerNotes: customerNotes,
    );

    return result.fold(
      (failure) {
        state = state.copyWith(
          isCreating: false,
          error: failure.message,
        );
        return false;
      },
      (booking) async {
        // ✅ Notification sent by database trigger automatically
        state = state.copyWith(
          isCreating: false,
          currentBooking: booking,
          selectedBooking: booking,
          successMessage: 'Booking created successfully!',
        );
        return true;
      },
    );
  }

  // Load user's bookings
  Future<void> loadUserBookings({
    required String userId,
    required String userType,
    String? status,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    final result = await getUserBookingsUseCase(
      userId: userId,
      userType: userType,
      status: status,
    );

    result.fold(
      (failure) {
        state = state.copyWith(
          isLoading: false,
          error: failure.message,
        );
      },
      (bookings) {
        state = state.copyWith(
          isLoading: false,
          bookings: bookings,
        );
      },
    );
  }

  // Load specific booking
  Future<void> loadBookingById(String bookingId) async {
    print('🔍 Loading booking: $bookingId');
    
    // ✅ CRITICAL FIX: Clear the booking FIRST in a separate state update
    // This forces the UI to show loading state
    state = state.copyWith(
      clearSelectedBooking: true,
      clearCurrentBooking: true,
    );
    
    // ✅ Then set loading state
    state = state.copyWith(
      isLoading: true,
      clearError: true,
    );

    final result = await getBookingByIdUseCase(bookingId);

    result.fold(
      (failure) {
        print('❌ Failed to load booking: ${failure.message}');
        state = state.copyWith(
          isLoading: false,
          error: failure.message,
        );
      },
      (booking) {
        print('✅ Booking loaded: ${booking.id}');
        state = state.copyWith(
          isLoading: false,
          selectedBooking: booking,
          currentBooking: booking,
        );
      },
    );
  }

  // Accept booking (artisan)
  Future<bool> acceptBooking(String bookingId) async {
    state = state.copyWith(isUpdating: true, clearError: true, successMessage: null);

    final result = await acceptBookingUseCase(bookingId);

    return await result.fold(
      (failure) async {
        state = state.copyWith(
          isUpdating: false,
          error: failure.message,
        );
        return false;
      },
      (_) async {
        final updatedBookingResult = await getBookingByIdUseCase(bookingId);
        
        return updatedBookingResult.fold(
          (failure) {
            state = state.copyWith(
              isUpdating: false,
              error: 'Accepted but failed to refresh: ${failure.message}',
            );
            return false;
          },
          (updatedBooking) async {
            // ✅ Notification sent by database trigger
            state = state.copyWith(
              isUpdating: false,
              selectedBooking: updatedBooking,
              currentBooking: updatedBooking,
              successMessage: 'Booking accepted!',
            );
            return true;
          },
        );
      },
    );
  }

  // Reject booking (artisan)
  Future<bool> rejectBooking({
    required String bookingId,
    required String reason,
  }) async {
    state = state.copyWith(isUpdating: true, clearError: true, successMessage: null);

    final result = await rejectBookingUseCase(
      bookingId: bookingId,
      reason: reason,
    );

    return await result.fold(
      (failure) async {
        state = state.copyWith(
          isUpdating: false,
          error: failure.message,
        );
        return false;
      },
      (_) async {
        final updatedBookingResult = await getBookingByIdUseCase(bookingId);
        
        return updatedBookingResult.fold(
          (failure) {
            state = state.copyWith(
              isUpdating: false,
              error: 'Rejected but failed to refresh',
            );
            return false;
          },
          (updatedBooking) async {
            // ✅ Send notification to customer
            await notificationService.sendBookingRejectedNotification(
              artisanName: updatedBooking.artisanName ?? 'Artisan',
              serviceType: updatedBooking.serviceType,
              reason: reason, bookingId: '',
            );
            
            state = state.copyWith(
              isUpdating: false,
              selectedBooking: updatedBooking,
              currentBooking: updatedBooking,
              successMessage: 'Booking rejected',
            );
            return true;
          },
        );
      },
    );
  }

  // Start booking (artisan)
  Future<bool> startBooking(String bookingId) async {
    state = state.copyWith(isUpdating: true, clearError: true, successMessage: null);

    final result = await startBookingUseCase(bookingId);

    return await result.fold(
      (failure) async {
        state = state.copyWith(
          isUpdating: false,
          error: failure.message,
        );
        return false;
      },
      (_) async {
        final updatedBookingResult = await getBookingByIdUseCase(bookingId);
        
        return updatedBookingResult.fold(
          (failure) {
            state = state.copyWith(
              isUpdating: false,
              error: 'Started but failed to refresh',
            );
            return false;
          },
          (updatedBooking) async {
            // ✅ Send notification to customer
            await notificationService.sendBookingStartedNotification(
              artisanName: updatedBooking.artisanName ?? 'Artisan',
              serviceType: updatedBooking.serviceType, bookingId: '',
            );
            
            state = state.copyWith(
              isUpdating: false,
              selectedBooking: updatedBooking,
              currentBooking: updatedBooking,
              successMessage: 'Work started!',
            );
            return true;
          },
        );
      },
    );
  }

  // Complete booking (artisan)
  Future<bool> completeBooking(String bookingId) async {
    state = state.copyWith(isUpdating: true, clearError: true, successMessage: null);

    final result = await completeBookingUseCase(bookingId);

    return await result.fold(
      (failure) async {
        state = state.copyWith(
          isUpdating: false,
          error: failure.message,
        );
        return false;
      },
      (_) async {
        final updatedBookingResult = await getBookingByIdUseCase(bookingId);
        
        return updatedBookingResult.fold(
          (failure) {
            state = state.copyWith(
              isUpdating: false,
              error: 'Completed but failed to refresh',
            );
            return false;
          },
          (updatedBooking) async {
            // ✅ Send notification to customer
            await notificationService.sendBookingCompletedNotification(
              artisanName: updatedBooking.artisanName ?? 'Artisan',
              serviceType: updatedBooking.serviceType, bookingId: '',
            );
            
            state = state.copyWith(
              isUpdating: false,
              selectedBooking: updatedBooking,
              currentBooking: updatedBooking,
              successMessage: 'Work completed!',
            );
            return true;
          },
        );
      },
    );
  }

  // Cancel booking
  Future<bool> cancelBooking({
    required String bookingId,
    required String cancelledBy,
    required String reason,
  }) async {
    state = state.copyWith(isUpdating: true, clearError: true, successMessage: null);

    final result = await cancelBookingUseCase(
      bookingId: bookingId,
      cancelledBy: cancelledBy,
      reason: reason,
    );

    return await result.fold(
      (failure) async {
        state = state.copyWith(
          isUpdating: false,
          error: failure.message,
        );
        return false;
      },
      (_) async {
        final updatedBookingResult = await getBookingByIdUseCase(bookingId);
        
        return updatedBookingResult.fold(
          (failure) {
            state = state.copyWith(
              isUpdating: false,
              error: 'Cancelled but failed to refresh',
            );
            return false;
          },
          (updatedBooking) async {
            // ✅ Send notification
            await notificationService.sendBookingCancelledNotification(
              userName: cancelledBy,
              serviceType: updatedBooking.serviceType,
              reason: reason, bookingId: '',
            );
            
            state = state.copyWith(
              isUpdating: false,
              selectedBooking: updatedBooking,
              currentBooking: updatedBooking,
              successMessage: 'Booking cancelled',
            );
            return true;
          },
        );
      },
    );
  }
  
  // Load booking statistics
  Future<void> loadBookingStats({
    required String userId,
    required String userType,
  }) async {
    final result = await getBookingStatsUseCase(
      userId: userId,
      userType: userType,
    );

    result.fold(
      (failure) {
        // Silently fail for stats
      },
      (stats) {
        state = state.copyWith(stats: stats);
      },
    );
  }

  // Clear current booking
  void clearCurrentBooking() {
    state = state.copyWith(clearCurrentBooking: true);
  }

  // Clear messages
  void clearMessages() {
    state = state.copyWith(clearError: true, successMessage: null);
  }
}

// Booking provider
final bookingProvider = StateNotifierProvider<BookingNotifier, BookingState>((ref) {
  return BookingNotifier(
    createBookingUseCase: ref.watch(createBookingUseCaseProvider),
    getUserBookingsUseCase: ref.watch(getUserBookingsUseCaseProvider),
    getBookingByIdUseCase: ref.watch(getBookingByIdUseCaseProvider),
    acceptBookingUseCase: ref.watch(acceptBookingUseCaseProvider),
    rejectBookingUseCase: ref.watch(rejectBookingUseCaseProvider),
    cancelBookingUseCase: ref.watch(cancelBookingUseCaseProvider),
    startBookingUseCase: ref.watch(startBookingUseCaseProvider),
    completeBookingUseCase: ref.watch(completeBookingUseCaseProvider),
    getBookingStatsUseCase: ref.watch(getBookingStatsUseCaseProvider),
    notificationService: ref.watch(notificationServiceProvider), // ✅ Add this
  );
});