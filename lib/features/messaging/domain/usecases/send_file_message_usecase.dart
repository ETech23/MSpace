import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../repositories/message_repository.dart';

class SendFileMessageUseCase {
  final MessageRepository repository;

  SendFileMessageUseCase(this.repository);
 
  Future<Either<Failure, void>> call({
    required String conversationId,
    required String senderId,
    required String filePath,
    required String fileType,
  }) {
    return repository.sendFileMessage(
      conversationId: conversationId,
      senderId: senderId,
      filePath: filePath,
      fileType: fileType,
    );
  }
}
