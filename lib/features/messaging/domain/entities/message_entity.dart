
// lib/features/messaging/domain/entities/message_entity.dart
import 'package:equatable/equatable.dart';

enum MessageType {
  text,
  image,
  voice,  // ← NEW
  system,
}

class MessageEntity extends Equatable {
  final String id;
  final String conversationId;
  final String senderId;
  
  final String? senderName;
  final String? senderPhotoUrl;
  
  final String messageText;
  final MessageType messageType;
  
  // Attachments
  final String? attachmentUrl;
  final String? attachmentType;
  
  // Voice note specific
  final int? voiceDurationSeconds;  // ← NEW
  
  // Read status
  final bool isRead;
  final DateTime? readAt;
  
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  const MessageEntity({
    required this.id,
    required this.conversationId,
    required this.senderId,
    this.senderName,
    this.senderPhotoUrl,
    required this.messageText,
    this.messageType = MessageType.text,
    this.attachmentUrl,
    this.attachmentType,
    this.voiceDurationSeconds,  // ← NEW
    this.isRead = false,
    this.readAt,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  bool isFromMe(String currentUserId) {
    return senderId == currentUserId;
  }

  bool get isDeleted => deletedAt != null;
  
  // ← NEW: Check if message is a voice note
  bool get isVoiceNote => messageType == MessageType.voice;
  
  // ← NEW: Format voice duration as MM:SS
  String get formattedDuration {
    if (voiceDurationSeconds == null) return '0:00';
    final minutes = voiceDurationSeconds! ~/ 60;
    final seconds = voiceDurationSeconds! % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  MessageEntity copyWith({
    bool? isRead,
    DateTime? readAt,
  }) {
    return MessageEntity(
      id: id,
      conversationId: conversationId,
      senderId: senderId,
      senderName: senderName,
      senderPhotoUrl: senderPhotoUrl,
      messageText: messageText,
      messageType: messageType,
      attachmentUrl: attachmentUrl,
      attachmentType: attachmentType,
      voiceDurationSeconds: voiceDurationSeconds,
      isRead: isRead ?? this.isRead,
      readAt: readAt ?? this.readAt,
      createdAt: createdAt,
      updatedAt: updatedAt,
      deletedAt: deletedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        conversationId,
        senderId,
        senderName,
        senderPhotoUrl,
        messageText,
        messageType,
        attachmentUrl,
        attachmentType,
        voiceDurationSeconds,
        isRead,
        readAt,
        createdAt,
        updatedAt,
        deletedAt,
      ];
}

MessageType messageTypeFromString(String type) {
  switch (type.toLowerCase()) {
    case 'image':
      return MessageType.image;
    case 'voice':  // ← NEW
      return MessageType.voice;
    case 'system':
      return MessageType.system;
    default:
      return MessageType.text;
  }
}

String messageTypeToString(MessageType type) {
  switch (type) {
    case MessageType.image:
      return 'image';
    case MessageType.voice:  // ← NEW
      return 'voice';
    case MessageType.system:
      return 'system';
    case MessageType.text:
      return 'text';
  }
}

