class BlockedUserEntity {
  final String blockedUserId;
  final String? name;
  final String? photoUrl;
  final String? reason;
  final DateTime blockedAt;

  const BlockedUserEntity({
    required this.blockedUserId,
    required this.blockedAt,
    this.name,
    this.photoUrl,
    this.reason,
  });
}
