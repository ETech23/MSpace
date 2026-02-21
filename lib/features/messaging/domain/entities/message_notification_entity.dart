// lib/features/messaging/domain/entities/message_notification_entity.dart
import 'package:equatable/equatable.dart';

class MessageNotificationEntity extends Equatable {
  final String id;
  final String messageId;
  final String userId;
  final String notificationTitle;
  final String notificationBody;
  final bool isSent;
  final DateTime? sentAt;
  final bool isDelivered;
  final DateTime? deliveredAt;
  final bool isRead;
  final DateTime? readAt;
  final DateTime createdAt;

  const MessageNotificationEntity({
    required this.id,
    required this.messageId,
    required this.userId,
    required this.notificationTitle,
    required this.notificationBody,
    this.isSent = false,
    this.sentAt,
    this.isDelivered = false,
    this.deliveredAt,
    this.isRead = false,
    this.readAt,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [
        id,
        messageId,
        userId,
        notificationTitle,
        notificationBody,
        isSent,
        sentAt,
        isDelivered,
        deliveredAt,
        isRead,
        readAt,
        createdAt,
      ];
}