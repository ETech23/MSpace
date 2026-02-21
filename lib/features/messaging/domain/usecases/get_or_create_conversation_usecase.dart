
// lib/features/messaging/domain/usecases/get_or_create_conversation_usecase.dart
import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../repositories/message_repository.dart';

class GetOrCreateConversationUseCase {
  final MessageRepository repository;

  GetOrCreateConversationUseCase(this.repository);

  Future<Either<Failure, String>> call({
    required String userId1,
    required String userId2,
    String? bookingId,
  }) {
    return repository.getOrCreateConversation(
      userId1: userId1,
      userId2: userId2,
      bookingId: bookingId,
    );
  }
}