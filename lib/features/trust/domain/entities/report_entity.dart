// lib/features/trust/domain/entities/report_entity.dart

class ReportEntity {
  final String id;
  final String reporterId;
  final String targetType; // user, job, message
  final String targetId;
  final String reason;
  final String status; // reported, under_review, actioned, dismissed
  final String? actionTaken;
  final DateTime createdAt;
  final DateTime? reviewedAt;
  final String? reviewedBy;

  ReportEntity({
    required this.id,
    required this.reporterId,
    required this.targetType,
    required this.targetId,
    required this.reason,
    required this.status,
    this.actionTaken,
    required this.createdAt,
    this.reviewedAt,
    this.reviewedBy,
  });
}
