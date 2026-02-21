
// lib/features/messaging/data/repositories/message_repository_impl.dart

import 'package:dartz/dartz.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/conversation_entity.dart';
import '../../domain/entities/message_entity.dart';
import '../../domain/repositories/message_repository.dart';
import '../datasources/message_remote_data_source.dart';

class MessageRepositoryImpl implements MessageRepository {
  final MessageRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;

  MessageRepositoryImpl({
    required this.remoteDataSource,
    required this.networkInfo,
  });

  @override
  Future<Either<Failure, List<ConversationEntity>>> getConversations(String userId) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure());
    }

    try {
      final conversations = await remoteDataSource.getConversations(userId);
      return Right(conversations);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return const Left(ServerFailure(message: 'An unexpected error occurred'));
    }
  }

  @override
  Future<Either<Failure, List<MessageEntity>>> getMessages(String conversationId) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure());
    }

    try {
      final messages = await remoteDataSource.getMessages(conversationId);
      return Right(messages);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return const Left(ServerFailure(message: 'An unexpected error occurred'));
    }
  }

 @override
  Future<Either<Failure, MessageEntity>> sendMessage({
    required String conversationId,
    required String senderId,
    required String messageText,
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure());
    }

    try {
      final message = await remoteDataSource.sendMessage(
        conversationId: conversationId,
        senderId: senderId,
        messageText: messageText,
      );
      return Right(message);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return const Left(ServerFailure(message: 'An unexpected error occurred'));
    }
  }

  // NEW: Voice message implementation
  @override
  Future<Either<Failure, MessageEntity>> sendVoiceMessage({
    required String conversationId,
    required String senderId,
    required String voiceFilePath,
    required int durationSeconds,
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure());
    }

    try {
      final message = await remoteDataSource.sendVoiceMessage(
        conversationId: conversationId,
        senderId: senderId,
        voiceFilePath: voiceFilePath,
        durationSeconds: durationSeconds,
      );
      return Right(message);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return const Left(ServerFailure(message: 'An unexpected error occurred'));
    }
  }

  @override
  Future<Either<Failure, String>> getOrCreateConversation({
    required String userId1,
    required String userId2,
    String? bookingId,
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure());
    }

    try {
      final conversationId = await remoteDataSource.getOrCreateConversation(
        userId1: userId1,
        userId2: userId2,
        bookingId: bookingId,
      );
      return Right(conversationId);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return const Left(ServerFailure(message: 'An unexpected error occurred'));
    }
  }

  @override
  Future<Either<Failure, void>> markMessagesAsRead(
    String conversationId,
    String userId,
  ) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure());
    }

    try {
      await remoteDataSource.markMessagesAsRead(conversationId, userId);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return const Left(ServerFailure(message: 'An unexpected error occurred'));
    }
  }

 @override
Future<Either<Failure, void>> sendFileMessage({
  required String conversationId,
  required String senderId,
  required String filePath,
  required String fileType,
}) async {
  if (!await networkInfo.isConnected) {
    return const Left(NetworkFailure());
  }

  try {
    await remoteDataSource.sendFileMessage(
      conversationId: conversationId,
      senderId: senderId,
      filePath: filePath,
      fileType: fileType,
    );

    return const Right(null);
  } on ServerException catch (e) {
    return Left(ServerFailure(message: e.message));
  } catch (e) {
    return Left(ServerFailure(message: e.toString()));
  }
}



  @override
  Future<Either<Failure, int>> getUnreadMessageCount(String userId) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure());
    }

    try {
      final count = await remoteDataSource.getUnreadMessageCount(userId);
      return Right(count);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return const Left(ServerFailure(message: 'An unexpected error occurred'));
    }
  }

  @override
Stream<List<MessageEntity>> subscribeToMessages(String conversationId) {
  // No need for cast, MessageModel is already a MessageEntity
  return remoteDataSource
      .subscribeToMessages(conversationId)
      .map((models) => List<MessageEntity>.from(models));
}

@override
Stream<List<ConversationEntity>> subscribeToConversations(String userId) {
  // No need for cast, ConversationModel is already a ConversationEntity
  return remoteDataSource
      .subscribeToConversations(userId)
      .map((models) => List<ConversationEntity>.from(models));
}

}