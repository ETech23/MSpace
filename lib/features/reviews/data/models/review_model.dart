// lib/features/reviews/data/models/review_model.dart
import '../../domain/entities/review_entity.dart';

class ReviewModel extends ReviewEntity {
  const ReviewModel({
    required super.id,
    required super.bookingId,
    required super.artisanId,
    required super.clientId,
    required super.rating,
    super.comment,
    required super.reviewerName,
    super.reviewerPhotoUrl,
    required super.artisanName,
    super.artisanPhotoUrl,
    required super.createdAt,
    super.updatedAt,
  });

  factory ReviewModel.fromJson(Map<String, dynamic> json) {
    return ReviewModel(
      id: json['id'] as String,
      bookingId: json['booking_id'] as String,
      artisanId: json['artisan_id'] as String,
      clientId: json['client_id'] as String,
      rating: (json['rating'] as num).toDouble(),
      comment: json['comment'] as String?,
      reviewerName: json['reviewer_name'] as String? ?? 'Anonymous',
      reviewerPhotoUrl: json['reviewer_photo_url'] as String?,
      artisanName: json['artisan_name'] as String? ?? 'Artisan',
      artisanPhotoUrl: json['artisan_photo_url'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'booking_id': bookingId,
      'artisan_id': artisanId,
      'client_id': clientId,
      'rating': rating,
      'comment': comment,
      'reviewer_name': reviewerName,
      'reviewer_photo_url': reviewerPhotoUrl,
      'artisan_name': artisanName,
      'artisan_photo_url': artisanPhotoUrl,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  ReviewEntity toEntity() => ReviewEntity(
        id: id,
        bookingId: bookingId,
        artisanId: artisanId,
        clientId: clientId,
        rating: rating,
        comment: comment,
        reviewerName: reviewerName,
        reviewerPhotoUrl: reviewerPhotoUrl,
        artisanName: artisanName,
        artisanPhotoUrl: artisanPhotoUrl,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}