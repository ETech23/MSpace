import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../repositories/booking_repository.dart';

class CancelBookingUseCase {
  final BookingRepository repository;

  CancelBookingUseCase(this.repository);

  Future<Either<Failure, void>> call({
    required String bookingId,
    required String cancelledBy,
    required String reason,
  }) async {
    return await repository.cancelBooking(
      bookingId: bookingId,
      cancelledBy: cancelledBy,
      reason: reason,
    );
  }
}