class DisputeEventEntity {
  final String id;
  final String disputeId;
  final String actorId;
  final String eventType;
  final String? note;
  final DateTime createdAt;

  const DisputeEventEntity({
    required this.id,
    required this.disputeId,
    required this.actorId,
    required this.eventType,
    required this.createdAt,
    this.note,
  });
}
