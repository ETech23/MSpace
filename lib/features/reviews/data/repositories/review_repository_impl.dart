import 'package:dartz/dartz.dart';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/review_entity.dart';
import '../../domain/repositories/review_repository.dart';
import '../models/review_model.dart';

class ReviewRepositoryImpl implements ReviewRepository {
  ReviewRepositoryImpl({required this.supabaseClient});

  final SupabaseClient supabaseClient;

  @override
  Future<Either<Failure, ReviewEntity>> createReview({
    required String bookingId,
    required String artisanId,
    required String customerId,
    required double rating,
    String? comment,
  }) async {
    try {
      final normalizedBookingId = bookingId.trim();
      final normalizedArtisanId = artisanId.trim();
      final normalizedCustomerId = customerId.trim();

      if (normalizedBookingId.isEmpty) {
        return Left(
          ServerFailure(message: 'A valid booking is required to leave a review.'),
        );
      }
      if (normalizedArtisanId.isEmpty) {
        return Left(
          ServerFailure(message: 'A valid artisan is required to leave a review.'),
        );
      }
      if (normalizedCustomerId.isEmpty &&
          (supabaseClient.auth.currentUser?.id.trim().isEmpty ?? true)) {
        return Left(
          ServerFailure(message: 'You must be signed in to leave a review.'),
        );
      }

      final normalizedComment = comment?.trim();
      final response = await supabaseClient.rpc(
        'create_review_secure',
        params: {
          'p_booking_id': normalizedBookingId,
          'p_artisan_id': normalizedArtisanId,
          'p_rating': rating,
          'p_comment': (normalizedComment == null || normalizedComment.isEmpty)
              ? null
              : normalizedComment,
        },
      );

      final reviewJson = _asStringKeyedMap(response);
      if (reviewJson.isEmpty) {
        return Left(
          ServerFailure(
            message: 'Review could not be created. The server returned no data.',
          ),
        );
      }

      return Right(ReviewModel.fromJson(reviewJson));
    } on PostgrestException catch (e) {
      final message = _mapCreateReviewError(e);
      print('Error creating review: ${e.message} (${e.code})');
      return Left(ServerFailure(message: message));
    } catch (e) {
      print('Error creating review: $e');
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<ReviewEntity>>> getArtisanReviews(
    String artisanId,
  ) async {
    try {
      final response = await supabaseClient
          .from('reviews')
          .select('*')
          .eq('artisan_id', artisanId)
          .order('created_at', ascending: false);

      final reviews = (response as List).map((item) {
        final json = item as Map;
        final transformedJson = <String, dynamic>{
          ...Map<String, dynamic>.from(json),
          'reviewer_name': json['reviewer_name'] ?? 'Anonymous',
          'reviewer_photo_url': json['reviewer_photo_url'],
          'artisan_name': json['artisan_name'] ?? 'Artisan',
          'artisan_photo_url': json['artisan_photo_url'],
        };
        return ReviewModel.fromJson(transformedJson);
      }).toList();

      return Right(reviews);
    } catch (e) {
      print('Error getting artisan reviews: $e');
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<ReviewEntity>>> getUserReviews(
    String userId,
  ) async {
    try {
      final response = await supabaseClient
          .from('reviews')
          .select('*')
          .or('client_id.eq.$userId,customer_id.eq.$userId')
          .order('created_at', ascending: false);

      final reviews = (response as List).map((item) {
        final json = item as Map;
        final transformedJson = <String, dynamic>{
          ...Map<String, dynamic>.from(json),
          'reviewer_name': json['reviewer_name'] ?? 'Anonymous',
          'reviewer_photo_url': json['reviewer_photo_url'],
          'artisan_name': json['artisan_name'] ?? 'Artisan',
          'artisan_photo_url': json['artisan_photo_url'],
        };
        return ReviewModel.fromJson(transformedJson);
      }).toList();

      return Right(reviews);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, ReviewEntity?>> getReviewByBooking(
    String bookingId,
  ) async {
    try {
      final response = await supabaseClient
          .from('reviews')
          .select('*')
          .eq('booking_id', bookingId)
          .maybeSingle();

      if (response == null) {
        return const Right(null);
      }

      final json = response as Map;
      final transformedJson = <String, dynamic>{
        ...Map<String, dynamic>.from(json),
        'reviewer_name': json['reviewer_name'] ?? 'Anonymous',
        'reviewer_photo_url': json['reviewer_photo_url'],
        'artisan_name': json['artisan_name'] ?? 'Artisan',
        'artisan_photo_url': json['artisan_photo_url'],
      };

      return Right(ReviewModel.fromJson(transformedJson));
    } catch (e) {
      print('Error getting review by booking: $e');
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> updateReview({
    required String reviewId,
    required double rating,
    String? comment,
  }) async {
    try {
      final updateData = {
        'rating': rating,
        'comment': comment,
        'updated_at': DateTime.now().toIso8601String(),
      };

      await supabaseClient.from('reviews').update(updateData).eq('id', reviewId);

      final review = await supabaseClient
          .from('reviews')
          .select('artisan_id')
          .eq('id', reviewId)
          .single();

      await _updateArtisanRating(review['artisan_id'] as String);

      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteReview(String reviewId) async {
    try {
      final review = await supabaseClient
          .from('reviews')
          .select('artisan_id')
          .eq('id', reviewId)
          .single();

      await supabaseClient.from('reviews').delete().eq('id', reviewId);
      await _updateArtisanRating(review['artisan_id'] as String);

      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  Future<void> _updateArtisanRating(String artisanId) async {
    try {
      final reviews = await supabaseClient
          .from('reviews')
          .select('rating')
          .eq('artisan_id', artisanId);

      if ((reviews as List).isEmpty) {
        await supabaseClient.from('artisan_profiles').update({
          'rating': 0.0,
          'reviews_count': 0,
        }).eq('user_id', artisanId);
        return;
      }

      final ratings = reviews
          .map((row) => ((row as Map<String, dynamic>)['rating'] as num).toDouble())
          .toList(growable: false);
      final avgRating = ratings.reduce((a, b) => a + b) / ratings.length;

      await supabaseClient.from('artisan_profiles').update({
        'rating': avgRating,
        'reviews_count': ratings.length,
      }).eq('user_id', artisanId);
    } catch (e) {
      print('Error updating artisan rating: $e');
    }
  }

  Map<String, dynamic> _asStringKeyedMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((key, val) => MapEntry(key.toString(), val));
    }
    if (value is String && value.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
        if (decoded is Map) {
          return decoded.map((key, val) => MapEntry(key.toString(), val));
        }
      } catch (_) {
        return <String, dynamic>{};
      }
    }
    return <String, dynamic>{};
  }

  String _mapCreateReviewError(PostgrestException error) {
    final rawMessage = error.message.trim();
    final lowered = rawMessage.toLowerCase();
    final code = error.code?.trim();

    if (code == 'PGRST202' ||
        lowered.contains('function public.create_review_secure') ||
        lowered.contains('could not find the function public.create_review_secure')) {
      return 'Review creation is not configured on the server yet. Run docs/reviews_rls_policies.sql and try again.';
    }
    if (code == '42501') {
      if (lowered.contains('only the booking client')) {
        return 'Only the booking client can submit this review.';
      }
      return 'You are not allowed to submit a review for this booking.';
    }
    if (code == '23502' &&
        (lowered.contains('customer_id') || lowered.contains('client_id'))) {
      return 'Review creation is out of sync with the database schema. Run docs/reviews_rls_policies.sql and try again.';
    }
    if (code == '23505') {
      return 'A review has already been submitted for this booking.';
    }
    if (code == '23514' || code == '22023') {
      return rawMessage;
    }
    if (code == 'P0002') {
      return 'Booking not found.';
    }
    if (rawMessage.isNotEmpty) {
      return rawMessage;
    }
    return 'Failed to submit review.';
  }
}
