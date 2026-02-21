// lib/features/notifications/domain/entities/notification_entity.dart

enum NotificationType {
  system,
  booking,
  message,
  job,      // ✅ ADD THIS
  payment,
}

class NotificationEntity {
  final String id;
  final String userId;
  final NotificationType type;
  final String title;
  final String body;
  final bool read;
  final String? relatedId;
  final Map<String, dynamic>? data;
  final DateTime createdAt;

  NotificationEntity({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.body,
    required this.read,
    this.relatedId,
    this.data,
    required this.createdAt,
  });

  factory NotificationEntity.fromJson(Map<String, dynamic> json) {
    return NotificationEntity(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      type: _parseType(json['type'] as String),
      title: json['title'] as String,
      body: json['body'] as String,
      read: json['read'] as bool? ?? false,
      relatedId: json['related_id'] as String?,
      data: json['data'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  static NotificationType _parseType(String type) {
    switch (type) {
      case 'system':
        return NotificationType.system;
      case 'booking':
        return NotificationType.booking;
      case 'message':
        return NotificationType.message;
      case 'job':
        return NotificationType.job;
      case 'payment':
        return NotificationType.payment;
      default:
        return NotificationType.system;
    }
  }

  NotificationEntity copyWith({
    String? id,
    String? userId,
    NotificationType? type,
    String? title,
    String? body,
    bool? read,
    String? relatedId,
    Map<String, dynamic>? data,
    DateTime? createdAt,
  }) {
    return NotificationEntity(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      title: title ?? this.title,
      body: body ?? this.body,
      read: read ?? this.read,
      relatedId: relatedId ?? this.relatedId,
      data: data ?? this.data,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}