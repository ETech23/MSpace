import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../data/models/user_model.dart';

/// Abstract repository interface for authentication operations
/// This defines the contract that the implementation must follow
abstract class AuthRepository {
  /// Login with email and password
  Future<Either<Failure, UserModel>> login({
    required String email,
    required String password,
  });

  /// Register a new user
  Future<Either<Failure, UserModel>> register({
    required String email,
    required String password,
    required String name,
    required String phone,
    required String userType,
    double? latitude,   // ✅ ADD
    double? longitude,  // ✅ ADD
    String? address,    // ✅ ADD
  });

  /// Logout current user
  Future<Either<Failure, void>> logout();

  /// Get current user if authenticated
  Future<Either<Failure, UserModel?>> getCurrentUser();

  /// Check if user is authenticated
  Future<bool> isAuthenticated();

  Future<void> updateUserType(String userId, String newType);
  Future<void> createArtisanProfileIfNeeded(String userId);
  Future<void> requestAccountDeletion({required String reason});
}
