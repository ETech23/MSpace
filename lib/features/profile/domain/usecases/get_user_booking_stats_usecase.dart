// lib/features/profile/domain/usecases/get_user_booking_stats_usecase.dart

import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../repositories/user_profile_repository.dart';

class GetUserBookingStatsUseCase {
  final UserProfileRepository repository;

  GetUserBookingStatsUseCase({required this.repository});

  Future<Either<Failure, Map<String, dynamic>>> call({
    required String userId,
    required String userType,
  }) async {
    return await repository.getUserBookingStats(
      userId: userId,
      userType: userType,
    );
  }
}