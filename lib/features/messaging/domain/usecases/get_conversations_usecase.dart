// lib/features/messaging/domain/usecases/get_conversations_usecase.dart
import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/conversation_entity.dart';
import '../repositories/message_repository.dart';

class GetConversationsUseCase {
  final MessageRepository repository;

  GetConversationsUseCase(this.repository);

  Future<Either<Failure, List<ConversationEntity>>> call(String userId) {
    return repository.getConversations(userId);
  }
}