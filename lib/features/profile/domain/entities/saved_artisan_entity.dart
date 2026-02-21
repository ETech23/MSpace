// lib/features/profile/domain/entities/saved_artisan_entity.dart
import 'package:equatable/equatable.dart';

class SavedArtisanEntity extends Equatable {
  final String id;
  final String userId;
  final String artisanId;
  final String artisanName;
  final String? artisanPhoto;
  final String category;
  final double rating;
  final DateTime savedAt;

  const SavedArtisanEntity({
    required this.id,
    required this.userId,
    required this.artisanId,
    required this.artisanName,
    this.artisanPhoto,
    required this.category,
    required this.rating,
    required this.savedAt,
  });

  @override
  List<Object?> get props => [
        id,
        userId,
        artisanId,
        artisanName,
        artisanPhoto,
        category,
        rating,
        savedAt,
      ];
}