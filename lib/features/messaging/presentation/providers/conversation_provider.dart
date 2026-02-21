// lib/features/messaging/presentation/providers/conversation_provider.dart
// UPDATED: Uses MessageRepository and properly tracks unread count

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/injection_container.dart';
import '../../domain/entities/conversation_entity.dart';
import '../../domain/usecases/get_conversations_usecase.dart';
import '../../domain/usecases/get_unread_count_usecase.dart';
import '../../domain/repositories/message_repository.dart';

// State
class ConversationState {
  final bool isLoading;
  final List<ConversationEntity> conversations;
  final int unreadCount;
  final String? error;

  ConversationState({
    this.isLoading = false,
    this.conversations = const [],
    this.unreadCount = 0,
    this.error,
  });

  ConversationState copyWith({
    bool? isLoading,
    List<ConversationEntity>? conversations,
    int? unreadCount,
    String? error,
    bool clearError = false,
  }) {
    return ConversationState(
      isLoading: isLoading ?? this.isLoading,
      conversations: conversations ?? this.conversations,
      unreadCount: unreadCount ?? this.unreadCount,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

// Notifier
class ConversationNotifier extends StateNotifier<ConversationState> {
  final GetConversationsUseCase getConversationsUseCase;
  final GetUnreadCountUseCase getUnreadCountUseCase;
  final MessageRepository messageRepository;

  StreamSubscription? _conversationSubscription;
  String? _currentUserId;

  ConversationNotifier({
    required this.getConversationsUseCase,
    required this.getUnreadCountUseCase,
    required this.messageRepository,
  }) : super(ConversationState());

  Future<void> loadConversations(String userId) async {
    _currentUserId = userId;
    state = state.copyWith(isLoading: true, clearError: true);

    final result = await getConversationsUseCase(userId);

    result.fold(
      (failure) {
        state = state.copyWith(
          isLoading: false,
          error: failure.message,
        );
      },
      (conversations) {
        state = state.copyWith(
          isLoading: false,
          conversations: conversations,
        );
        _updateUnreadCount(userId);
        
        // Start subscribing to real-time updates
        subscribeToConversations(userId);
      },
    );
  }

  // Subscribe to real-time conversation updates
  void subscribeToConversations(String userId) {
    _currentUserId = userId;
    _conversationSubscription?.cancel();

    _conversationSubscription = messageRepository
        .subscribeToConversations(userId)
        .listen(
      (conversations) {
        // Sort by last message time (newest first)
        final sorted = [...conversations]
          ..sort((a, b) {
            if (a.lastMessageTime == null && b.lastMessageTime == null) {
              return b.createdAt.compareTo(a.createdAt);
            }
            if (a.lastMessageTime == null) return 1;
            if (b.lastMessageTime == null) return -1;
            return b.lastMessageTime!.compareTo(a.lastMessageTime!);
          });

        // Calculate total unread count from all conversations
        final totalUnread = sorted.fold<int>(
          0,
          (sum, conv) => sum + conv.unreadCount,
        );

        state = state.copyWith(
          conversations: sorted,
          unreadCount: totalUnread,
        );
      },
      onError: (error) {
        state = state.copyWith(error: error.toString());
      },
    );
  }

  Future<void> _updateUnreadCount(String userId) async {
    final result = await getUnreadCountUseCase(userId);
    result.fold(
      (_) {},
      (count) {
        state = state.copyWith(unreadCount: count);
      },
    );
  }

  void refreshUnreadCount(String userId) {
    _updateUnreadCount(userId);
  }

  // Force refresh conversations (for pull-to-refresh)
  Future<void> refreshConversations() async {
    if (_currentUserId != null) {
      await loadConversations(_currentUserId!);
    }
  }

  @override
  void dispose() {
    _conversationSubscription?.cancel();
    super.dispose();
  }
}

// Providers
final conversationProvider =
    StateNotifierProvider<ConversationNotifier, ConversationState>((ref) {
  return ConversationNotifier(
    getConversationsUseCase: getIt<GetConversationsUseCase>(),
    getUnreadCountUseCase: getIt<GetUnreadCountUseCase>(),
    messageRepository: getIt<MessageRepository>(),
  );
});

// Unread count provider (for message badges)
final munreadCountProvider = Provider<int>((ref) {
  return ref.watch(conversationProvider).unreadCount;
});