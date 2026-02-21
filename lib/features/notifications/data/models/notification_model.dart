// lib/features/notifications/data/models/notification_model.dart
import '../../domain/entities/notification_entity.dart';

class NotificationModel extends NotificationEntity {
  NotificationModel({
    required super.id,
    required super.userId,
    required super.title,
    required super.body,
    required super.type,
    super.relatedId,
    super.data,
    required super.read,
    required super.createdAt,
    // ✅ REMOVED: readAt is not in the entity
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      type: _parseType(json['type'] as String),
      relatedId: json['related_id'] as String?,
      data: json['data'] as Map<String, dynamic>?,
      read: json['read'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      // ✅ REMOVED: readAt parsing since it's not in the entity
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'body': body,
      'type': _typeToString(type),
      'related_id': relatedId,
      'data': data,
      'read': read,
      'created_at': createdAt.toIso8601String(),
      // ✅ REMOVED: readAt since it doesn't exist
    };
  }

  static NotificationType _parseType(String type) {
    switch (type.toLowerCase()) {
      case 'booking':
        return NotificationType.booking;
      case 'message':
        return NotificationType.message;
      case 'payment':
        return NotificationType.payment;
      case 'job': // ✅ ADDED: job case
        return NotificationType.job;
      case 'system':
        return NotificationType.system;
      default:
        return NotificationType.system;
    }
  }

  static String _typeToString(NotificationType type) {
    switch (type) {
      case NotificationType.booking:
        return 'booking';
      case NotificationType.message:
        return 'message';
      case NotificationType.payment:
        return 'payment';
      case NotificationType.job: // ✅ ADDED: job case
        return 'job';
      case NotificationType.system:
        return 'system';
    }
  }

  NotificationEntity toEntity() => NotificationEntity(
        id: id,
        userId: userId,
        title: title,
        body: body,
        type: type,
        relatedId: relatedId,
        data: data,
        read: read,
        createdAt: createdAt,
        // ✅ REMOVED: readAt parameter
      );
}