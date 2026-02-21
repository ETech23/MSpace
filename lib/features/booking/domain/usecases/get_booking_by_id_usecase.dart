import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/booking_entity.dart';
import '../repositories/booking_repository.dart';

class GetBookingByIdUseCase {
  final BookingRepository repository;

  GetBookingByIdUseCase(this.repository);

  Future<Either<Failure, BookingEntity>> call(String bookingId) async {
    return await repository.getBookingById(bookingId);
  }
}