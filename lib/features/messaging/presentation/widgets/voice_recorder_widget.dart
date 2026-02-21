// lib/features/messaging/presentation/widgets/voice_recorder_widget.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class VoiceRecorderWidget extends StatefulWidget {
  final Function(String filePath, int durationSeconds) onRecordingComplete;
  final VoidCallback onCancel;

  const VoiceRecorderWidget({
    super.key,
    required this.onRecordingComplete,
    required this.onCancel,
  });

  @override
  State<VoiceRecorderWidget> createState() => _VoiceRecorderWidgetState();
}

class _VoiceRecorderWidgetState extends State<VoiceRecorderWidget> {
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  int _recordDuration = 0;
  Timer? _timer;
  String? _recordingPath;

  @override
  void initState() {
    super.initState();
    _startRecording();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _audioRecorder.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    try {
      // Request microphone permission
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Microphone permission denied')),
          );
          widget.onCancel();
        }
        return;
      }

      // Check if recorder has permission
      if (!await _audioRecorder.hasPermission()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Microphone permission required')),
          );
          widget.onCancel();
        }
        return;
      }

      // Get temporary directory for recording
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _recordingPath = '${tempDir.path}/voice_message_$timestamp.m4a';

      // Start recording
      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: _recordingPath!,
      );

      setState(() => _isRecording = true);

      // Start timer
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() => _recordDuration++);
        }
        
        // Auto-stop after 2 minutes
        if (_recordDuration >= 120) {
          _stopRecording();
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start recording: $e')),
        );
        widget.onCancel();
      }
    }
  }

  Future<void> _stopRecording() async {
    try {
      _timer?.cancel();
      
      final path = await _audioRecorder.stop();
      
      if (path != null && _recordDuration > 0) {
        widget.onRecordingComplete(path, _recordDuration);
      } else {
        widget.onCancel();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save recording: $e')),
        );
        widget.onCancel();
      }
    }
  }

  Future<void> _cancelRecording() async {
    try {
      _timer?.cancel();
      await _audioRecorder.stop();
      
      // Delete the recording file
      if (_recordingPath != null) {
        final file = File(_recordingPath!);
        if (await file.exists()) {
          await file.delete();
        }
      }
      
      widget.onCancel();
    } catch (e) {
      widget.onCancel();
    }
  }

  String _formatDuration(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$secs';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Cancel button
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: _cancelRecording,
                color: colorScheme.error,
                tooltip: 'Cancel',
              ),

              const SizedBox(width: 16),

              // Recording indicator
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: colorScheme.error,
                  shape: BoxShape.circle,
                ),
              ),

              const SizedBox(width: 12),

              // Timer
              Text(
                _formatDuration(_recordDuration),
                style: theme.textTheme.titleMedium?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const Spacer(),

              // Waveform animation
              Row(
                children: List.generate(5, (index) {
                  return AnimatedContainer(
                    duration: Duration(milliseconds: 300 + (index * 100)),
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    width: 3,
                    height: _isRecording ? (10 + (index % 3) * 8).toDouble() : 4,
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  );
                }),
              ),

              const Spacer(),

              // Send button
              Container(
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: Icon(
                    Icons.send_rounded,
                    color: colorScheme.onPrimary,
                  ),
                  onPressed: _stopRecording,
                  tooltip: 'Send',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}