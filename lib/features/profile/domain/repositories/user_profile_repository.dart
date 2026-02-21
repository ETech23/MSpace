// lib/features/profile/domain/repositories/user_profile_repository.dart

import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/user_profile_entity.dart';

abstract class UserProfileRepository {
  // Get user profile by ID and type
  Future<Either<Failure, UserProfileEntity>> getUserProfile({
    required String userId,
    required String userType, // 'artisan' or 'client'
  });
  
  // Get user booking statistics
  Future<Either<Failure, Map<String, dynamic>>> getUserBookingStats({
    required String userId,
    required String userType,
  });
  
  // Get basic user info (for quick display)
  Future<Either<Failure, Map<String, dynamic>>> getBasicUserInfo(String userId);
}