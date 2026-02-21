// lib/features/trust/domain/entities/identity_verification_entity.dart

class IdentityVerificationEntity {
  final String id;
  final String userId;
  final String docType;
  final String docUrl;
  final String selfieUrl;
  final String status; // pending, verified, rejected
  final DateTime submittedAt;
  final DateTime? reviewedAt;
  final String? reviewedBy;
  final String? rejectionReason;

  IdentityVerificationEntity({
    required this.id,
    required this.userId,
    required this.docType,
    required this.docUrl,
    required this.selfieUrl,
    required this.status,
    required this.submittedAt,
    this.reviewedAt,
    this.reviewedBy,
    this.rejectionReason,
  });
}
