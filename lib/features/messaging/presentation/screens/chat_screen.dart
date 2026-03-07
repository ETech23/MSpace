// lib/features/messaging/presentation/screens/chat_screen.dart
import 'package:artisan_marketplace/features/messaging/domain/entities/message_entity.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class _ChatScreenState extends ConsumerState<ChatScreen>
    with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _messageController = TextEditingController();
  bool _showScrollFab = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(authProvider).user;
      if (user != null) {
        final notifier = ref.read(messageProvider.notifier);
        notifier.loadMessages(widget.conversationId);
        notifier.subscribeToMessages(widget.conversationId);
        notifier.markAsRead(widget.conversationId, user.id);
      }
    });
  }

  void _onScroll() {
    final show = _scrollController.hasClients && _scrollController.offset > 120;
    if (show != _showScrollFab) setState(() => _showScrollFab = show);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _scrollToBottom({bool animate = false}) {
    if (!_scrollController.hasClients) return;
    if (animate) {
      _scrollController.animateTo(0.0,
          duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
    } else {
      _scrollController.jumpTo(0.0);
    }
  }

  void _sendMessage() {
    final user = ref.read(authProvider).user;
    if (user == null || _messageController.text.trim().isEmpty) return;
    HapticFeedback.lightImpact();
    ref.read(messageProvider.notifier).sendTextMessage(
      conversationId: widget.conversationId,
      senderId: user.id,
      text: _messageController.text.trim(),
    );
    _messageController.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom(animate: true));
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
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom(animate: true));
  }

  void _sendImages(List<File> imageFiles) async {
    final user = ref.read(authProvider).user;
    if (user == null || imageFiles.isEmpty) return;

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        SizedBox(
          width: 18, height: 18,
          child: CircularProgressIndicator(
              strokeWidth: 2, color: Theme.of(context).colorScheme.onPrimary),
        ),
        const SizedBox(width: 14),
        Text('Uploading ${imageFiles.length} image(s)…'),
      ]),
      duration: const Duration(seconds: 30),
    ));

    try {
      await ref.read(messageProvider.notifier).sendMultipleImages(
        conversationId: widget.conversationId,
        senderId: user.id,
        imageFiles: imageFiles,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${imageFiles.length} image(s) sent'),
          backgroundColor: Theme.of(context).colorScheme.primary,
          duration: const Duration(seconds: 2),
        ));
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom(animate: true));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to send images: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ));
      }
    }
  }

  Future<void> _pickAndSendImages() async {
    final images = await showMultipleImagePicker(context, maxImages: 10);
    if (images != null && images.isNotEmpty) _sendImages(images);
  }

  Future<void> _sendDocument(String filePath) async {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    await ref.read(messageProvider.notifier).sendFileMessage(
      conversationId: widget.conversationId,
      senderId: user.id,
      filePath: filePath,
      fileType: 'document',
    );
  }

  void _navigateToProfile() {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => UserProfileScreen(
        userId: widget.otherUserId,
        userType: 'artisan',
        userName: widget.otherUserName,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final messageState = ref.watch(messageProvider);
    final user = ref.watch(authProvider).user;

    ref.listen<MessageState>(messageProvider, (prev, next) {
      if (prev != null && prev.messages.length < next.messages.length && next.messages.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom(animate: true));
      }
      if (next.error != null && prev?.error != next.error) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(next.error!),
          backgroundColor: colorScheme.error,
          action: SnackBarAction(
              label: 'Dismiss', textColor: colorScheme.onError, onPressed: () {}),
        ));
      }
    });

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0E0E0F)
          : const Color(0xFFF5F5F7),
      appBar: _ChatAppBar(
        otherUserName: widget.otherUserName,
        otherUserPhotoUrl: widget.otherUserPhotoUrl,
        colorScheme: colorScheme,
        isDark: isDark,
        onTap: _navigateToProfile,
        onInfo: _navigateToProfile,
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: messageState.isLoading && messageState.messages.isEmpty
                    ? _ChatLoadingState(colorScheme: colorScheme)
                    : messageState.error != null && messageState.messages.isEmpty
                        ? _ChatErrorState(
                            error: messageState.error!,
                            onRetry: () => ref.read(messageProvider.notifier)
                                .loadMessages(widget.conversationId),
                            colorScheme: colorScheme,
                          )
                        : messageState.messages.isEmpty && !messageState.isLoading
                            ? _ChatEmptyState(
                                otherUserName: widget.otherUserName,
                                colorScheme: colorScheme,
                              )
                            : _buildMessageList(messageState, user, colorScheme, isDark),
              ),

              // Input
              _ChatInputWrapper(
                controller: _messageController,
                onSend: _sendMessage,
                onVoiceSend: _sendVoiceMessage,
                onFileSend: _sendImages,
                onDocumentSend: _sendDocument,
                onImagePick: _pickAndSendImages,
                isSending: messageState.isSending,
                colorScheme: colorScheme,
                isDark: isDark,
              ),
            ],
          ),

          // Scroll to bottom FAB
          AnimatedPositioned(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            right: 16,
            bottom: _showScrollFab ? 88 : 40,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: _showScrollFab ? 1.0 : 0.0,
              child: GestureDetector(
                onTap: () => _scrollToBottom(animate: true),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.primary.withOpacity(0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(Icons.keyboard_arrow_down_rounded,
                      size: 22, color: colorScheme.onPrimary),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _shouldShowDateSeparator(List messages, int index) {
    if (index == messages.length - 1) return true;
    final cur = messages[index].createdAt;
    final nxt = messages[index + 1].createdAt;
    return DateTime(cur.year, cur.month, cur.day) !=
        DateTime(nxt.year, nxt.month, nxt.day);
  }

  Widget _buildMessageList(
      MessageState state, user, ColorScheme cs, bool isDark) {
    final imageMessages =
        state.messages.where((m) => m.messageType == MessageType.image).toList();
    final reversed = state.messages.reversed.toList();

    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      itemCount: reversed.length,
      itemBuilder: (context, index) {
        final message = reversed[index];
        final isMe = message.isFromMe(user?.id ?? '');
        final showDate = _shouldShowDateSeparator(reversed, index);
        int? imgIdx;
        if (message.messageType == MessageType.image) {
          imgIdx = imageMessages.indexOf(message);
        }
        return Column(children: [
          MessageBubble(
            message: message,
            isMe: isMe,
            allImageMessages: message.messageType == MessageType.image ? imageMessages : null,
            messageIndexInImages: imgIdx,
          ),
          if (showDate) _DateSeparator(date: message.createdAt, colorScheme: cs),
        ]);
      },
    );
  }
}

// ── App bar ───────────────────────────────────────────────────────────────────

class _ChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _ChatAppBar({
    required this.otherUserName,
    required this.otherUserPhotoUrl,
    required this.colorScheme,
    required this.isDark,
    required this.onTap,
    required this.onInfo,
  });
  final String otherUserName;
  final String? otherUserPhotoUrl;
  final ColorScheme colorScheme;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback onInfo;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: isDark ? const Color(0xFF0E0E0F) : const Color(0xFFF5F5F7),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      leadingWidth: 44,
      leading: Padding(
        padding: const EdgeInsets.only(left: 8),
        child: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.arrow_back_rounded, size: 18, color: colorScheme.onSurface),
          ),
        ),
      ),
      title: GestureDetector(
        onTap: onTap,
        child: Row(
          children: [
            // Avatar with online indicator
            Stack(
              children: [
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: colorScheme.primaryContainer,
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.primary.withOpacity(0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: otherUserPhotoUrl != null
                        ? Image.network(otherUserPhotoUrl!, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Icon(Icons.person_rounded,
                                size: 22, color: colorScheme.onPrimaryContainer))
                        : Icon(Icons.person_rounded, size: 22,
                            color: colorScheme.onPrimaryContainer),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  otherUserName,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    color: colorScheme.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Tap to view profile',
                  style: TextStyle(
                    fontSize: 10,
                    color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        GestureDetector(
          onTap: onInfo,
          child: Container(
            margin: const EdgeInsets.only(right: 12),
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.info_outline_rounded, size: 18, color: colorScheme.onSurface),
          ),
        ),
      ],
    );
  }
}

// ── Input wrapper ──────────────────────────────────────────────────────────────

class _ChatInputWrapper extends StatelessWidget {
  const _ChatInputWrapper({
    required this.controller,
    required this.onSend,
    required this.onVoiceSend,
    required this.onFileSend,
    required this.onDocumentSend,
    required this.onImagePick,
    required this.isSending,
    required this.colorScheme,
    required this.isDark,
  });
  final TextEditingController controller;
  final VoidCallback onSend;
  final Function(String, int) onVoiceSend;
  final Function(List<File>) onFileSend;
  final Function(String) onDocumentSend;
  final VoidCallback onImagePick;
  final bool isSending;
  final ColorScheme colorScheme;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0E0E0F) : const Color(0xFFF5F5F7),
        border: Border(
          top: BorderSide(
            color: colorScheme.outlineVariant.withOpacity(0.25),
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: ChatInput(
            controller: controller,
            onSend: onSend,
            onVoiceSend: onVoiceSend,
            onFileSend: onFileSend,
            onDocumentSend: onDocumentSend,
            onImagePick: onImagePick,
            isSending: isSending,
          ),
        ),
      ),
    );
  }
}

