// lib/features/messaging/domain/entities/notification_settings_entity.dart
// CREATE NEW FILE:

import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

class NotificationSettingsEntity extends Equatable {
  final String userId;
  final bool messagesEnabled;
  final bool bookingsEnabled;
  final bool reviewsEnabled;
  final bool promotionsEnabled;
  final bool soundEnabled;
  final bool vibrationEnabled;
  final bool quietHoursEnabled;
  final TimeOfDay? quietHoursStart;
  final TimeOfDay? quietHoursEnd;

  const NotificationSettingsEntity({
    required this.userId,
    this.messagesEnabled = true,
    this.bookingsEnabled = true,
    this.reviewsEnabled = true,
    this.promotionsEnabled = true,
    this.soundEnabled = true,
    this.vibrationEnabled = true,
    this.quietHoursEnabled = false,
    this.quietHoursStart,
    this.quietHoursEnd,
  });

  @override
  List<Object?> get props => [
        userId,
        messagesEnabled,
        bookingsEnabled,
        reviewsEnabled,
        promotionsEnabled,
        soundEnabled,
        vibrationEnabled,
        quietHoursEnabled,
        quietHoursStart,
        quietHoursEnd,
      ];
}