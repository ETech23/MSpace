// lib/features/messaging/presentation/widgets/message_bubble.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/message_entity.dart';
import 'voice_message_bubble.dart';

class MessageBubble extends StatelessWidget {
  final MessageEntity message;
  final bool isMe;
  final List<MessageEntity>? allImageMessages;
  final int? messageIndexInImages;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.allImageMessages,
    this.messageIndexInImages,
  });

  @override
  Widget build(BuildContext context) {
    // Voice messages
    if (message.messageType == MessageType.voice) {
      return VoiceMessageBubble(message: message, isMe: isMe);
    }

    // Image messages (attachmentUrl can have multiple URLs separated by comma)
    if (message.messageType == MessageType.image && message.attachmentUrl != null) {
      final urls = message.attachmentUrl!.split(',').map((e) => e.trim()).toList();
      return _ImageMessageBubble(
        imageUrls: urls,
        createdAt: message.createdAt,
        isMe: isMe,
        isRead: message.isRead,
        allImageMessages: allImageMessages,
        messageIndexInImages: messageIndexInImages,
      );
    }

    // Text messages
    return _TextMessageBubble(message: message, isMe: isMe);
  }
}

/// ---------------- IMAGE MESSAGE BUBBLE WITH SWIPE ----------------
class _ImageMessageBubble extends StatefulWidget {
  final List<String> imageUrls;
  final DateTime createdAt;
  final bool isMe;
  final bool isRead;
  final List<MessageEntity>? allImageMessages;
  final int? messageIndexInImages;

  const _ImageMessageBubble({
    required this.imageUrls,
    required this.createdAt,
    required this.isMe,
    required this.isRead,
    this.allImageMessages,
    this.messageIndexInImages,
  });

  @override
  State<_ImageMessageBubble> createState() => _ImageMessageBubbleState();
}

