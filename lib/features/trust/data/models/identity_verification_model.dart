// lib/features/trust/data/models/identity_verification_model.dart

import '../../domain/entities/identity_verification_entity.dart';

class IdentityVerificationModel extends IdentityVerificationEntity {
  IdentityVerificationModel({
    required super.id,
    required super.userId,
    required super.docType,
    required super.docUrl,
    required super.selfieUrl,
    required super.status,
    required super.submittedAt,
    super.reviewedAt,
    super.reviewedBy,
    super.rejectionReason,
  });

  factory IdentityVerificationModel.fromJson(Map<String, dynamic> json) {
    return IdentityVerificationModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      docType: json['doc_type'] as String,
      docUrl: json['doc_url'] as String,
      selfieUrl: json['selfie_url'] as String,
      status: json['status'] as String,
      submittedAt: DateTime.parse(json['submitted_at'] as String),
      reviewedAt: json['reviewed_at'] != null
          ? DateTime.parse(json['reviewed_at'] as String)
          : null,
      reviewedBy: json['reviewed_by'] as String?,
      rejectionReason: json['rejection_reason'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'doc_type': docType,
      'doc_url': docUrl,
      'selfie_url': selfieUrl,
      'status': status,
      'submitted_at': submittedAt.toIso8601String(),
      'reviewed_at': reviewedAt?.toIso8601String(),
      'reviewed_by': reviewedBy,
      'rejection_reason': rejectionReason,
    };
  }
}
