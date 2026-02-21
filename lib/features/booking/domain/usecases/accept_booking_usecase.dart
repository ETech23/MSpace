import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../repositories/booking_repository.dart';

class AcceptBookingUseCase {
  final BookingRepository repository;

  AcceptBookingUseCase(this.repository);

  Future<Either<Failure, void>> call(String bookingId) async {
    return await repository.acceptBooking(bookingId);
  }
}