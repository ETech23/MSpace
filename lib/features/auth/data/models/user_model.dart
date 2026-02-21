import 'package:json_annotation/json_annotation.dart';
import '../../domain/entities/user_entity.dart';

part 'user_model.g.dart';

@JsonSerializable()
class UserModel extends UserEntity {
  const UserModel({
    required super.id,
    required super.name,
    required super.email,
    required super.userType,
    super.photoUrl,
    super.phone,
    super.latitude,
    super.longitude,
    super.address,
    required super.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    // ✅ Priority 1: Check for separate latitude/longitude fields (NEW FORMAT)
    double? lat = (json['latitude'] as num?)?.toDouble();
    double? lng = (json['longitude'] as num?)?.toDouble();
    
    // ✅ Priority 2: Fallback to PostGIS location field (OLD FORMAT)
    if (lat == null || lng == null) {
      if (json['location'] != null) {
        final location = json['location'];
        
        // Handle GeoJSON format: {"type": "Point", "coordinates": [lng, lat]}
        if (location is Map && location['coordinates'] != null) {
          final coordinates = location['coordinates'];
          if (coordinates is List && coordinates.length >= 2) {
            lng = (coordinates[0] as num?)?.toDouble();
            lat = (coordinates[1] as num?)?.toDouble();
          }
        }
        // Handle WKT format: "POINT(lng lat)"
        else if (location is String && location.startsWith('POINT(')) {
          try {
            final coordString = location
                .replaceAll('POINT(', '')
                .replaceAll(')', '')
                .trim();
            final coords = coordString.split(' ');
            if (coords.length >= 2) {
              lng = double.tryParse(coords[0]);
              lat = double.tryParse(coords[1]);
            }
          } catch (e) {
            print('⚠️ Error parsing WKT location: $e');
          }
        }
      }
    }

    // Debug logging
    if (lat != null && lng != null) {
      print('✅ UserModel: Loaded location (lat: $lat, lng: $lng)');
    } else {
      print('⚠️ UserModel: No location data for user ${json['name']}');
    }

    return UserModel(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      userType: (json['user_type'] ?? json['role'] ?? 'customer') as String,
      photoUrl: json['photo_url'] as String?,
      phone: json['phone'] as String?,
      latitude: lat,
      longitude: lng,
      address: json['address'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String? ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'id': id,
      'name': name,
      'email': email,
      'user_type': userType,
      'photo_url': photoUrl,
      'phone': phone,
      'address': address,
      'created_at': createdAt.toIso8601String(),
    };

    // ✅ Save BOTH formats for maximum compatibility
    if (latitude != null && longitude != null) {
      // Separate fields (easier to query)
      json['latitude'] = latitude;
      json['longitude'] = longitude;
      
      // PostGIS point format (for spatial queries)
      json['location'] = 'POINT($longitude $latitude)';
    }
    
    return json;
  }

  UserEntity toEntity() => UserEntity(
    id: id,
    name: name,
    email: email,
    userType: userType,
    photoUrl: photoUrl,
    phone: phone,
    latitude: latitude,
    longitude: longitude,
    address: address,
    createdAt: createdAt,
  );
}