// lib/features/trust/domain/entities/dispute_entity.dart

class DisputeEntity {
  final String id;
  final String bookingId;
  final String openedBy;
  final String reason;
  final List<String> evidenceUrls;
  final String status; // open, investigating, resolved, closed
  final DateTime openedAt;
  final DateTime? resolvedAt;
  final String? resolvedBy;
  final String? resolutionNotes;

  DisputeEntity({
    required this.id,
    required this.bookingId,
    required this.openedBy,
    required this.reason,
    required this.evidenceUrls,
    required this.status,
    required this.openedAt,
    this.resolvedAt,
    this.resolvedBy,
    this.resolutionNotes,
  });
}
