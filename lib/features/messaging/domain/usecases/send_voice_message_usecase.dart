// ============================================================================
// lib/features/messaging/domain/usecases/send_voice_message_usecase.dart
// ============================================================================

import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/message_entity.dart';
import '../repositories/message_repository.dart';

class SendVoiceMessageUseCase {
  final MessageRepository repository;

  SendVoiceMessageUseCase(this.repository);

  Future<Either<Failure, MessageEntity>> call({
    required String conversationId,
    required String senderId,
    required String voiceFilePath,
    required int durationSeconds,
  }) {
    return repository.sendVoiceMessage(
      conversationId: conversationId,
      senderId: senderId,
      voiceFilePath: voiceFilePath,
      durationSeconds: durationSeconds,
    );
  }
}
