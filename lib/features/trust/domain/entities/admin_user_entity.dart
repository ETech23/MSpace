class AdminUserEntity {
  final String id;
  final String name;
  final String email;
  final String userType;
  final bool verified;
  final String moderationStatus;
  final DateTime createdAt;

  const AdminUserEntity({
    required this.id,
    required this.name,
    required this.email,
    required this.userType,
    required this.verified,
    required this.moderationStatus,
    required this.createdAt,
  });
}
