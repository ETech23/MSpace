// ================================================
// BOOKING REPOSITORY IMPLEMENTATION
// lib/features/booking/data/repositories/booking_repository_impl.dart
// ================================================
import 'package:dartz/dartz.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/booking_entity.dart';
import '../../domain/repositories/booking_repository.dart';
import '../datasources/booking_remote_datasource.dart';

class BookingRepositoryImpl implements BookingRepository {
  final BookingRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;

  BookingRepositoryImpl({
    required this.remoteDataSource,
    required this.networkInfo,
  });

  @override
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
  }) async {
    if (await networkInfo.isConnected) {
      try {
        final booking = await remoteDataSource.createBooking(
          clientId: customerId,
          artisanId: artisanId,
          artisanProfileId: artisanProfileId,
          serviceType: serviceType,
          description: description,
          scheduledDate: preferredDate,
          locationAddress: locationAddress,
          locationLatitude: locationLatitude,
          locationLongitude: locationLongitude,
          estimatedPrice: estimatedPrice,
          customerNotes: customerNotes,
        );
        return Right(booking.toEntity());
      } on ServerException catch (e) {
        return Left(ServerFailure(message: e.message));
      }
    } else {
      return const Left(NetworkFailure());
    }
  }

  @override
  Future<Either<Failure, List<BookingEntity>>> getUserBookings({
    required String userId,
    required String userType,
    String? status,
    int limit = 20,
    int offset = 0,
  }) async {
    if (await networkInfo.isConnected) {
      try {
        final bookings = await remoteDataSource.getUserBookings(
          userId: userId,
          userType: userType,
          status: status,
          limit: limit,
          offset: offset,
        );
        return Right(bookings.map((b) => b.toEntity()).toList());
      } on ServerException catch (e) {
        return Left(ServerFailure(message: e.message));
      }
    } else {
      return const Left(NetworkFailure());
    }
  }

  @override
  Future<Either<Failure, BookingEntity>> getBookingById(String bookingId) async {
    if (await networkInfo.isConnected) {
      try {
        final booking = await remoteDataSource.getBookingById(bookingId);
        return Right(booking.toEntity());
      } on ServerException catch (e) {
        return Left(ServerFailure(message: e.message));
      }
    } else {
      return const Left(NetworkFailure());
    }
  }

  @override
  Future<Either<Failure, void>> updateBookingStatus({
    required String bookingId,
    required String newStatus,
    String? reason,
  }) async {
    if (await networkInfo.isConnected) {
      try {
        await remoteDataSource.updateBookingStatus(
          bookingId: bookingId,
          newStatus: newStatus,
          reason: reason,
        );
        return const Right(null);
      } on ServerException catch (e) {
        return Left(ServerFailure(message: e.message));
      }
    } else {
      return const Left(NetworkFailure());
    }
  }

  @override
  Future<Either<Failure, void>> cancelBooking({
    required String bookingId,
    required String cancelledBy,
    required String reason,
  }) async {
    if (await networkInfo.isConnected) {
      try {
        await remoteDataSource.cancelBooking(
          bookingId: bookingId,
          cancelledBy: cancelledBy,
          reason: reason,
        );
        return const Right(null);
      } on ServerException catch (e) {
        return Left(ServerFailure(message: e.message));
      }
    } else {
      return const Left(NetworkFailure());
    }
  }

  @override
  Future<Either<Failure, void>> acceptBooking(String bookingId) async {
    if (await networkInfo.isConnected) {
      try {
        await remoteDataSource.acceptBooking(bookingId);
        return const Right(null);
      } on ServerException catch (e) {
        return Left(ServerFailure(message: e.message));
      }
    } else {
      return const Left(NetworkFailure());
    }
  }

  @override
  Future<Either<Failure, void>> rejectBooking({
    required String bookingId,
    required String reason,
  }) async {
    if (await networkInfo.isConnected) {
      try {
        await remoteDataSource.rejectBooking(
          bookingId: bookingId,
          reason: reason,
        );
        return const Right(null);
      } on ServerException catch (e) {
        return Left(ServerFailure(message: e.message));
      }
    } else {
      return const Left(NetworkFailure());
    }
  }

  @override
  Future<Either<Failure, void>> startBooking(String bookingId) async {
    if (await networkInfo.isConnected) {
      try {
        await remoteDataSource.startBooking(bookingId);
        return const Right(null);
      } on ServerException catch (e) {
        return Left(ServerFailure(message: e.message));
      }
    } else {
      return const Left(NetworkFailure());
    }
  }

  @override
  Future<Either<Failure, void>> completeBooking(String bookingId) async {
    if (await networkInfo.isConnected) {
      try {
        await remoteDataSource.completeBooking(bookingId);
        return const Right(null);
      } on ServerException catch (e) {
        return Left(ServerFailure(message: e.message));
      }
    } else {
      return const Left(NetworkFailure());
    }
  }

  @override
  Future<Either<Failure, Map<String, int>>> getBookingStats({
    required String userId,
    required String userType,
  }) async {
    if (await networkInfo.isConnected) {
      try {
        final stats = await remoteDataSource.getBookingStats(
          userId: userId,
          userType: userType,
        );
        return Right(stats);
      } on ServerException catch (e) {
        return Left(ServerFailure(message: e.message));
      }
    } else {
      return const Left(NetworkFailure());
    }
  }
}