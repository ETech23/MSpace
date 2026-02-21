// lib/features/profile/data/repositories/user_profile_repository_impl.dart

import 'package:artisan_marketplace/core/error/exceptions.dart';
import 'package:artisan_marketplace/features/profile/data/datasources/user_profile_remote_data_source.dart';
import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/user_profile_entity.dart';
import '../../domain/repositories/user_profile_repository.dart';

class UserProfileRepositoryImpl implements UserProfileRepository {
  final UserProfileRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;

  UserProfileRepositoryImpl({
    required this.remoteDataSource,
    required this.networkInfo,
  });

  @override
  Future<Either<Failure, UserProfileEntity>> getUserProfile({
    required String userId,
    required String userType,
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure());
    }

    try {
      final userProfile = await remoteDataSource.getUserProfile(
        userId: userId,
        userType: userType,
      );
      return Right(userProfile);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return const Left(ServerFailure(message: 'An unexpected error occurred'));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> getUserBookingStats({
    required String userId,
    required String userType,
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure());
    }

    try {
      final stats = await remoteDataSource.getUserBookingStats(
        userId: userId,
        userType: userType,
      );
      return Right(stats);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return const Left(ServerFailure(message: 'An unexpected error occurred'));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> getBasicUserInfo(String userId) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure());
    }

    try {
      final profile = await remoteDataSource.getUserProfile(
        userId: userId,
        userType: 'user',
      );

      return Right({
        'id': profile.id,
        'name': profile.displayName,
        'photoUrl': profile.profilePhotoUrl,
        'rating': profile.rating,
        'isVerified': profile.isVerified,
      });
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return const Left(ServerFailure(message: 'An unexpected error occurred'));
    }
  }
}
