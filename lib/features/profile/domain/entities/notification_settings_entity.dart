// lib/features/profile/domain/entities/notification_settings_entity.dart
import 'package:equatable/equatable.dart';

class NotificationSettingsEntity extends Equatable {
  final bool pushNotifications;
  final bool emailNotifications;
  final bool bookingUpdates;
  final bool promotions;
  final bool newMessages;

  const NotificationSettingsEntity({
    required this.pushNotifications,
    required this.emailNotifications,
    required this.bookingUpdates,
    required this.promotions,
    required this.newMessages,
  });

  @override
  List<Object?> get props => [
        pushNotifications,
        emailNotifications,
        bookingUpdates,
        promotions,
        newMessages,
      ];

  NotificationSettingsEntity copyWith({
    bool? pushNotifications,
    bool? emailNotifications,
    bool? bookingUpdates,
    bool? promotions,
    bool? newMessages,
  }) {
    return NotificationSettingsEntity(
      pushNotifications: pushNotifications ?? this.pushNotifications,
      emailNotifications: emailNotifications ?? this.emailNotifications,
      bookingUpdates: bookingUpdates ?? this.bookingUpdates,
      promotions: promotions ?? this.promotions,
      newMessages: newMessages ?? this.newMessages,
    );
  }
}
