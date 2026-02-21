// lib/features/profile/data/models/privacy_settings_model.dart
import '../../domain/entities/privacy_settings_entity.dart';

class PrivacySettingsModel extends PrivacySettingsEntity {
  const PrivacySettingsModel({
    required super.profileVisible,
    required super.showEmail,
    required super.showPhone,
    required super.showAddress,
  });

  factory PrivacySettingsModel.fromJson(Map<String, dynamic> json) {
    return PrivacySettingsModel(
      profileVisible: json['profile_visible'] ?? true,
      showEmail: json['show_email'] ?? false,
      showPhone: json['show_phone'] ?? true,
      showAddress: json['show_address'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'profile_visible': profileVisible,
      'show_email': showEmail,
      'show_phone': showPhone,
      'show_address': showAddress,
    };
  }
}