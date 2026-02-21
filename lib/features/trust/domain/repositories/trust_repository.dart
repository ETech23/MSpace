// lib/features/trust/domain/repositories/trust_repository.dart

import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/identity_verification_entity.dart';
import '../entities/dispute_entity.dart';
import '../entities/report_entity.dart';

abstract class TrustRepository {
  // Identity verification
  Future<Either<Failure, IdentityVerificationEntity?>>
      getLatestIdentityVerification(String userId);
  Future<Either<Failure, IdentityVerificationEntity>>
      submitIdentityVerification({
    required String userId,
    required String docType,
    required String docFilePath,
    required String selfieFilePath,
  });
  Future<Either<Failure, List<IdentityVerificationEntity>>>
      adminListIdentityVerifications({String? status});
  Future<Either<Failure, void>> adminReviewIdentityVerification({
    required String verificationId,
    required String status,
    String? rejectionReason,
  });

  // Disputes
  Future<Either<Failure, DisputeEntity>> openDispute({
    required String bookingId,
    required String openedBy,
    required String reason,
    List<String> evidenceFilePaths,
  });
  Future<Either<Failure, List<DisputeEntity>>> getDisputesForBooking(
    String bookingId,
  );
  Future<Either<Failure, List<DisputeEntity>>> getMyDisputes(String userId);
  Future<Either<Failure, List<DisputeEntity>>> adminListDisputes({
    String? status,
  });
  Future<Either<Failure, void>> adminResolveDispute({
    required String disputeId,
    required String status,
    String? resolutionNotes,
  });

  // Moderation reports
  Future<Either<Failure, ReportEntity>> submitReport({
    required String reporterId,
    required String targetType,
    required String targetId,
    required String reason,
  });
  Future<Either<Failure, List<ReportEntity>>> getMyReports(String userId);
  Future<Either<Failure, List<ReportEntity>>> adminListReports({
    String? status,
  });
  Future<Either<Failure, void>> adminUpdateReport({
    required String reportId,
    required String status,
    String? actionTaken,
  });
}
