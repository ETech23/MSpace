// lib/features/messaging/domain/usecases/send_message_usecase.dart
import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/message_entity.dart';
import '../repositories/message_repository.dart';

class SendMessageUseCase {
  final MessageRepository repository;

  SendMessageUseCase(this.repository);

  Future<Either<Failure, MessageEntity>> call({
    required String conversationId,
    required String senderId,
    required String messageText,
  }) {
    return repository.sendMessage(
      conversationId: conversationId,
      senderId: senderId,
      messageText: messageText,
    );
  }
}
