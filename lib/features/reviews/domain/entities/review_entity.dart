// lib/features/reviews/domain/entities/review_entity.dart
import 'package:equatable/equatable.dart';

class ReviewEntity extends Equatable {
  final String id;
  final String bookingId;
  final String artisanId;
  final String clientId;
  final double rating; // 1-5 stars
  final String? comment;
  final String reviewerName;
  final String? reviewerPhotoUrl;
  final String artisanName;
  final String? artisanPhotoUrl;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const ReviewEntity({
    required this.id,
    required this.bookingId,
    required this.artisanId,
    required this.clientId,
    required this.rating,
    this.comment,
    required this.reviewerName,
    this.reviewerPhotoUrl,
    required this.artisanName,
    this.artisanPhotoUrl,
    required this.createdAt,
    this.updatedAt,
  });

  @override
  List<Object?> get props => [
        id,
        bookingId,
        artisanId,
        clientId,
        rating,
        comment,
        reviewerName,
        reviewerPhotoUrl,
        artisanName,
        artisanPhotoUrl,
        createdAt,
        updatedAt,
      ];
}