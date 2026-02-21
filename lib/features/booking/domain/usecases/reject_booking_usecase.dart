import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../repositories/booking_repository.dart';

class RejectBookingUseCase {
  final BookingRepository repository;

  RejectBookingUseCase(this.repository);

  Future<Either<Failure, void>> call({
    required String bookingId,
    required String reason,
  }) async {
    return await repository.rejectBooking(
      bookingId: bookingId,
      reason: reason,
    );
  }
}
