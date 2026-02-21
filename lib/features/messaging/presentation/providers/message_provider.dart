// ============================================================================
// lib/features/messaging/presentation/providers/message_provider.dart
// CLEAN, FIXED & STABLE VERSION
// ============================================================================

import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/injection_container.dart';
import '../../domain/entities/message_entity.dart';
import '../../domain/repositories/message_repository.dart';
import '../../domain/usecases/get_messages_usecase.dart';
import '../../domain/usecases/mark_messages_as_read_usecase.dart';
import '../../domain/usecases/send_file_message_usecase.dart';
import '../../domain/usecases/send_message_usecase.dart';
import '../../domain/usecases/send_voice_message_usecase.dart';

// ============================================================================
// STATE
// ============================================================================

class MessageState {
  final bool isLoading;
  final bool isSending;
  final List<MessageEntity> messages;
  final String? error;

  const MessageState({
    this.isLoading = false,
    this.isSending = false,
    this.messages = const [],
    this.error,
  });

  MessageState copyWith({
    bool? isLoading,
    bool? isSending,
    List<MessageEntity>? messages,
    String? error,
    bool clearError = false,
  }) {
    return MessageState(
      isLoading: isLoading ?? this.isLoading,
      isSending: isSending ?? this.isSending,
      messages: messages ?? this.messages,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

// ============================================================================
// NOTIFIER
// ============================================================================

class MessageNotifier extends StateNotifier<MessageState> {
  final GetMessagesUseCase getMessagesUseCase;
  final SendMessageUseCase sendMessageUseCase;
  final SendVoiceMessageUseCase sendVoiceMessageUseCase;
  final SendFileMessageUseCase sendFileMessageUseCase;
  final MarkMessagesAsReadUseCase markMessagesAsReadUseCase;
  final MessageRepository messageRepository;

  StreamSubscription<List<MessageEntity>>? _messageSubscription;

  MessageNotifier({
    required this.getMessagesUseCase,
    required this.sendMessageUseCase,
    required this.sendVoiceMessageUseCase,
    required this.sendFileMessageUseCase,
    required this.markMessagesAsReadUseCase,
    required this.messageRepository,
  }) : super(const MessageState());

  // ============================================================================
  // LOAD MESSAGES
  // ============================================================================

  Future<void> loadMessages(String conversationId) async {
    state = state.copyWith(isLoading: true, clearError: true);

    final result = await getMessagesUseCase(conversationId);

    result.fold(
      (failure) {
        state = state.copyWith(
          isLoading: false,
          error: failure.message,
        );
      },
      (messages) {
        final sorted = [...messages]
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

        state = state.copyWith(
          isLoading: false,
          messages: sorted,
        );
      },
    );
  }

  // ============================================================================
  // REAL-TIME SUBSCRIPTION
  // ============================================================================

  void subscribeToMessages(String conversationId) {
    _messageSubscription?.cancel();

    _messageSubscription = messageRepository
        .subscribeToMessages(conversationId)
        .listen((messages) {
      final sorted = [...messages]
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

      state = state.copyWith(messages: sorted);
    });
  }

  // ============================================================================
  // TEXT MESSAGE
  // ============================================================================

  Future<void> sendTextMessage({
    required String conversationId,
    required String senderId,
    required String text,
  }) async {
    if (text.trim().isEmpty) return;

    state = state.copyWith(isSending: true, clearError: true);

    final result = await sendMessageUseCase(
      conversationId: conversationId,
      senderId: senderId,
      messageText: text.trim(),
    );

    result.fold(
      (failure) {
        state = state.copyWith(
          isSending: false,
          error: failure.message,
        );
      },
      (_) {
        state = state.copyWith(isSending: false);
      },
    );
  }

  // ============================================================================
  // VOICE MESSAGE
  // ============================================================================

  Future<void> sendVoiceMessage({
    required String conversationId,
    required String senderId,
    required String voiceFilePath,
    required int durationSeconds,
  }) async {
    state = state.copyWith(isSending: true, clearError: true);

    final result = await sendVoiceMessageUseCase(
      conversationId: conversationId,
      senderId: senderId,
      voiceFilePath: voiceFilePath,
      durationSeconds: durationSeconds,
    );

    result.fold(
      (failure) {
        state = state.copyWith(
          isSending: false,
          error: failure.message,
        );
      },
      (_) {
        state = state.copyWith(isSending: false);
      },
    );
  }

  // ============================================================================
  // MULTIPLE IMAGE MESSAGE (NO NULL SERVICES)
  // ============================================================================

  Future<void> sendMultipleImages({
    required String conversationId,
    required String senderId,
    required List<File> imageFiles,
  }) async {
    if (imageFiles.isEmpty) return;

    state = state.copyWith(isSending: true, clearError: true);

    try {
      for (final image in imageFiles) {
        final result = await sendFileMessageUseCase(
          conversationId: conversationId,
          senderId: senderId,
          filePath: image.path,
          fileType: 'image',
        );

        result.fold(
          (failure) => throw Exception(failure.message),
          (_) {},
        );
      }

      state = state.copyWith(isSending: false);
    } catch (e) {
      state = state.copyWith(
        isSending: false,
        error: e.toString(),
      );
      rethrow;
    }
  }

  // ============================================================================
  // GENERIC FILE MESSAGE
  // ============================================================================

  Future<void> sendFileMessage({
    required String conversationId,
    required String senderId,
    required String filePath,
    required String fileType,
  }) async {
    state = state.copyWith(isSending: true, clearError: true);

    final result = await sendFileMessageUseCase(
      conversationId: conversationId,
      senderId: senderId,
      filePath: filePath,
      fileType: fileType,
    );

    result.fold(
      (failure) {
        state = state.copyWith(
          isSending: false,
          error: failure.message,
        );
      },
      (_) {
        state = state.copyWith(isSending: false);
      },
    );
  }

  // ============================================================================
  // MARK AS READ
  // ============================================================================

  Future<void> markAsRead(String conversationId, String userId) async {
    await markMessagesAsReadUseCase(conversationId, userId);
  }

  // ============================================================================
  // CLEANUP
  // ============================================================================

  @override
  void dispose() {
    _messageSubscription?.cancel();
    super.dispose();
  }
}

// ============================================================================
// PROVIDER
// ============================================================================

final messageProvider =
    StateNotifierProvider<MessageNotifier, MessageState>(
  (ref) => MessageNotifier(
    getMessagesUseCase: getIt<GetMessagesUseCase>(),
    sendMessageUseCase: getIt<SendMessageUseCase>(),
    sendVoiceMessageUseCase: getIt<SendVoiceMessageUseCase>(),
    sendFileMessageUseCase: getIt<SendFileMessageUseCase>(),
    markMessagesAsReadUseCase: getIt<MarkMessagesAsReadUseCase>(),
    messageRepository: getIt<MessageRepository>(),
  ),
);
