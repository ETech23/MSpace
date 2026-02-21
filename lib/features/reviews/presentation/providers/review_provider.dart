// lib/features/reviews/presentation/providers/review_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/review_entity.dart';
import '../../domain/repositories/review_repository.dart';
import '../../../../core/di/injection_container.dart';

// Provider for repository
final reviewRepositoryProvider = Provider<ReviewRepository>((ref) {
  return getIt<ReviewRepository>();
});

// Review State
class ReviewState {
  final bool isLoading;
  final String? error;
  final List<ReviewEntity> reviews;
  final ReviewEntity? currentReview;
  final String? successMessage;

  ReviewState({
    this.isLoading = false,
    this.error,
    this.reviews = const [],
    this.currentReview,
    this.successMessage,
  });

  ReviewState copyWith({
    bool? isLoading,
    String? error,
    List<ReviewEntity>? reviews,
    ReviewEntity? currentReview,
    String? successMessage,
  }) {
    return ReviewState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      reviews: reviews ?? this.reviews,
      currentReview: currentReview ?? this.currentReview,
      successMessage: successMessage,
    );
  }
}

// Review Notifier
class ReviewNotifier extends StateNotifier<ReviewState> {
  final ReviewRepository repository;

  ReviewNotifier({required this.repository}) : super(ReviewState());

  Future<bool> createReview({
    required String bookingId,
    required String artisanId,
    required String clientId,
    required double rating,
    String? comment,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    final result = await repository.createReview(
      bookingId: bookingId,
      artisanId: artisanId,
      clientId: clientId,
      rating: rating,
      comment: comment,
    );

    return result.fold(
      (failure) {
        state = state.copyWith(
          isLoading: false,
          error: failure.message,
        );
        return false;
      },
      (review) {
        state = state.copyWith(
          isLoading: false,
          currentReview: review,
          successMessage: 'Review submitted successfully!',
        );
        return true;
      },
    );
  }

  Future<void> loadArtisanReviews(String artisanId) async {
    state = state.copyWith(isLoading: true, error: null);

    final result = await repository.getArtisanReviews(artisanId);

    result.fold(
      (failure) {
        state = state.copyWith(
          isLoading: false,
          error: failure.message,
        );
      },
      (reviews) {
        state = state.copyWith(
          isLoading: false,
          reviews: reviews,
        );
      },
    );
  }

  Future<void> loadUserReviews(String userId) async {
    state = state.copyWith(isLoading: true, error: null);

    final result = await repository.getUserReviews(userId);

    result.fold(
      (failure) {
        state = state.copyWith(
          isLoading: false,
          error: failure.message,
        );
      },
      (reviews) {
        state = state.copyWith(
          isLoading: false,
          reviews: reviews,
        );
      },
    );
  }

  Future<void> loadReviewByBooking(String bookingId) async {
    state = state.copyWith(isLoading: true, error: null);

    final result = await repository.getReviewByBooking(bookingId);

    result.fold(
      (failure) {
        state = state.copyWith(
          isLoading: false,
          error: failure.message,
        );
      },
      (review) {
        state = state.copyWith(
          isLoading: false,
          currentReview: review,
        );
      },
    );
  }

  Future<bool> updateReview({
    required String reviewId,
    required double rating,
    String? comment,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    final result = await repository.updateReview(
      reviewId: reviewId,
      rating: rating,
      comment: comment,
    );

    return result.fold(
      (failure) {
        state = state.copyWith(
          isLoading: false,
          error: failure.message,
        );
        return false;
      },
      (_) {
        state = state.copyWith(
          isLoading: false,
          successMessage: 'Review updated successfully!',
        );
        return true;
      },
    );
  }

  Future<bool> deleteReview(String reviewId) async {
    state = state.copyWith(isLoading: true, error: null);

    final result = await repository.deleteReview(reviewId);

    return result.fold(
      (failure) {
        state = state.copyWith(
          isLoading: false,
          error: failure.message,
        );
        return false;
      },
      (_) {
        state = state.copyWith(
          isLoading: false,
          successMessage: 'Review deleted successfully!',
        );
        return true;
      },
    );
  }

  void clearMessages() {
    state = state.copyWith(error: null, successMessage: null);
  }
}

// ✅ ADD THIS - The main reviewProvider that booking_detail_screen.dart uses
final reviewProvider = StateNotifierProvider<ReviewNotifier, ReviewState>((ref) {
  return ReviewNotifier(repository: ref.watch(reviewRepositoryProvider));
});

/// ===============================
/// Review By Booking Provider
/// ===============================
final reviewByBookingProvider =
    StateNotifierProvider.family<
        ReviewByBookingNotifier,
        AsyncValue<ReviewEntity?>,
        String>((ref, bookingId) {
  return ReviewByBookingNotifier(ref)
    ..load(bookingId);
});

class ReviewByBookingNotifier
    extends StateNotifier<AsyncValue<ReviewEntity?>> {
  final Ref ref;

  ReviewByBookingNotifier(this.ref)
      : super(const AsyncValue.loading());

  Future<void> load(String bookingId) async {
    // 🚫 Prevent duplicate calls
    if (state is AsyncData) return;

    final result = await ref
        .read(reviewRepositoryProvider)
        .getReviewByBooking(bookingId);

    state = result.fold(
      (failure) =>
          AsyncValue.error(failure.message, StackTrace.current),
      (review) => AsyncValue.data(review),
    );
  }
}

/// ===============================
/// Create Review Provider
/// ===============================
final createReviewProvider =
    StateNotifierProvider<CreateReviewNotifier, AsyncValue<void>>(
  (ref) => CreateReviewNotifier(ref),
);

class CreateReviewNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref ref;

  CreateReviewNotifier(this.ref)
      : super(const AsyncValue.data(null)); // ✅ idle state

  Future<bool> submit({
    required String bookingId,
    required String artisanId,
    required String clientId,
    required double rating,
    String? comment,
  }) async {
    state = const AsyncValue.loading();

    final result = await ref
        .read(reviewRepositoryProvider)
        .createReview(
          bookingId: bookingId,
          artisanId: artisanId,
          clientId: clientId,
          rating: rating,
          comment: comment,
        );

    return result.fold(
      (failure) {
        state =
            AsyncValue.error(failure.message, StackTrace.current);
        return false;
      },
      (_) {
        state = const AsyncValue.data(null); // ✅ reset
        return true;
      },
    );
  }
}