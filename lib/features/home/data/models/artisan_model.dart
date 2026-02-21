import '../../domain/entities/artisan_entity.dart';

class ArtisanModel extends ArtisanEntity {
  const ArtisanModel({
    required super.id,
    required super.userId,
    required super.name,
    required super.email,
    super.phoneNumber,
    super.photoUrl,
    required super.category,
    super.bio,
    super.address,
    super.latitude,
    super.longitude,
    super.rating,
    super.reviewCount,
    super.isVerified,
    super.premium,
    super.isFeatured,
    super.isAvailable,
    super.distance,
    super.skills,
    super.completedJobs,
    super.certifications,
    super.hourlyRate,
    super.experienceYears,
    required super.createdAt,
    super.updatedAt,
  });

  factory ArtisanModel.fromJson(Map<String, dynamic> json) {
  // Extract coordinates from users object
  double? lat;
  double? lng;
  String? address;
  String name = 'Unknown';
  String email = '';
  String? photoUrl;

  if (json['users'] != null && json['users'] is Map) {
    final user = json['users'] as Map<String, dynamic>;
    name = user['name'] ?? 'Unknown';
    email = user['email'] ?? '';
    photoUrl = user['photo_url'];
    address = user['address'] as String?;
    
    // ✅ Now latitude and longitude are direct fields
    lat = (user['latitude'] as num?)?.toDouble();
    lng = (user['longitude'] as num?)?.toDouble();
    
    print('🔍 Parsed user: $name, lat=$lat, lng=$lng, address=$address');
  }

  return ArtisanModel(
    id: json['id'] as String,
    userId: json['user_id'] as String,
    name: name,
    email: email,
    phoneNumber: json['phone_number'] as String?,
    photoUrl: photoUrl,
    category: json['category'] as String? ?? 'General',
    skills: json['skills'] != null ? List<String>.from(json['skills']) : [],
    bio: json['bio'] as String?,
    experienceYears: json['experience_years']?.toString(),
    hourlyRate: (json['hourly_rate'] as num?)?.toDouble(),
    rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
    reviewCount: json['reviews_count'] as int? ?? 0,
    isVerified: json['verified'] as bool? ?? false,
    premium: json['premium'] as bool? ?? false,
    isFeatured: json['premium'] as bool? ?? false,
    isAvailable: (json['availability_status'] as String?) == 'available',
    completedJobs: json['completed_jobs'] as int? ?? 0,
    latitude: lat,
    longitude: lng,
    address: address,
    distance: (json['distance_km'] as num?)?.toDouble(),
    certifications: json['certifications'] != null 
        ? List<String>.from(json['certifications']) 
        : null,
    createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    updatedAt: json['updated_at'] != null
        ? DateTime.tryParse(json['updated_at'])
        : null,
  );
}

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'name': name,
        'email': email,
        'phone_number': phoneNumber,
        'photo_url': photoUrl,
        'category': category,
        'skills': skills,
        'bio': bio,
        'experience_years': experienceYears,
        'hourly_rate': hourlyRate,
        'rating': rating,
        'reviews_count': reviewCount,
        'verified': isVerified,
        'premium': premium,
        'availability_status': isAvailable ? 'available' : 'unavailable',
        'completed_jobs': completedJobs,
        'address': address,
        'distance_km': distance,
        'certifications': certifications,
      };

  ArtisanEntity toEntity() => ArtisanEntity(
        id: id,
        userId: userId,
        name: name,
        email: email,
        phoneNumber: phoneNumber,
        photoUrl: photoUrl,
        category: category,
        bio: bio,
        address: address,
        latitude: latitude,
        longitude: longitude,
        rating: rating,
        reviewCount: reviewCount,
        isVerified: isVerified,
        premium: premium,
        isFeatured: isFeatured,
        isAvailable: isAvailable,
        distance: distance,
        skills: skills,
        completedJobs: completedJobs,
        certifications: certifications,
        hourlyRate: hourlyRate,
        experienceYears: experienceYears,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}