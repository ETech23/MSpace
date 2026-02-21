import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../repositories/booking_repository.dart';

class CompleteBookingUseCase {
  final BookingRepository repository;

  CompleteBookingUseCase(this.repository);

  Future<Either<Failure, void>> call(String bookingId) async {
    return await repository.completeBooking(bookingId);
  }
}