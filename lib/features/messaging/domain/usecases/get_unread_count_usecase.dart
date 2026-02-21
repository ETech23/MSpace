// lib/features/messaging/domain/usecases/get_unread_count_usecase.dart
import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../repositories/message_repository.dart';

class GetUnreadCountUseCase {
  final MessageRepository repository;

  GetUnreadCountUseCase(this.repository);

  Future<Either<Failure, int>> call(String userId) {
    return repository.getUnreadMessageCount(userId);
  }
}