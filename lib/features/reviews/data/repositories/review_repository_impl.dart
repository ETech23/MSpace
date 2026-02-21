// lib/features/reviews/data/repositories/review_repository_impl.dart
import 'package:dartz/dartz.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/review_entity.dart';
import '../../domain/repositories/review_repository.dart';
import '../models/review_model.dart';

class ReviewRepositoryImpl implements ReviewRepository {
  final SupabaseClient supabaseClient;

  ReviewRepositoryImpl({required this.supabaseClient});

@override
Future<Either<Failure, ReviewEntity>> createReview({
  required String bookingId,
  required String artisanId,
  required String clientId,
  required double rating,
  String? comment,
}) async {
  try {
    // Get reviewer (client) info
    final userResponse = await supabaseClient
        .from('users')
        .select('name, photo_url')
        .eq('id', clientId)
        .single();

    // Get artisan info
    final artisanResponse = await supabaseClient
        .from('users')
        .select('name, photo_url')
        .eq('id', artisanId)
        .single();

    // ✅ FIXED: Include reviewer and artisan names/photos in the insert
    final reviewData = {
      'booking_id': bookingId,
      'artisan_id': artisanId,
      'client_id': clientId,
      'rating': rating,
      'comment': comment,
      'reviewer_name': userResponse['name'] as String, // ✅ ADD THIS
      'reviewer_photo_url': userResponse['photo_url'] as String?, // ✅ ADD THIS
      'artisan_name': artisanResponse['name'] as String, // ✅ ADD THIS
      'artisan_photo_url': artisanResponse['photo_url'] as String?, // ✅ ADD THIS
      'created_at': DateTime.now().toIso8601String(),
    };

    final response = await supabaseClient
        .from('reviews')
        .insert(reviewData)
        .select()
        .single();

    // Update artisan's average rating
    await _updateArtisanRating(artisanId);

    return Right(ReviewModel.fromJson(response));
  } catch (e) {
    print('❌ Error creating review: $e');
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
        .select('''
          *,
          reviewer:client_id(name, photo_url),
          artisan:artisan_id(name, photo_url)
        ''')
        .eq('artisan_id', artisanId)
        .order('created_at', ascending: false);

    final reviews = (response as List).map((item) {
      final json = item as Map;
      // ✅ Transform to include user info
      final Map<String, dynamic> transformedJson = {
        ...Map<String, dynamic>.from(json),
        'reviewer_name': (json['reviewer'] as Map?)?['name'] ?? 
                         json['reviewer_name'] ?? 'Anonymous',
        'reviewer_photo_url': (json['reviewer'] as Map?)?['photo_url'] ?? 
                              json['reviewer_photo_url'],
        'artisan_name': (json['artisan'] as Map?)?['name'] ?? 
                        json['artisan_name'] ?? 'Artisan',
        'artisan_photo_url': (json['artisan'] as Map?)?['photo_url'] ?? 
                             json['artisan_photo_url'],
      };
      return ReviewModel.fromJson(transformedJson);
    }).toList();

    return Right(reviews);
  } catch (e) {
    print('❌ Error getting artisan reviews: $e');
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
          .select('''
            *,
            reviewer:client_id(name, photo_url),
            artisan:artisan_id(name, photo_url)
          ''')
          .eq('client_id', userId)
          .order('created_at', ascending: false);

      final reviews = (response as List).map((item) {
        final json = item as Map;
        // ✅ Transform to include user info with proper casting
        final Map<String, dynamic> transformedJson = {
          ...Map<String, dynamic>.from(json),
          'reviewer_name': (json['reviewer'] as Map?)?['name'] ?? 'Anonymous',
          'reviewer_photo_url': (json['reviewer'] as Map?)?['photo_url'],
          'artisan_name': (json['artisan'] as Map?)?['name'] ?? 'Artisan',
          'artisan_photo_url': (json['artisan'] as Map?)?['photo_url'],
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
        .select('''
          *,
          reviewer:client_id(name, photo_url),
          artisan:artisan_id(name, photo_url)
        ''')
        .eq('booking_id', bookingId)
        .maybeSingle();

    if (response == null) {
      return const Right(null);
    }

    // ✅ Transform to include user info
    final json = response as Map;
    final Map<String, dynamic> transformedJson = {
      ...Map<String, dynamic>.from(json),
      'reviewer_name': (json['reviewer'] as Map?)?['name'] ?? 
                       json['reviewer_name'] ?? 'Anonymous',
      'reviewer_photo_url': (json['reviewer'] as Map?)?['photo_url'] ?? 
                            json['reviewer_photo_url'],
      'artisan_name': (json['artisan'] as Map?)?['name'] ?? 
                      json['artisan_name'] ?? 'Artisan',
      'artisan_photo_url': (json['artisan'] as Map?)?['photo_url'] ?? 
                           json['artisan_photo_url'],
    };

    return Right(ReviewModel.fromJson(transformedJson));
  } catch (e) {
    print('❌ Error getting review by booking: $e');
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

      await supabaseClient
          .from('reviews')
          .update(updateData)
          .eq('id', reviewId);

      // Get artisan ID and update rating
      final review = await supabaseClient
          .from('reviews')
          .select('artisan_id')
          .eq('id', reviewId)
          .single();

      await _updateArtisanRating(review['artisan_id']);

      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteReview(String reviewId) async {
    try {
      // Get artisan ID before deleting
      final review = await supabaseClient
          .from('reviews')
          .select('artisan_id')
          .eq('id', reviewId)
          .single();

      await supabaseClient.from('reviews').delete().eq('id', reviewId);

      // Update artisan rating
      await _updateArtisanRating(review['artisan_id']);

      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  Future<void> _updateArtisanRating(String artisanId) async {
    try {
      // Calculate average rating
      final reviews = await supabaseClient
          .from('reviews')
          .select('rating')
          .eq('artisan_id', artisanId);

      if ((reviews as List).isEmpty) {
        // No reviews, set rating to 0
        await supabaseClient
            .from('artisan_profiles')
            .update({
              'rating': 0.0,
              'reviews_count': 0,
            })
            .eq('user_id', artisanId);
        return;
      }

      final ratings = (reviews as List).map((r) => (r['rating'] as num).toDouble()).toList();
      final avgRating = ratings.reduce((a, b) => a + b) / ratings.length;

      // Update artisan profile
      await supabaseClient
          .from('artisan_profiles')
          .update({
            'rating': avgRating,
            'reviews_count': ratings.length,
          })
          .eq('user_id', artisanId);
    } catch (e) {
      print('⚠️ Error updating artisan rating: $e');
    }
  }
}