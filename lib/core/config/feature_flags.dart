class FeatureFlags {
  final bool maintenanceMode;
  final bool disablePostJob;
  final bool disableBookings;
  final bool disableChat;
  final String? maintenanceMessage;
  final DateTime fetchedAt;

  const FeatureFlags({
    required this.maintenanceMode,
    required this.disablePostJob,
    required this.disableBookings,
    required this.disableChat,
    required this.fetchedAt,
    this.maintenanceMessage,
  });

  factory FeatureFlags.defaults() {
    return FeatureFlags(
      maintenanceMode: false,
      disablePostJob: false,
      disableBookings: false,
      disableChat: false,
      maintenanceMessage: null,
      fetchedAt: DateTime.now(),
    );
  }

  factory FeatureFlags.fromJson(Map<String, dynamic> json) {
    return FeatureFlags(
      maintenanceMode: json['maintenance_mode'] as bool? ?? false,
      disablePostJob: json['disable_post_job'] as bool? ?? false,
      disableBookings: json['disable_bookings'] as bool? ?? false,
      disableChat: json['disable_chat'] as bool? ?? false,
      maintenanceMessage: json['maintenance_message'] as String?,
      fetchedAt: DateTime.now(),
    );
  }
}
