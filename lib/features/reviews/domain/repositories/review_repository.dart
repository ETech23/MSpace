// lib/features/reviews/domain/repositories/review_repository.dart
import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/review_entity.dart';

abstract class ReviewRepository {
  Future<Either<Failure, ReviewEntity>> createReview({
    required String bookingId,
    required String artisanId,
    required String clientId,
    required double rating,
    String? comment,
  });

  Future<Either<Failure, List<ReviewEntity>>> getArtisanReviews(
    String artisanId,
  );

  Future<Either<Failure, List<ReviewEntity>>> getUserReviews(
    String userId,
  );

  Future<Either<Failure, ReviewEntity?>> getReviewByBooking(
    String bookingId,
  );

  Future<Either<Failure, void>> updateReview({
    required String reviewId,
    required double rating,
    String? comment,
  });

  Future<Either<Failure, void>> deleteReview(String reviewId);
}