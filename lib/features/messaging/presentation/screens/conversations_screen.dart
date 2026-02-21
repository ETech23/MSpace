// lib/features/messaging/presentation/screens/conversations_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/conversation_provider.dart';
import 'chat_screen.dart';

class ConversationsScreen extends ConsumerStatefulWidget {
  const ConversationsScreen({super.key});

  @override
  ConsumerState<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends ConsumerState<ConversationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(authProvider).user;
      if (user != null) {
        ref.read(conversationProvider.notifier).loadConversations(user.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final conversationState = ref.watch(conversationProvider);
    final user = ref.watch(authProvider).user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        centerTitle: true,
        actions: [
          // Unread count badge
          if (conversationState.unreadCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: colorScheme.error,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${conversationState.unreadCount}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onError,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: conversationState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : conversationState.error != null
              ? _buildErrorState(conversationState.error!, theme, colorScheme)
              : conversationState.conversations.isEmpty
                  ? _buildEmptyState(theme, colorScheme)
                  : RefreshIndicator(
                      onRefresh: () async {
                        if (user != null) {
                          await ref
                              .read(conversationProvider.notifier)
                              .loadConversations(user.id);
                        }
                      },
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: conversationState.conversations.length,
                        separatorBuilder: (context, index) => Divider(
                          height: 1,
                          indent: 88,
                          color: colorScheme.outlineVariant,
                        ),
                        itemBuilder: (context, index) {
                          final conversation = conversationState.conversations[index];
                          return _buildConversationItem(
                            conversation,
                            user?.id ?? '',
                            theme,
                            colorScheme,
                          );
                        },
                      ),
                    ),
    );
  }

 Widget _buildConversationItem(
  conversation,
  String currentUserId,
  ThemeData theme,
  ColorScheme colorScheme,
) {
  final hasUnread = conversation.unreadCount > 0;
  final isLastMessageFromMe =
      conversation.isLastMessageFromMe(currentUserId);

  final otherUserId =
      conversation.getOtherUserId(currentUserId);

  final otherUserName =
      conversation.getOtherUserName(currentUserId) ?? 'User';

  final otherUserPhoto =
      conversation.getOtherUserPhotoUrl(currentUserId);

  return InkWell(
    onTap: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            conversationId: conversation.id,
            otherUserId: otherUserId,
            otherUserName: otherUserName,
            otherUserPhotoUrl: otherUserPhoto,
          ),
        ),
      );
    },
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: colorScheme.primaryContainer,
            backgroundImage:
                otherUserPhoto != null ? NetworkImage(otherUserPhoto) : null,
            child: otherUserPhoto == null
                ? Icon(
                    Icons.person,
                    size: 32,
                    color: colorScheme.onPrimaryContainer,
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        otherUserName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight:
                              hasUnread ? FontWeight.bold : FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (conversation.lastMessageTime != null)
                      Text(
                        timeago.format(conversation.lastMessageTime!),
                        style: theme.textTheme.bodySmall,
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  conversation.lastMessageText ?? 'No messages yet',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}


  Widget _buildEmptyState(ThemeData theme, ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 80,
            color: colorScheme.onSurfaceVariant.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No messages yet',
            style: theme.textTheme.titleLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start a conversation from a booking\nor artisan profile',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error, ThemeData theme, ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            'Error loading messages',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              error,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () {
              final user = ref.read(authProvider).user;
              if (user != null) {
                ref.read(conversationProvider.notifier).loadConversations(user.id);
              }
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}