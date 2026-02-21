import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../repositories/booking_repository.dart';

class GetBookingStatsUseCase {
  final BookingRepository repository;

  GetBookingStatsUseCase(this.repository);

  Future<Either<Failure, Map<String, int>>> call({
    required String userId,
    required String userType,
  }) async {
    return await repository.getBookingStats(
      userId: userId,
      userType: userType,
    );
  }
}