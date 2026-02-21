// lib/features/messaging/domain/repositories/message_repository.dart
import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/conversation_entity.dart';
import '../entities/message_entity.dart';

abstract class MessageRepository {
  Future<Either<Failure, List<ConversationEntity>>> getConversations(String userId);
  Future<Either<Failure, List<MessageEntity>>> getMessages(String conversationId);
  
  // Existing text message method
  Future<Either<Failure, MessageEntity>> sendMessage({
    required String conversationId,
    required String senderId,
    required String messageText,
  });
  
  // NEW: Voice message method
  Future<Either<Failure, MessageEntity>> sendVoiceMessage({
    required String conversationId,
    required String senderId,
    required String voiceFilePath,
    required int durationSeconds,
  });
  
  Future<Either<Failure, String>> getOrCreateConversation({
    required String userId1,
    required String userId2,
    String? bookingId,
  });
  Future<Either<Failure, void>> markMessagesAsRead(String conversationId, String userId);
  Future<Either<Failure, int>> getUnreadMessageCount(String userId);
  Stream<List<MessageEntity>> subscribeToMessages(String conversationId);
  Stream<List<ConversationEntity>> subscribeToConversations(String userId);

  Future<Either<Failure, void>> sendFileMessage({
    required String conversationId,
    required String senderId,
    required String filePath,
    required String fileType,
  });
}