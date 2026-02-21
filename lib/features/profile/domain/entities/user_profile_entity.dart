// lib/features/profile/domain/entities/user_profile_entity.dart

class UserProfileEntity {
  final String id;
  final String displayName;
  final String userType; // 'artisan' or 'client'
  final String? profilePhotoUrl;
  final String? phone;
  final String? email;
  final String? location;
  final double? rating;
  final int? totalReviews;
  final String? category;
  final int? yearsOfExperience;
  final List<String>? skills;
  final DateTime? memberSince;
  final String? bio;
  final List<String>? portfolioImages;
  final bool? isVerified;

  UserProfileEntity({
    required this.id,
    required this.displayName,
    required this.userType,
    this.profilePhotoUrl,
    this.phone,
    this.email,
    this.location,
    this.rating,
    this.totalReviews,
    this.category,
    this.yearsOfExperience,
    this.skills,
    this.memberSince,
    this.bio,
    this.portfolioImages,
    this.isVerified,
  });

  factory UserProfileEntity.fromJson(Map<String, dynamic> json) {
    return UserProfileEntity(
      id: json['id'] as String,
      displayName: json['displayName'] ?? json['fullName'] ?? 'Unknown User',
      userType: json['userType'] as String,
      profilePhotoUrl: json['profilePhotoUrl'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      location: json['location'] as String?,
      rating: json['rating'] != null ? (json['rating'] as num).toDouble() : null,
      totalReviews: json['totalReviews'] as int?,
      category: json['category'] as String?,
      yearsOfExperience: json['yearsOfExperience'] as int?,
      skills: json['skills'] != null 
          ? List<String>.from(json['skills']) 
          : null,
      memberSince: json['memberSince'] != null 
          ? DateTime.parse(json['memberSince'] as String) 
          : null,
      bio: json['bio'] as String?,
      portfolioImages: json['portfolioImages'] != null
          ? List<String>.from(json['portfolioImages'])
          : null,
      isVerified: json['isVerified'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'displayName': displayName,
      'userType': userType,
      'profilePhotoUrl': profilePhotoUrl,
      'phone': phone,
      'email': email,
      'location': location,
      'rating': rating,
      'totalReviews': totalReviews,
      'category': category,
      'yearsOfExperience': yearsOfExperience,
      'skills': skills,
      'memberSince': memberSince?.toIso8601String(),
      'bio': bio,
      'portfolioImages': portfolioImages,
      'isVerified': isVerified,
    };
  }
}