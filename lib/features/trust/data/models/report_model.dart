// lib/features/trust/data/models/report_model.dart

import '../../domain/entities/report_entity.dart';

class ReportModel extends ReportEntity {
  ReportModel({
    required super.id,
    required super.reporterId,
    required super.targetType,
    required super.targetId,
    required super.reason,
    required super.status,
    super.actionTaken,
    required super.createdAt,
    super.reviewedAt,
    super.reviewedBy,
  });

  factory ReportModel.fromJson(Map<String, dynamic> json) {
    return ReportModel(
      id: json['id'] as String,
      reporterId: json['reporter_id'] as String,
      targetType: json['target_type'] as String,
      targetId: json['target_id'] as String,
      reason: json['reason'] as String,
      status: json['status'] as String,
      actionTaken: json['action_taken'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      reviewedAt: json['reviewed_at'] != null
          ? DateTime.parse(json['reviewed_at'] as String)
          : null,
      reviewedBy: json['reviewed_by'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'reporter_id': reporterId,
      'target_type': targetType,
      'target_id': targetId,
      'reason': reason,
      'status': status,
      'action_taken': actionTaken,
      'created_at': createdAt.toIso8601String(),
      'reviewed_at': reviewedAt?.toIso8601String(),
      'reviewed_by': reviewedBy,
    };
  }
}
