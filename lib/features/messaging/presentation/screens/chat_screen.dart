// lib/features/messaging/presentation/screens/chat_screen.dart
// UPDATED with reverse list - newest messages at bottom like WhatsApp

import 'package:artisan_marketplace/features/messaging/domain/entities/message_entity.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../profile/presentation/screens/user_profile_screen.dart';
import '../providers/message_provider.dart';
import '../widgets/message_bubble.dart';
import '../widgets/chat_input.dart';
import 'dart:io';
import '../widgets/multiple_image_picker.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String conversationId;
  final String otherUserId;
  final String otherUserName;
  final String? otherUserPhotoUrl;

  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserPhotoUrl,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _messageController = TextEditingController();

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(authProvider).user;
      if (user != null) {
        final notifier = ref.read(messageProvider.notifier);

        notifier.loadMessages(widget.conversationId);

        notifier.subscribeToMessages(
          widget.conversationId,
        );

        notifier.markAsRead(widget.conversationId, user.id);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _scrollToBottom({bool animate = false}) {
    if (!_scrollController.hasClients) return;

    // In reverse list, position 0 is the bottom (newest messages)
    if (animate) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } else {
      _scrollController.jumpTo(0.0);
    }
  }

  void _sendMessage() {
    final user = ref.read(authProvider).user;
    if (user == null || _messageController.text.trim().isEmpty) return;

    ref.read(messageProvider.notifier).sendTextMessage(
      conversationId: widget.conversationId,
      senderId: user.id,
      text: _messageController.text.trim(),
    );

    _messageController.clear();
    
    // Scroll to bottom after sending message
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom(animate: true);
    });
  }

  void _sendVoiceMessage(String filePath, int durationSeconds) async {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    await ref.read(messageProvider.notifier).sendVoiceMessage(
      conversationId: widget.conversationId,
      senderId: user.id,
      voiceFilePath: filePath,
      durationSeconds: durationSeconds,
    );

    // Scroll to bottom after sending voice message
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom(animate: true);
    });
  }

  void _sendImages(List<File> imageFiles) async {
    final user = ref.read(authProvider).user;
    if (user == null || imageFiles.isEmpty) return;

    // Show loading indicator
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 16),
            Text('Uploading ${imageFiles.length} image(s)...'),
          ],
        ),
        duration: const Duration(seconds: 30),
      ),
    );

    // Upload all images
    try {
      await ref.read(messageProvider.notifier).sendMultipleImages(
        conversationId: widget.conversationId,
        senderId: user.id,
        imageFiles: imageFiles,
      );

      // Hide loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${imageFiles.length} image(s) sent successfully'),
            backgroundColor: Theme.of(context).colorScheme.primary,
            duration: const Duration(seconds: 2),
          ),
        );
      }

      // Scroll to bottom after sending images
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom(animate: true);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send images: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _pickAndSendImages() async {
    final images = await showMultipleImagePicker(
      context,
      maxImages: 10,
    );

    if (images != null && images.isNotEmpty) {
      _sendImages(images);
    }
  }

  void _navigateToProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserProfileScreen(
          userId: widget.otherUserId,
          userType: 'artisan',
          userName: widget.otherUserName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final messageState = ref.watch(messageProvider);
    final user = ref.watch(authProvider).user;

    ref.listen<MessageState>(messageProvider, (previous, next) {
      // Auto-scroll when new message arrives
      if (previous != null && 
          previous.messages.length < next.messages.length &&
          next.messages.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToBottom(animate: true);
        });
      }

      // Show error if file upload fails
      if (next.error != null && previous?.error != next.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: colorScheme.error,
            action: SnackBarAction(
              label: 'Dismiss',
              textColor: colorScheme.onError,
              onPressed: () {},
            ),
          ),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: InkWell(
          onTap: _navigateToProfile,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: colorScheme.primaryContainer,
                backgroundImage: widget.otherUserPhotoUrl != null
                    ? NetworkImage(widget.otherUserPhotoUrl!)
                    : null,
                child: widget.otherUserPhotoUrl == null
                    ? Icon(
                        Icons.person,
                        size: 20,
                        color: colorScheme.onPrimaryContainer,
                      )
                    : null,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  widget.otherUserName,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _navigateToProfile,
            tooltip: 'View Profile',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: messageState.isLoading && messageState.messages.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : messageState.error != null && messageState.messages.isEmpty
                    ? _buildErrorState(messageState.error!, theme, colorScheme)
                    : messageState.messages.isEmpty && !messageState.isLoading
                        ? _buildEmptyState(theme, colorScheme)
                        : _buildMessageList(messageState, user),
          ),
          ChatInput(
            controller: _messageController,
            onSend: _sendMessage,
            onVoiceSend: _sendVoiceMessage,
            onFileSend: _sendImages,
            onImagePick: _pickAndSendImages,
            isSending: messageState.isSending,
          ),
        ],
      ),
    );
  }

  bool _shouldShowDateSeparator(List messages, int index) {
    // In reverse order, check with next message instead of previous
    if (index == messages.length - 1) return true;

    final currentMessage = messages[index];
    final nextMessage = messages[index + 1];

    final currentDate = DateTime(
      currentMessage.createdAt.year,
      currentMessage.createdAt.month,
      currentMessage.createdAt.day,
    );

    final nextDate = DateTime(
      nextMessage.createdAt.year,
      nextMessage.createdAt.month,
      nextMessage.createdAt.day,
    );

    return !currentDate.isAtSameMomentAs(nextDate);
  }

  Widget _buildMessageList(MessageState messageState, user) {
    // Get all image messages for swipe navigation across messages
    final imageMessages = messageState.messages
        .where((msg) => msg.messageType == MessageType.image)
        .toList();

    // Reverse the messages list so newest appears at bottom
    final reversedMessages = messageState.messages.reversed.toList();

    return ListView.builder(
      controller: _scrollController,
      reverse: true, // This makes the list start from the bottom
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      itemCount: reversedMessages.length,
      itemBuilder: (context, index) {
        final message = reversedMessages[index];
        final isMe = message.isFromMe(user?.id ?? '');

        final showDateSeparator =
            _shouldShowDateSeparator(reversedMessages, index);

        // Find index in image messages list for swipe navigation
        int? imageMessageIndex;
        if (message.messageType == MessageType.image) {
          imageMessageIndex = imageMessages.indexOf(message);
        }

        return Column(
          children: [
            MessageBubble(
              message: message,
              isMe: isMe,
              // Pass all image messages for cross-message swipe navigation
              allImageMessages:
                  message.messageType == MessageType.image ? imageMessages : null,
              messageIndexInImages: imageMessageIndex,
            ),
            if (showDateSeparator)
              _buildDateSeparator(
                message.createdAt,
                Theme.of(context),
                Theme.of(context).colorScheme,
              ),
          ],
        );
      },
    );
  }

  Widget _buildDateSeparator(
    DateTime date,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(date.year, date.month, date.day);

    String dateText;
    if (messageDate.isAtSameMomentAs(today)) {
      dateText = 'Today';
    } else if (messageDate.isAtSameMomentAs(yesterday)) {
      dateText = 'Yesterday';
    } else {
      dateText = DateFormat('MMMM dd, yyyy').format(date);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: Divider(color: colorScheme.outlineVariant),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              dateText,
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Divider(color: colorScheme.outlineVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_outlined,
            size: 64,
            color: colorScheme.onSurfaceVariant.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Start the conversation',
            style: theme.textTheme.titleMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Send a message to ${widget.otherUserName}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(
      String error, ThemeData theme, ColorScheme colorScheme) {
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
              ref
                  .read(messageProvider.notifier)
                  .loadMessages(widget.conversationId);
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}