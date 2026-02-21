import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../repositories/booking_repository.dart';

class StartBookingUseCase {
  final BookingRepository repository;

  StartBookingUseCase(this.repository);

  Future<Either<Failure, void>> call(String bookingId) async {
    return await repository.startBooking(bookingId);
  }
}
