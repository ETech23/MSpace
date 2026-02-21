// lib/features/messaging/data/models/conversation_model.dart
// Update the fromJson method to match YOUR schema

import '../../domain/entities/conversation_entity.dart';

class ConversationModel extends ConversationEntity {
  const ConversationModel({
    required super.id,
    required super.participant1Id,
    required super.participant2Id,
    super.participant1Name,
    super.participant1PhotoUrl,
    super.participant2Name,
    super.participant2PhotoUrl,
    super.lastMessageText,
    super.lastMessageTime,
    super.unreadCount,
    super.bookingId,
    super.lastMessageSenderId,
    required super.createdAt,
    required super.updatedAt,
  });

  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    // YOUR SCHEMA uses participant1 and participant2
    final participant1 = json['participant1'] as Map<String, dynamic>?;
    final participant2 = json['participant2'] as Map<String, dynamic>?;
    final lastMessage = json['last_message'] as Map<String, dynamic>?;

    return ConversationModel(
      id: json['id'] as String,
      participant1Id: json['participant1_id'] as String,
      participant2Id: json['participant2_id'] as String,
      participant1Name: participant1?['name'] as String?,
      participant1PhotoUrl: participant1?['photo_url'] as String?,
      participant2Name: participant2?['name'] as String?,
      participant2PhotoUrl: participant2?['photo_url'] as String?,
      lastMessageText: lastMessage?['message_text'] as String?,
      lastMessageSenderId: lastMessage?['sender_id'] as String?,
      lastMessageTime: lastMessage != null
          ? DateTime.parse(lastMessage['created_at'] as String)
          : null,
      unreadCount: json['unread_count'] as int? ?? 0,
      bookingId: json['booking_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'participant1_id': participant1Id,
      'participant2_id': participant2Id,
      'booking_id': bookingId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}