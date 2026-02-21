// lib/features/messaging/presentation/widgets/chat_input.dart
import 'package:flutter/material.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'voice_recorder_widget.dart';
import 'package:flutter/foundation.dart' hide Category;
import 'dart:io';

class ChatInput extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final Function(String filePath, int durationSeconds)? onVoiceSend;
  final Function(List<File> imageFiles)? onFileSend;
  final VoidCallback? onImagePick;
  final bool isSending;

  const ChatInput({
    super.key,
    required this.controller,
    required this.onSend,
    this.onVoiceSend,
    this.onFileSend,
    this.onImagePick,
    this.isSending = false,
  });

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  bool _isRecording = false;
  bool _hasText = false;
  bool _showEmojiPicker = false;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final hasText = widget.controller.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
    }
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus && _showEmojiPicker) {
      setState(() => _showEmojiPicker = false);
    }
  }

  void _toggleEmojiPicker() {
    setState(() {
      _showEmojiPicker = !_showEmojiPicker;
      if (_showEmojiPicker) {
        _focusNode.unfocus();
      } else {
        _focusNode.requestFocus();
      }
    });
  }

  void _onEmojiSelected(Category? category, Emoji emoji) {
    final controller = widget.controller;
    final text = controller.text;
    final selection = controller.selection;

    final int cursorPosition =
        selection.isValid ? selection.baseOffset : text.length;

    final newText = text.replaceRange(
      cursorPosition,
      cursorPosition,
      emoji.emoji,
    );

    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: cursorPosition + emoji.emoji.length,
      ),
    );
  }

  void _onBackspacePressed() {
    final controller = widget.controller;
    final text = controller.text;
    final selection = controller.selection;

    if (text.isEmpty) return;

    final int cursorPosition =
        selection.isValid ? selection.baseOffset : text.length;

    if (cursorPosition <= 0) return;

    final newText = text.replaceRange(
      cursorPosition - 1,
      cursorPosition,
      '',
    );

    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: cursorPosition - 1,
      ),
    );
  }

  Future<void> _pickFile() async {
    try {
      final result = await showModalBottomSheet<String>(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_library, color: Colors.blue),
                  title: const Text('Photos from Gallery'),
                  subtitle: const Text('Select multiple images'),
                  onTap: () => Navigator.pop(context, 'gallery'),
                ),
                ListTile(
                  leading: const Icon(Icons.camera_alt, color: Colors.green),
                  title: const Text('Take Photo'),
                  onTap: () => Navigator.pop(context, 'camera'),
                ),
                ListTile(
                  leading: const Icon(Icons.insert_drive_file, color: Colors.orange),
                  title: const Text('Document'),
                  onTap: () => Navigator.pop(context, 'document'),
                ),
              ],
            ),
          ),
        ),
      );

      if (result == null || !mounted) return;

      if (result == 'gallery') {
        // Use the multiple image picker
        widget.onImagePick?.call();
      } else if (result == 'camera') {
        await _pickSingleImage(true);
      } else if (result == 'document') {
        await _pickDocument();
      }
    } catch (e) {
      if (mounted) {
        _showError('Failed to pick file');
      }
    }
  }

  Future<void> _pickSingleImage(bool fromCamera) async {
    if (kIsWeb) {
      _showError('Camera is not supported on Web');
      return;
    }
    
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: fromCamera ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image != null && widget.onFileSend != null) {
        // Send single image as a list
        widget.onFileSend!([File(image.path)]);
      }
    } catch (e) {
      if (mounted) {
        _showError('Failed to pick image');
      }
    }
  }

  Future<void> _pickDocument() async {
    if (kIsWeb) {
      _showError('Document picking is not supported on Web');
      return;
    }
    
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'txt', 'xlsx', 'xls'],
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.path != null) {
          // For documents, you might want to handle them differently
          // For now, we'll show an error as the current implementation expects images
          _showError('Document upload coming soon');
          // TODO: Implement document upload separately
          // widget.onDocumentSend?.call(file.path!);
        }
      }
    } catch (e) {
      if (mounted) {
        _showError('Failed to pick document');
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _startRecording() {
    setState(() => _isRecording = true);
  }

  void _cancelRecording() {
    setState(() => _isRecording = false);
  }

  void _onRecordingComplete(String filePath, int durationSeconds) {
    setState(() => _isRecording = false);
    if (widget.onVoiceSend != null) {
      widget.onVoiceSend!(filePath, durationSeconds);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isRecording) {
      return VoiceRecorderWidget(
        onRecordingComplete: _onRecordingComplete,
        onCancel: _cancelRecording,
      );
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
            border: Border(
              top: BorderSide(
                color: colorScheme.outlineVariant,
                width: 1,
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: colorScheme.outlineVariant,
                        ),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              _showEmojiPicker
                                  ? Icons.keyboard
                                  : Icons.emoji_emotions_outlined,
                              size: 24,
                              color: colorScheme.primary,
                            ),
                            onPressed: _toggleEmojiPicker,
                            tooltip: _showEmojiPicker ? 'Keyboard' : 'Emojis',
                          ),
                          Expanded(
                            child: TextField(
                              controller: widget.controller,
                              focusNode: _focusNode,
                              decoration: InputDecoration(
                                hintText: 'Type a message...',
                                hintStyle: theme.textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 12,
                                ),
                              ),
                              maxLines: null,
                              textCapitalization: TextCapitalization.sentences,
                              enabled: !widget.isSending,
                              onSubmitted: (_) {
                                if (_hasText) widget.onSend();
                              },
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.attach_file, size: 24),
                            onPressed: widget.isSending ? null : _pickFile,
                            tooltip: 'Attach',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: widget.isSending
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: colorScheme.onPrimary,
                              ),
                            )
                          : Icon(
                              _hasText ? Icons.send_rounded : Icons.mic,
                              color: colorScheme.onPrimary,
                            ),
                      onPressed: widget.isSending
                          ? null
                          : (_hasText ? widget.onSend : _startRecording),
                      tooltip: _hasText ? 'Send' : 'Record',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_showEmojiPicker)
          SizedBox(
            height: 300,
            child: EmojiPicker(
              onEmojiSelected: _onEmojiSelected,
              onBackspacePressed: _onBackspacePressed,
              config: const Config(
                height: 300,
                emojiViewConfig: EmojiViewConfig(
                  emojiSizeMax: 28,
                ),
                categoryViewConfig: CategoryViewConfig(),
                bottomActionBarConfig: BottomActionBarConfig(),
                searchViewConfig: SearchViewConfig(),
              ),
            ),
          ),
      ],
    );
  }
}