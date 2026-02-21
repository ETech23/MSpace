// lib/features/messaging/domain/usecases/mark_messages_as_read_usecase.dart
import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../repositories/message_repository.dart';

class MarkMessagesAsReadUseCase {
  final MessageRepository repository;

  MarkMessagesAsReadUseCase(this.repository);

  Future<Either<Failure, void>> call(String conversationId, String userId) {
    return repository.markMessagesAsRead(conversationId, userId);
  }
}