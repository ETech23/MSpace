// lib/features/messaging/presentation/widgets/voice_message_bubble.dart
// ✅ FIXED: Proper cleanup to prevent memory leaks

import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';
import '../../domain/entities/message_entity.dart';

class VoiceMessageBubble extends StatefulWidget {
  final MessageEntity message;
  final bool isMe;

  const VoiceMessageBubble({
    super.key,
    required this.message,
    required this.isMe,
  });

  @override
  State<VoiceMessageBubble> createState() => _VoiceMessageBubbleState();
}

class _VoiceMessageBubbleState extends State<VoiceMessageBubble> {
  late final AudioPlayer _audioPlayer;
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  // ✅ CRITICAL: Store subscriptions so we can cancel them
  StreamSubscription<Duration>? _durationSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<PlayerState>? _stateSubscription;
  StreamSubscription<void>? _completeSubscription;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _setupAudioPlayer();
  }

  void _setupAudioPlayer() {
    // ✅ FIX: Store subscriptions and check mounted before setState
    _durationSubscription = _audioPlayer.onDurationChanged.listen((duration) {
      if (mounted) {
        setState(() => _duration = duration);
      }
    });

    _positionSubscription = _audioPlayer.onPositionChanged.listen((position) {
      if (mounted) {
        setState(() => _position = position);
      }
    });

    _stateSubscription = _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
      }
    });

    _completeSubscription = _audioPlayer.onPlayerComplete.listen((event) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
        });
      }
    });
  }

  @override
  void dispose() {
    // ✅ CRITICAL: Cancel all subscriptions BEFORE disposing player
    _durationSubscription?.cancel();
    _positionSubscription?.cancel();
    _stateSubscription?.cancel();
    _completeSubscription?.cancel();
    
    // Stop and dispose the audio player
    _audioPlayer.stop();
    _audioPlayer.dispose();
    
    super.dispose();
  }

  Future<void> _togglePlayPause() async {
    try {
      if (_isPlaying) {
        await _audioPlayer.pause();
      } else {
        if (_position >= _duration) {
          await _audioPlayer.seek(Duration.zero);
        }
        await _audioPlayer.play(UrlSource(widget.message.attachmentUrl!));
      }
    } catch (e) {
      debugPrint('❌ Error playing audio: $e');
      if (mounted) {
        setState(() => _isPlaying = false);
      }
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    final displayDuration = widget.message.voiceDurationSeconds != null
        ? Duration(seconds: widget.message.voiceDurationSeconds!)
        : _duration;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: widget.isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Sender's avatar (for other user's messages)
          if (!widget.isMe && widget.message.senderPhotoUrl != null) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: colorScheme.primaryContainer,
              backgroundImage: NetworkImage(widget.message.senderPhotoUrl!),
            ),
            const SizedBox(width: 8),
          ],
          
          // Voice bubble
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.7,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: widget.isMe
                  ? colorScheme.primaryContainer
                  : colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: widget.isMe ? const Radius.circular(16) : const Radius.circular(4),
                bottomRight: widget.isMe ? const Radius.circular(4) : const Radius.circular(16),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Play/Pause button
                IconButton(
                  icon: Icon(
                    _isPlaying ? Icons.pause : Icons.play_arrow,
                    color: widget.isMe
                        ? colorScheme.onPrimaryContainer
                        : colorScheme.onSurfaceVariant,
                  ),
                  onPressed: _togglePlayPause,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                
                const SizedBox(width: 8),
                
                // Waveform and progress
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Simplified waveform
                      SizedBox(
                        height: 30,
                        child: Row(
                          children: List.generate(30, (index) {
                            final isActive = _duration > Duration.zero &&
                                (index / 30) <= (_position.inMilliseconds / _duration.inMilliseconds);
                            final height = 10.0 + (index % 4) * 5;
                            
                            return Expanded(
                              child: Container(
                                height: height,
                                margin: const EdgeInsets.symmetric(horizontal: 1),
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? (widget.isMe
                                          ? colorScheme.primary
                                          : colorScheme.secondary)
                                      : (widget.isMe
                                          ? colorScheme.onPrimaryContainer.withOpacity(0.3)
                                          : colorScheme.onSurfaceVariant.withOpacity(0.3)),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                      
                      const SizedBox(height: 4),
                      
                      // Duration
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatDuration(_isPlaying ? _position : displayDuration),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: widget.isMe
                                  ? colorScheme.onPrimaryContainer.withOpacity(0.7)
                                  : colorScheme.onSurfaceVariant.withOpacity(0.7),
                            ),
                          ),
                          if (widget.isMe)
                            Icon(
                              widget.message.isRead ? Icons.done_all : Icons.done,
                              size: 14,
                              color: widget.message.isRead
                                  ? colorScheme.primary
                                  : colorScheme.onPrimaryContainer.withOpacity(0.7),
                            ),
                        ],
                      ),
                    ],
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