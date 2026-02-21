// lib/features/messaging/domain/entities/conversation_entity.dart
import 'package:equatable/equatable.dart';

class ConversationEntity extends Equatable {
  final String id;
  final String participant1Id;
  final String participant2Id;
  final String? participant1Name;
  final String? participant1PhotoUrl;
  final String? participant2Name;
  final String? participant2PhotoUrl;
  final String? lastMessageText;
  final DateTime? lastMessageTime;
  final String? lastMessageSenderId;  // ADD THIS
  final int unreadCount;
  final String? bookingId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ConversationEntity({
    required this.id,
    required this.participant1Id,
    required this.participant2Id,
    this.participant1Name,
    this.participant1PhotoUrl,
    this.participant2Name,
    this.participant2PhotoUrl,
    this.lastMessageText,
    this.lastMessageTime,
    this.lastMessageSenderId,  // ADD THIS
    this.unreadCount = 0,
    this.bookingId,
    required this.createdAt,
    required this.updatedAt,
  });

  // Get the other user's info based on current user ID
  String getOtherUserId(String currentUserId) {
    return currentUserId == participant1Id ? participant2Id : participant1Id;
  }

  String? getOtherUserName(String currentUserId) {
    return currentUserId == participant1Id ? participant2Name : participant1Name;
  }

  String? getOtherUserPhotoUrl(String currentUserId) {
    return currentUserId == participant1Id
        ? participant2PhotoUrl
        : participant1PhotoUrl;
  }

  // ADD THIS METHOD - Check if last message is from current user
  bool isLastMessageFromMe(String currentUserId) {
    if (lastMessageSenderId == null) return false;
    return lastMessageSenderId == currentUserId;
  }

  @override
  List<Object?> get props => [
        id,
        participant1Id,
        participant2Id,
        participant1Name,
        participant1PhotoUrl,
        participant2Name,
        participant2PhotoUrl,
        lastMessageText,
        lastMessageTime,
        lastMessageSenderId,  // ADD THIS
        unreadCount,
        bookingId,
        createdAt,
        updatedAt,
      ];
}