import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/booking_entity.dart';

abstract class BookingRepository {
  Future<Either<Failure, BookingEntity>> createBooking({
    required String customerId,
    required String artisanId,
    required String artisanProfileId,
    required String serviceType,
    required String description,
    required DateTime preferredDate,
    required String preferredTime,
    required String locationAddress,
    double? locationLatitude,
    double? locationLongitude,
    double? estimatedPrice,
    String? customerNotes,
  });

  Future<Either<Failure, List<BookingEntity>>> getUserBookings({
    required String userId,
    required String userType,
    String? status,
  });

  Future<Either<Failure, BookingEntity>> getBookingById(String bookingId);

  Future<Either<Failure, void>> acceptBooking(String bookingId);

  Future<Either<Failure, void>> rejectBooking({
    required String bookingId,
    required String reason,
  });

  Future<Either<Failure, void>> cancelBooking({
    required String bookingId,
    required String cancelledBy,
    required String reason,
  });

  Future<Either<Failure, void>> startBooking(String bookingId);

  Future<Either<Failure, void>> completeBooking(String bookingId);

  Future<Either<Failure, Map<String, int>>> getBookingStats({
    required String userId,
    required String userType,
  });
}