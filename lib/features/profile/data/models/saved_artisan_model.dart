// lib/features/profile/data/models/saved_artisan_model.dart
import '../../domain/entities/saved_artisan_entity.dart';

class SavedArtisanModel extends SavedArtisanEntity {
  const SavedArtisanModel({
    required super.id,
    required super.userId,
    required super.artisanId,
    required super.artisanName,
    super.artisanPhoto,
    required super.category,
    required super.rating,
    required super.savedAt,
  });

  factory SavedArtisanModel.fromJson(Map<String, dynamic> json) {
    return SavedArtisanModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      artisanId: json['artisan_id'] as String,
      artisanName: json['artisan_name'] as String,
      artisanPhoto: json['artisan_photo'] as String?,
      category: json['category'] as String,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      savedAt: DateTime.parse(json['saved_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'artisan_id': artisanId,
      'artisan_name': artisanName,
      'artisan_photo': artisanPhoto,
      'category': category,
      'rating': rating,
      'saved_at': savedAt.toIso8601String(),
    };
  }

  // ✅ Add toEntity method
  SavedArtisanEntity toEntity() {
    return SavedArtisanEntity(
      id: id,
      userId: userId,
      artisanId: artisanId,
      artisanName: artisanName,
      artisanPhoto: artisanPhoto,
      category: category,
      rating: rating,
      savedAt: savedAt,
    );
  }
}