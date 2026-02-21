// lib/features/profile/domain/entities/profile_update_entity.dart
import 'package:equatable/equatable.dart';

class ProfileUpdateEntity extends Equatable {
  // Basic user fields
  final String? name;
  final String? phone;
  final String? address;
  final double? latitude;
  final double? longitude;
  final String? photoUrl;
  
  // Artisan-specific fields (will be ignored for non-artisan users)
  final String? bio;

  const ProfileUpdateEntity({
    this.name,
    this.phone,
    this.address,
    this.latitude,
    this.longitude,
    this.photoUrl,
    this.bio,
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> json = {};
    
    if (name != null) json['name'] = name;
    if (phone != null) json['phone'] = phone;
    if (address != null) json['address'] = address;
    if (latitude != null) json['latitude'] = latitude;
    if (longitude != null) json['longitude'] = longitude;
    if (photoUrl != null) json['photo_url'] = photoUrl;
    
    // Add PostGIS point if we have coordinates
    if (latitude != null && longitude != null) {
      json['location'] = 'POINT($longitude $latitude)';
    }
    
    return json;
  }

  @override
  List<Object?> get props => [
        name,
        phone,
        address,
        latitude,
        longitude,
        photoUrl,
        bio,
      ];
}