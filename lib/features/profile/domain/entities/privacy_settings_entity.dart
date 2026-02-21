// lib/features/profile/domain/entities/privacy_settings_entity.dart
import 'package:equatable/equatable.dart';

class PrivacySettingsEntity extends Equatable {
  final bool profileVisible;
  final bool showEmail;
  final bool showPhone;
  final bool showAddress;

  const PrivacySettingsEntity({
    required this.profileVisible,
    required this.showEmail,
    required this.showPhone,
    required this.showAddress,
  });

  @override
  List<Object?> get props => [profileVisible, showEmail, showPhone, showAddress];

  PrivacySettingsEntity copyWith({
    bool? profileVisible,
    bool? showEmail,
    bool? showPhone,
    bool? showAddress,
  }) {
    return PrivacySettingsEntity(
      profileVisible: profileVisible ?? this.profileVisible,
      showEmail: showEmail ?? this.showEmail,
      showPhone: showPhone ?? this.showPhone,
      showAddress: showAddress ?? this.showAddress,
    );
  }
}