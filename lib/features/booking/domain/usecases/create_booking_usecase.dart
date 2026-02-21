import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/booking_entity.dart';
import '../repositories/booking_repository.dart';

class CreateBookingUseCase {
  final BookingRepository repository;

  CreateBookingUseCase(this.repository);

  Future<Either<Failure, BookingEntity>> call({
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
  }) async {
    return await repository.createBooking(
      customerId: customerId,
      artisanId: artisanId,
      artisanProfileId: artisanProfileId,
      serviceType: serviceType,
      description: description,
      preferredDate: preferredDate,
      preferredTime: preferredTime,
      locationAddress: locationAddress,
      locationLatitude: locationLatitude,
      locationLongitude: locationLongitude,
      estimatedPrice: estimatedPrice,
      customerNotes: customerNotes,
    );
  }
}