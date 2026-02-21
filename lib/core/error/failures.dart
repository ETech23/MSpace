import 'package:equatable/equatable.dart';

abstract class Failure extends Equatable {
  final String message;

  const Failure({required this.message});

  @override
  List<Object?> get props => [message];
}

// Server failure
class ServerFailure extends Failure {
  const ServerFailure({super.message = 'Server error occurred'});
}

// Network failure
class NetworkFailure extends Failure {
  const NetworkFailure({super.message = 'No internet connection'});
}

// Auth failure
class AuthFailure extends Failure {
  const AuthFailure({super.message = 'Authentication failed'});
}

// Cache failure
class CacheFailure extends Failure {
  const CacheFailure({super.message = 'Cache error occurred'});
}

// Validation failure
class ValidationFailure extends Failure {
  const ValidationFailure({super.message = 'Validation failed'});
}