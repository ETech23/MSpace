// lib/features/profile/data/models/notification_settings_model.dart
import '../../domain/entities/notification_settings_entity.dart';

class NotificationSettingsModel extends NotificationSettingsEntity {
  const NotificationSettingsModel({
    required super.pushNotifications,
    required super.emailNotifications,
    required super.bookingUpdates,
    required super.promotions,
    required super.newMessages,
  });

  factory NotificationSettingsModel.fromJson(Map<String, dynamic> json) {
    return NotificationSettingsModel(
      pushNotifications: json['push_notifications'] ?? true,
      emailNotifications: json['email_notifications'] ?? true,
      bookingUpdates: json['booking_updates'] ?? true,
      promotions: json['promotions'] ?? false,
      newMessages: json['new_messages'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'push_notifications': pushNotifications,
      'email_notifications': emailNotifications,
      'booking_updates': bookingUpdates,
      'promotions': promotions,
      'new_messages': newMessages,
    };
  }
}