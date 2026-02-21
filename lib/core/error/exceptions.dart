// lib/core/error/exceptions.dart

/// Base exception for server-related errors
class ServerException implements Exception {
  final String message;

  const ServerException({this.message = 'Server error occurred'});

  @override
  String toString() => 'ServerException: $message';
}

/// Exception for when there's no internet connection
class NetworkException implements Exception {
  final String message;

  const NetworkException({this.message = 'No internet connection'});

  @override
  String toString() => 'NetworkException: $message';
}

/// Exception for cache-related errors
class CacheException implements Exception {
  final String message;

  const CacheException({this.message = 'Cache error occurred'});

  @override
  String toString() => 'CacheException: $message';
}

/// Exception for authentication errors
/// Named AppAuthException to avoid conflict with Supabase's AuthException
class AppAuthException implements Exception {
  final String message;

  const AppAuthException({this.message = 'Authentication failed'});

  @override
  String toString() => 'AppAuthException: $message';
}

/// Exception for validation errors
class ValidationException implements Exception {
  final String message;
  final Map<String, String>? fieldErrors;

  const ValidationException({
    this.message = 'Validation failed',
    this.fieldErrors,
  });

  @override
  String toString() => 'ValidationException: $message';
}

/// Exception for not found errors
class NotFoundException implements Exception {
  final String message;

  const NotFoundException({this.message = 'Resource not found'});

  @override
  String toString() => 'NotFoundException: $message';
}

/// Exception for permission/authorization errors
class UnauthorizedException implements Exception {
  final String message;

  const UnauthorizedException({this.message = 'Unauthorized access'});

  @override
  String toString() => 'UnauthorizedException: $message';
}
