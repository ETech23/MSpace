// lib/features/messaging/data/models/message_model.dart

import '../../domain/entities/message_entity.dart';

class MessageModel extends MessageEntity {
  const MessageModel({
    required super.id,
    required super.conversationId,
    required super.senderId,
    super.senderName,
    super.senderPhotoUrl,
    required super.messageText,
    super.messageType,
    super.attachmentUrl,
    super.attachmentType,
    super.voiceDurationSeconds,  // ← NEW
    super.isRead,
    super.readAt,
    required super.createdAt,
    required super.updatedAt,
    super.deletedAt,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    String? senderName;
    String? senderPhoto;
    
    if (json['sender'] != null && json['sender'] is Map) {
      final senderData = json['sender'] as Map<String, dynamic>;
      senderName = senderData['name'] as String?;
      senderPhoto = senderData['photo_url'] as String?;
    }
    
    return MessageModel(
      id: json['id'] as String,
      conversationId: json['conversation_id'] as String,
      senderId: json['sender_id'] as String,
      senderName: senderName,
      senderPhotoUrl: senderPhoto,
      messageText: json['message_text'] as String,
      messageType: messageTypeFromString(json['message_type'] as String? ?? 'text'),
      attachmentUrl: json['attachment_url'] as String?,
      attachmentType: json['attachment_type'] as String?,
      voiceDurationSeconds: json['voice_duration_seconds'] as int?,  // ← NEW
      isRead: json['is_read'] as bool? ?? false,
      readAt: json['read_at'] != null
          ? DateTime.parse(json['read_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      deletedAt: json['deleted_at'] != null
          ? DateTime.parse(json['deleted_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversation_id': conversationId,
      'sender_id': senderId,
      'message_text': messageText,
      'message_type': messageTypeToString(messageType),
      'attachment_url': attachmentUrl,
      'attachment_type': attachmentType,
      'voice_duration_seconds': voiceDurationSeconds,  // ← NEW
      'is_read': isRead,
      'read_at': readAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
    };
  }
}
