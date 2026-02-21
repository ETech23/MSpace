import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/booking_entity.dart';
import '../repositories/booking_repository.dart';

class GetUserBookingsUseCase {
  final BookingRepository repository;

  GetUserBookingsUseCase(this.repository);

  Future<Either<Failure, List<BookingEntity>>> call({
    required String userId,
    required String userType,
    String? status,
  }) async {
    return await repository.getUserBookings(
      userId: userId,
      userType: userType,
      status: status,
    );
  }
}