// lib/features/home/domain/entities/artisan_entity.dart

import 'package:equatable/equatable.dart';

class ArtisanEntity extends Equatable {
  final String id;
  final String userId;
  final String name;
  final String email;
  final String? phoneNumber;
  final String? photoUrl;
  final String category;
  final String? bio;
  final String? address;
  final String? city;      // Added as actual field
  final String? state;     // Added as actual field
  final double? latitude;
  final double? longitude;
  final double rating;
  final int reviewCount;
  final bool isVerified;
  final bool premium;
  final bool isFeatured;
  final bool isAvailable;
  final double? distance;
  final List<String>? skills;
  final int completedJobs;
  final List<String>? certifications;
  final double? hourlyRate;
  final String? experienceYears;

  // Search metadata (optional)
  final String? matchType;
  final double? relevanceScore;

  final DateTime createdAt;
  final DateTime? updatedAt;

  const ArtisanEntity({
    required this.id,
    required this.userId,
    required this.name,
    required this.email,
    this.phoneNumber,
    this.photoUrl,
    required this.category,
    this.bio,
    this.address,
    this.city,
    this.state,
    this.latitude,
    this.longitude,
    this.rating = 0.0,
    this.reviewCount = 0,
    this.isVerified = false,
    this.premium = false,
    this.isFeatured = false,
    this.isAvailable = true,
    this.distance,
    this.skills,
    this.completedJobs = 0,
    this.certifications,
    this.hourlyRate,
    this.experienceYears,
    this.matchType,
    this.relevanceScore,
    required this.createdAt,
    this.updatedAt,
  });

  /// Extract city from address if not provided directly
  String? get displayCity {
    if (city != null && city!.isNotEmpty) return city;
    if (address == null || address!.isEmpty) return null;
    
    // Try to extract city from address (e.g., "123 Main St, Port Harcourt, Rivers")
    final parts = address!.split(',');
    if (parts.length >= 2) {
      return parts[parts.length - 2].trim(); // Second to last part is usually city
    }
    return null;
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        name,
        email,
        phoneNumber,
        photoUrl,
        category,
        bio,
        address,
        city,
        state,
        latitude,
        longitude,
        rating,
        reviewCount,
        isVerified,
        premium,
        isFeatured,
        isAvailable,
        distance,
        skills,
        completedJobs,
        certifications,
        hourlyRate,
        experienceYears,
        matchType,
        relevanceScore,
        createdAt,
        updatedAt,
      ];

  ArtisanEntity copyWith({
    String? id,
    String? userId,
    String? name,
    String? email,
    String? phoneNumber,
    String? photoUrl,
    String? category,
    String? bio,
    String? address,
    String? city,
    String? state,
    double? latitude,
    double? longitude,
    double? rating,
    int? reviewCount,
    bool? isVerified,
    bool? premium,
    bool? isFeatured,
    bool? isAvailable,
    double? distance,
    List<String>? skills,
    int? completedJobs,
    List<String>? certifications,
    double? hourlyRate,
    String? experienceYears,
    String? matchType,
    double? relevanceScore,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ArtisanEntity(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      photoUrl: photoUrl ?? this.photoUrl,
      category: category ?? this.category,
      bio: bio ?? this.bio,
      address: address ?? this.address,
      city: city ?? this.city,
      state: state ?? this.state,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      isVerified: isVerified ?? this.isVerified,
      premium: premium ?? this.premium,
      isFeatured: isFeatured ?? this.isFeatured,
      isAvailable: isAvailable ?? this.isAvailable,
      distance: distance ?? this.distance,
      skills: skills ?? this.skills,
      completedJobs: completedJobs ?? this.completedJobs,
      certifications: certifications ?? this.certifications,
      hourlyRate: hourlyRate ?? this.hourlyRate,
      experienceYears: experienceYears ?? this.experienceYears,
      matchType: matchType ?? this.matchType,
      relevanceScore: relevanceScore ?? this.relevanceScore,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'ArtisanEntity(id: $id, name: $name, category: $category, city: $displayCity)';
  }
}