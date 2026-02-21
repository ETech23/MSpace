// lib/features/trust/data/models/dispute_model.dart

import '../../domain/entities/dispute_entity.dart';

class DisputeModel extends DisputeEntity {
  DisputeModel({
    required super.id,
    required super.bookingId,
    required super.openedBy,
    required super.reason,
    required super.evidenceUrls,
    required super.status,
    required super.openedAt,
    super.resolvedAt,
    super.resolvedBy,
    super.resolutionNotes,
  });

  factory DisputeModel.fromJson(Map<String, dynamic> json) {
    final evidence = json['evidence_urls'];
    return DisputeModel(
      id: json['id'] as String,
      bookingId: json['booking_id'] as String,
      openedBy: json['raised_by'] as String,
      reason: json['reason'] as String,
      evidenceUrls: evidence is List
          ? evidence.map((e) => e.toString()).toList()
          : <String>[],
      status: json['status'] as String,
      openedAt: DateTime.parse(json['opened_at'] as String),
      resolvedAt: json['resolved_at'] != null
          ? DateTime.parse(json['resolved_at'] as String)
          : null,
      resolvedBy: json['resolved_by'] as String?,
      resolutionNotes: json['resolution_notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'booking_id': bookingId,
      'raised_by': openedBy,
      'reason': reason,
      'evidence_urls': evidenceUrls,
      'status': status,
      'opened_at': openedAt.toIso8601String(),
      'resolved_at': resolvedAt?.toIso8601String(),
      'resolved_by': resolvedBy,
      'resolution_notes': resolutionNotes,
    };
  }
}
