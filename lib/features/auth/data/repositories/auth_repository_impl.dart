import 'package:dartz/dartz.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_local_datasource.dart';
import '../datasources/auth_remote_datasource.dart';
import '../models/user_model.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;
  final AuthLocalDataSource localDataSource;
  final NetworkInfo networkInfo;

  AuthRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
    required this.networkInfo,
  });

  @override
  Future<Either<Failure, UserModel>> login({
    required String email,
    required String password,
  }) async {
    if (await networkInfo.isConnected) {
      try {
        final user = await remoteDataSource.login(
          email: email,
          password: password,
        );
        await localDataSource.cacheUser(user);
        return Right(user);
      } on ServerException catch (e) {
        return Left(ServerFailure(message: e.message));
      } catch (e) {
        return Left(ServerFailure(message: 'Unexpected error: ${e.toString()}'));
      }
    } else {
      return const Left(NetworkFailure());
    }
  }

  @override
  Future<Either<Failure, UserModel>> register({
    required String email,
    required String password,
    required String name,
    required String phone,
    required String userType,
    String? referralCode,
    String? referralSource,
    double? latitude,  
    double? longitude, 
    String? address,   
  }) async {
    if (await networkInfo.isConnected) {
      try {
        final user = await remoteDataSource.register(
          email: email,
          password: password,
          name: name,
          phone: phone,
          userType: userType,
          referralCode: referralCode,
          referralSource: referralSource,
        );
        await localDataSource.cacheUser(user);
        return Right(user);
      } on ServerException catch (e) {
        return Left(ServerFailure(message: e.message));
      } catch (e) {
        return Left(ServerFailure(message: 'Unexpected error: ${e.toString()}'));
      }
    } else {
      return const Left(NetworkFailure());
    }
  }

  @override
  Future<Either<Failure, UserModel>> loginWithGoogle({
    String? preferredUserType,
  }) async {
    if (await networkInfo.isConnected) {
      try {
        final user = await remoteDataSource.loginWithGoogle(
          preferredUserType: preferredUserType,
        );
        await localDataSource.cacheUser(user);
        return Right(user);
      } on ServerException catch (e) {
        return Left(ServerFailure(message: e.message));
      } catch (e) {
        return Left(ServerFailure(message: 'Unexpected error: ${e.toString()}'));
      }
    } else {
      return const Left(NetworkFailure());
    }
  }

  @override
  Future<Either<Failure, void>> logout() async {
    if (await networkInfo.isConnected) {
      try {
        await remoteDataSource.logout();
        await localDataSource.clearCachedUser();
        return const Right(null);
      } on ServerException catch (e) {
        return Left(ServerFailure(message: e.message));
      } catch (e) {
        return Left(ServerFailure(message: 'Unexpected error: ${e.toString()}'));
      }
    } else {
      return const Left(NetworkFailure());
    }
  }

  @override
  Future<Either<Failure, UserModel?>> getCurrentUser() async {
    if (await networkInfo.isConnected) {
      try {
        final user = await remoteDataSource.getCurrentUser();
        if (user != null) {
          await localDataSource.cacheUser(user);
        }
        return Right(user);
      } on ServerException catch (e) {
        final cached = await localDataSource.getCachedUser();
        if (cached != null) {
          return Right(cached);
        }
        return Left(ServerFailure(message: e.message));
      } catch (e) {
        final cached = await localDataSource.getCachedUser();
        if (cached != null) {
          return Right(cached);
        }
        return Left(ServerFailure(message: 'Unexpected error: ${e.toString()}'));
      }
    } else {
      final cached = await localDataSource.getCachedUser();
      if (cached != null) {
        return Right(cached);
      }
      return const Left(NetworkFailure());
    }
  }

  @override
  Future<bool> isAuthenticated() async {
    try {
      final isAuth = await remoteDataSource.isAuthenticated();
      if (isAuth) return true;
      final cached = await localDataSource.getCachedUser();
      return cached != null;
    } catch (e) {
      final cached = await localDataSource.getCachedUser();
      return cached != null;
    }
  }

  @override
  Future<void> updateUserType(String userId, String newType) async {
    try {
      return await remoteDataSource.updateUserType(userId, newType);
    } on ServerException catch (e) {
      throw ServerFailure(message: e.message);
    }
  }
  
  @override
  Future<void> createArtisanProfileIfNeeded(String userId) async {
    try {
      return await remoteDataSource.createArtisanProfileIfNeeded(userId);
    } on ServerException catch (e) {
      throw ServerFailure(message: e.message);
    }
  }

  @override
  Future<void> createBusinessProfileIfNeeded(String userId, {String? businessName}) async {
    try {
      return await remoteDataSource.createBusinessProfileIfNeeded(
        userId,
        businessName: businessName,
      );
    } on ServerException catch (e) {
      throw ServerFailure(message: e.message);
    }
  }

  @override
  Future<void> requestAccountDeletion({required String reason}) async {
    try {
      return await remoteDataSource.requestAccountDeletion(reason: reason);
    } on ServerException catch (e) {
      throw ServerFailure(message: e.message);
    }
  }
}
