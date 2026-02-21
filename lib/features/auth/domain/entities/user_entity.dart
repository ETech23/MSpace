import 'package:equatable/equatable.dart';

class UserEntity extends Equatable {
  final String id;
  final String email;
  final String name;
  final String? phone;
  final String? photoUrl;
  final String? address;
  final double? latitude;
  final double? longitude;
  final String userType; // Changed from 'role' to 'userType'
  final DateTime createdAt;
  final DateTime? updatedAt;

  const UserEntity({
    required this.id,
    required this.email,
    required this.name,
    this.phone,
    this.photoUrl,
    this.address,
    this.latitude,
    this.longitude,
    required this.userType, // Changed from 'role' to 'userType'
    required this.createdAt,
    this.updatedAt,
  });

  bool get isArtisan => userType == 'artisan';
  bool get isClient => userType == 'client';

  @override
  List<Object?> get props => [
        id,
        email,
        name,
        phone,
        photoUrl,
        address,
        latitude,
        longitude,
        userType,
        createdAt,
        updatedAt,
      ];
}