// ── Date separator ─────────────────────────────────────────────────────────────

class _DateSeparator extends StatelessWidget {
  const _DateSeparator({required this.date, required this.colorScheme});
  final DateTime date;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final d = DateTime(date.year, date.month, date.day);

    final label = d == today
        ? 'Today'
        : d == yesterday
            ? 'Yesterday'
            : DateFormat('MMMM dd, yyyy').format(date);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(children: [
        Expanded(child: Container(height: 0.5, color: colorScheme.outlineVariant.withOpacity(0.4))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withOpacity(0.6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurfaceVariant,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ),
        Expanded(child: Container(height: 0.5, color: colorScheme.outlineVariant.withOpacity(0.4))),
      ]),
    );
  }
}

// ── States ─────────────────────────────────────────────────────────────────────

class _ChatLoadingState extends StatelessWidget {
  const _ChatLoadingState({required this.colorScheme});
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final shimmer = isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.04);
    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.all(16),
      itemCount: 6,
      itemBuilder: (_, i) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Align(
          alignment: i.isEven ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 180 + (i % 2) * 40.0,
            height: 44,
            decoration: BoxDecoration(
              color: shimmer,
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChatEmptyState extends StatelessWidget {
  const _ChatEmptyState({required this.otherUserName, required this.colorScheme});
  final String otherUserName;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: colorScheme.primary.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.chat_bubble_outline_rounded,
                size: 34, color: colorScheme.primary.withOpacity(0.5)),
          ),
          const SizedBox(height: 18),
          Text('Start the conversation',
              style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700, letterSpacing: -0.3)),
          const SizedBox(height: 6),
          Text('Send a message to $otherUserName',
              style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant, height: 1.5),
              textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}

class _ChatErrorState extends StatelessWidget {
  const _ChatErrorState({
    required this.error,
    required this.onRetry,
    required this.colorScheme,
  });
  final String error;
  final VoidCallback onRetry;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
                color: colorScheme.error.withOpacity(0.08), shape: BoxShape.circle),
            child: Icon(Icons.wifi_off_rounded, size: 34, color: colorScheme.error),
          ),
          const SizedBox(height: 18),
          Text('Error loading messages',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(error,
              style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Retry'),
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
            ),
          ),
        ]),
      ),
    );
  }
}

