class DisputeMessageEntity {
  final String id;
  final String disputeId;
  final String senderId;
  final String message;
  final List<String> evidenceUrls;
  final DateTime createdAt;

  const DisputeMessageEntity({
    required this.id,
    required this.disputeId,
    required this.senderId,
    required this.message,
    required this.evidenceUrls,
    required this.createdAt,
  });
}