class _ImageMessageBubbleState extends State<_ImageMessageBubble> {
  int currentIndex = 0;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _openFullScreen() {
    // Flatten all images from all messages
    final List<_ImageItem> allImages = [];
    int initialImageIndex = 0;

    if (widget.allImageMessages != null && widget.messageIndexInImages != null) {
      for (int msgIdx = 0; msgIdx < widget.allImageMessages!.length; msgIdx++) {
        final msg = widget.allImageMessages![msgIdx];
        if (msg.attachmentUrl != null) {
          final urls = msg.attachmentUrl!.split(',').map((e) => e.trim()).toList();
          for (int urlIdx = 0; urlIdx < urls.length; urlIdx++) {
            // Calculate initial index - if this is the current message and current image
            if (msgIdx == widget.messageIndexInImages && urlIdx == currentIndex) {
              initialImageIndex = allImages.length;
            }
            allImages.add(_ImageItem(
              url: urls[urlIdx],
              messageIndex: msgIdx,
              imageIndexInMessage: urlIdx,
              createdAt: msg.createdAt,
              isMe: msg.senderId == widget.allImageMessages![widget.messageIndexInImages!].senderId,
              isRead: msg.isRead,
            ));
          }
        }
      }
    } else {
      // Fallback: just current message images
      for (int i = 0; i < widget.imageUrls.length; i++) {
        allImages.add(_ImageItem(
          url: widget.imageUrls[i],
          messageIndex: 0,
          imageIndexInMessage: i,
          createdAt: widget.createdAt,
          isMe: widget.isMe,
          isRead: widget.isRead,
        ));
      }
      initialImageIndex = currentIndex;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _ImageGalleryScreen(
          images: allImages,
          initialIndex: initialImageIndex,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final maxWidth = MediaQuery.of(context).size.width * 0.65;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: widget.isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Container(
            width: maxWidth,
            height: 200,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: colorScheme.surfaceContainerHighest,
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                // Swipeable PageView with tap to open fullscreen
                PageView.builder(
                  controller: _pageController,
                  itemCount: widget.imageUrls.length,
                  onPageChanged: (index) {
                    setState(() {
                      currentIndex = index;
                    });
                  },
                  itemBuilder: (context, index) {
                    return GestureDetector(
                      onTap: _openFullScreen,
                      child: Image.network(
                        widget.imageUrls[index],
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              value: progress.expectedTotalBytes != null
                                  ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                                  : null,
                            ),
                          );
                        },
                        errorBuilder: (_, __, ___) => Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.broken_image,
                                size: 48,
                                color: colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Failed to load image',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),

                // Page indicators (dots) - only show if multiple images
                if (widget.imageUrls.length > 1)
                  Positioned(
                    top: 8,
                    left: 0,
                    right: 0,
                    child: IgnorePointer(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          widget.imageUrls.length,
                          (index) => Container(
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: currentIndex == index
                                  ? Colors.white
                                  : Colors.white.withOpacity(0.4),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                // Image counter badge - Top right
                if (widget.imageUrls.length > 1)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: IgnorePointer(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${currentIndex + 1}/${widget.imageUrls.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),

                // Left arrow (previous image)
                if (widget.imageUrls.length > 1 && currentIndex > 0)
                  Positioned(
                    left: 8,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.chevron_left, color: Colors.white),
                          onPressed: () {
                            _pageController.previousPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          },
                        ),
                      ),
                    ),
                  ),

                // Right arrow (next image)
                if (widget.imageUrls.length > 1 && currentIndex < widget.imageUrls.length - 1)
                  Positioned(
                    right: 8,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.chevron_right, color: Colors.white),
                          onPressed: () {
                            _pageController.nextPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          },
                        ),
                      ),
                    ),
                  ),

                // Time + read indicator overlay - Bottom right
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: IgnorePointer(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            DateFormat('HH:mm').format(widget.createdAt),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                          if (widget.isMe) ...[
                            const SizedBox(width: 4),
                            Icon(
                              widget.isRead ? Icons.done_all : Icons.done,
                              size: 14,
                              color: widget.isRead ? Colors.lightBlueAccent : Colors.white,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Helper class to represent an individual image
class _ImageItem {
  final String url;
  final int messageIndex;
  final int imageIndexInMessage;
  final DateTime createdAt;
  final bool isMe;
  final bool isRead;

  _ImageItem({
    required this.url,
    required this.messageIndex,
    required this.imageIndexInMessage,
    required this.createdAt,
    required this.isMe,
    required this.isRead,
  });
}

/// ---------------- IMAGE GALLERY SCREEN WITH SWIPE BETWEEN ALL IMAGES ----------------
class _ImageGalleryScreen extends StatefulWidget {
  final List<_ImageItem> images;
  final int initialIndex;

  const _ImageGalleryScreen({
    required this.images,
    this.initialIndex = 0,
  });

  @override
  State<_ImageGalleryScreen> createState() => _ImageGalleryScreenState();
}

class _ImageGalleryScreenState extends State<_ImageGalleryScreen> {
  late PageController _pageController;
  late int currentIndex;

  @override
  void initState() {
    super.initState();
    currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentImage = widget.images[currentIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          '${currentIndex + 1} / ${widget.images.length}',
          style: const TextStyle(color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // Swipeable full-screen images (across ALL messages)
          PageView.builder(
            controller: _pageController,
            itemCount: widget.images.length,
            onPageChanged: (index) {
              setState(() {
                currentIndex = index;
              });
            },
            itemBuilder: (context, index) {
              return Center(
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Image.network(
                    widget.images[index].url,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                              value: progress.expectedTotalBytes != null
                                  ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Loading image...',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      );
                    },
                    errorBuilder: (_, __, ___) => const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.broken_image,
                            size: 100,
                            color: Colors.white54,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Failed to load image',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

          // Page indicators at bottom
          if (widget.images.length > 1)
            Positioned(
              bottom: 80,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    widget.images.length > 10 ? 10 : widget.images.length,
                    (index) {
                      // For many images, show only a subset around current
                      int displayIndex = index;
                      if (widget.images.length > 10) {
                        displayIndex = (currentIndex - 5 + index).clamp(0, widget.images.length - 1);
                      }
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        width: currentIndex == displayIndex ? 20 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(3),
                          color: currentIndex == displayIndex
                              ? Colors.white
                              : Colors.white.withOpacity(0.4),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),

          // Timestamp and read indicator
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        DateFormat('MMM d, HH:mm').format(currentImage.createdAt),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                      if (currentImage.isMe) ...[
                        const SizedBox(width: 6),
                        Icon(
                          currentImage.isRead ? Icons.done_all : Icons.done,
                          size: 16,
                          color: currentImage.isRead ? Colors.lightBlueAccent : Colors.white,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ---------------- TEXT MESSAGE BUBBLE ----------------
class _TextMessageBubble extends StatelessWidget {
  final MessageEntity message;
  final bool isMe;

  const _TextMessageBubble({
    required this.message,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe && message.senderPhotoUrl != null) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: colorScheme.primaryContainer,
              backgroundImage: NetworkImage(message.senderPhotoUrl!),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? colorScheme.primaryContainer : colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(4),
                  bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.messageText,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isMe ? colorScheme.onPrimaryContainer : colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        DateFormat('HH:mm').format(message.createdAt),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: isMe
                              ? colorScheme.onPrimaryContainer.withOpacity(0.7)
                              : colorScheme.onSurfaceVariant.withOpacity(0.7),
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        Icon(
                          message.isRead ? Icons.done_all : Icons.done,
                          size: 14,
                          color: message.isRead
                              ? colorScheme.primary
                              : colorScheme.onPrimaryContainer.withOpacity(0.7),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}