// ============================================================================
// lib/features/messaging/presentation/widgets/voice_player_widget.dart
// ============================================================================

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

class VoicePlayerWidget extends StatefulWidget {
  final String audioUrl;
  final int durationSeconds;
  final bool isMe;

  const VoicePlayerWidget({
    super.key,
    required this.audioUrl,
    required this.durationSeconds,
    this.isMe = false,
  });

  @override
  State<VoicePlayerWidget> createState() => _VoicePlayerWidgetState();
}

class _VoicePlayerWidgetState extends State<VoicePlayerWidget> {
  late AudioPlayer _audioPlayer;
  bool _isPlaying = false;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _totalDuration = Duration(seconds: widget.durationSeconds);
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      await _audioPlayer.setUrl(widget.audioUrl);
      
      _audioPlayer.positionStream.listen((position) {
        if (mounted) {
          setState(() {
            _currentPosition = position;
          });
        }
      });

      _audioPlayer.playerStateStream.listen((state) {
        if (mounted) {
          setState(() {
            _isPlaying = state.playing;
            _isLoading = state.processingState == ProcessingState.loading;
          });
        }
        
        // Auto-reset when completed
        if (state.processingState == ProcessingState.completed) {
          _audioPlayer.seek(Duration.zero);
          _audioPlayer.pause();
        }
      });

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Error loading audio: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _togglePlayPause() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.play();
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final progress = _totalDuration.inSeconds > 0
        ? _currentPosition.inSeconds / _totalDuration.inSeconds
        : 0.0;

    return Container(
      constraints: const BoxConstraints(maxWidth: 280),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Play/Pause button
          Container(
            decoration: BoxDecoration(
              color: widget.isMe
                  ? colorScheme.onPrimaryContainer.withOpacity(0.2)
                  : colorScheme.primary.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: _isLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: widget.isMe
                            ? colorScheme.onPrimaryContainer
                            : colorScheme.primary,
                      ),
                    )
                  : Icon(
                      _isPlaying ? Icons.pause : Icons.play_arrow,
                      color: widget.isMe
                          ? colorScheme.onPrimaryContainer
                          : colorScheme.primary,
                    ),
              onPressed: _isLoading ? null : _togglePlayPause,
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(),
            ),
          ),
          
          const SizedBox(width: 8),
          
          // Progress bar
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 2,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                    activeTrackColor: widget.isMe
                        ? colorScheme.onPrimaryContainer
                        : colorScheme.primary,
                    inactiveTrackColor: widget.isMe
                        ? colorScheme.onPrimaryContainer.withOpacity(0.3)
                        : colorScheme.primary.withOpacity(0.3),
                    thumbColor: widget.isMe
                        ? colorScheme.onPrimaryContainer
                        : colorScheme.primary,
                  ),
                  child: Slider(
                    value: progress.clamp(0.0, 1.0),
                    onChanged: (value) async {
                      final position = Duration(
                        seconds: (value * _totalDuration.inSeconds).round(),
                      );
                      await _audioPlayer.seek(position);
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDuration(_currentPosition),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: widget.isMe
                              ? colorScheme.onPrimaryContainer.withOpacity(0.7)
                              : colorScheme.onSurfaceVariant.withOpacity(0.7),
                        ),
                      ),
                      Text(
                        _formatDuration(_totalDuration),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: widget.isMe
                              ? colorScheme.onPrimaryContainer.withOpacity(0.7)
                              : colorScheme.onSurfaceVariant.withOpacity(0.7),
                        ),
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