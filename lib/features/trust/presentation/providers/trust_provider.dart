// lib/features/trust/presentation/providers/trust_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/injection_container.dart';
import '../../domain/entities/identity_verification_entity.dart';
import '../../domain/entities/dispute_entity.dart';
import '../../domain/entities/report_entity.dart';
import '../../domain/repositories/trust_repository.dart';

final trustRepositoryProvider = Provider<TrustRepository>((ref) {
  return getIt<TrustRepository>();
});

// ---------------------------
// Identity Verification
// ---------------------------
class IdentityVerificationState {
  final bool isLoading;
  final bool isSubmitting;
  final IdentityVerificationEntity? verification;
  final String? error;
  final String? successMessage;

  IdentityVerificationState({
    this.isLoading = false,
    this.isSubmitting = false,
    this.verification,
    this.error,
    this.successMessage,
  });

  IdentityVerificationState copyWith({
    bool? isLoading,
    bool? isSubmitting,
    IdentityVerificationEntity? verification,
    String? error,
    String? successMessage,
  }) {
    return IdentityVerificationState(
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      verification: verification ?? this.verification,
      error: error,
      successMessage: successMessage,
    );
  }
}

class IdentityVerificationNotifier
    extends StateNotifier<IdentityVerificationState> {
  final TrustRepository repository;

  IdentityVerificationNotifier({required this.repository})
      : super(IdentityVerificationState());

  Future<void> loadLatest(String userId) async {
    state = state.copyWith(isLoading: true, error: null);
    final result = await repository.getLatestIdentityVerification(userId);
    result.fold(
      (failure) {
        state = state.copyWith(isLoading: false, error: failure.message);
      },
      (verification) {
        state = state.copyWith(
          isLoading: false,
          verification: verification,
        );
      },
    );
  }

  Future<bool> submit({
    required String userId,
    required String docType,
    required String docFilePath,
    required String selfieFilePath,
  }) async {
    state = state.copyWith(isSubmitting: true, error: null, successMessage: null);
    final result = await repository.submitIdentityVerification(
      userId: userId,
      docType: docType,
      docFilePath: docFilePath,
      selfieFilePath: selfieFilePath,
    );
    return result.fold(
      (failure) {
        state = state.copyWith(isSubmitting: false, error: failure.message);
        return false;
      },
      (verification) {
        state = state.copyWith(
          isSubmitting: false,
          verification: verification,
          successMessage: 'Verification submitted',
        );
        return true;
      },
    );
  }

  void clearMessages() {
    state = state.copyWith(error: null, successMessage: null);
  }
}

final identityVerificationProvider =
    StateNotifierProvider<IdentityVerificationNotifier, IdentityVerificationState>(
  (ref) => IdentityVerificationNotifier(
    repository: ref.watch(trustRepositoryProvider),
  ),
);

final adminIdentityQueueProvider =
    FutureProvider<List<IdentityVerificationEntity>>((ref) async {
  final repository = ref.watch(trustRepositoryProvider);
  final result = await repository.adminListIdentityVerifications(status: 'pending');
  return result.fold(
    (failure) => throw Exception(failure.message),
    (items) => items,
  );
});

// ---------------------------
// Disputes
// ---------------------------
class DisputeState {
  final bool isSubmitting;
  final String? error;
  final String? successMessage;

  DisputeState({
    this.isSubmitting = false,
    this.error,
    this.successMessage,
  });

  DisputeState copyWith({
    bool? isSubmitting,
    String? error,
    String? successMessage,
  }) {
    return DisputeState(
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: error,
      successMessage: successMessage,
    );
  }
}

class DisputeNotifier extends StateNotifier<DisputeState> {
  final TrustRepository repository;

  DisputeNotifier({required this.repository}) : super(DisputeState());

  Future<bool> openDispute({
    required String bookingId,
    required String openedBy,
    required String reason,
    List<String> evidenceFilePaths = const [],
  }) async {
    state = state.copyWith(isSubmitting: true, error: null, successMessage: null);
    final result = await repository.openDispute(
      bookingId: bookingId,
      openedBy: openedBy,
      reason: reason,
      evidenceFilePaths: evidenceFilePaths,
    );
    return result.fold(
      (failure) {
        state = state.copyWith(isSubmitting: false, error: failure.message);
        return false;
      },
      (_) {
        state = state.copyWith(
          isSubmitting: false,
          successMessage: 'Dispute opened',
        );
        return true;
      },
    );
  }

  void clearMessages() {
    state = state.copyWith(error: null, successMessage: null);
  }
}

final disputeProvider = StateNotifierProvider<DisputeNotifier, DisputeState>(
  (ref) => DisputeNotifier(repository: ref.watch(trustRepositoryProvider)),
);

final disputesByBookingProvider =
    FutureProvider.family<List<DisputeEntity>, String>((ref, bookingId) async {
  final repository = ref.watch(trustRepositoryProvider);
  final result = await repository.getDisputesForBooking(bookingId);
  return result.fold(
    (failure) => throw Exception(failure.message),
    (items) => items,
  );
});

final adminDisputesProvider = FutureProvider<List<DisputeEntity>>((ref) async {
  final repository = ref.watch(trustRepositoryProvider);
final result = await repository.adminListDisputes(status: 'open');
  return result.fold(
    (failure) => throw Exception(failure.message),
    (items) => items,
  );
});

// ---------------------------
// Reports
// ---------------------------
class ReportState {
  final bool isSubmitting;
  final String? error;
  final String? successMessage;

  ReportState({
    this.isSubmitting = false,
    this.error,
    this.successMessage,
  });

  ReportState copyWith({
    bool? isSubmitting,
    String? error,
    String? successMessage,
  }) {
    return ReportState(
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: error,
      successMessage: successMessage,
    );
  }
}

class ReportNotifier extends StateNotifier<ReportState> {
  final TrustRepository repository;

  ReportNotifier({required this.repository}) : super(ReportState());

  Future<bool> submitReport({
    required String reporterId,
    required String targetType,
    required String targetId,
    required String reason,
  }) async {
    state = state.copyWith(isSubmitting: true, error: null, successMessage: null);
    final result = await repository.submitReport(
      reporterId: reporterId,
      targetType: targetType,
      targetId: targetId,
      reason: reason,
    );
    return result.fold(
      (failure) {
        state = state.copyWith(isSubmitting: false, error: failure.message);
        return false;
      },
      (_) {
        state = state.copyWith(
          isSubmitting: false,
          successMessage: 'Report submitted',
        );
        return true;
      },
    );
  }

  void clearMessages() {
    state = state.copyWith(error: null, successMessage: null);
  }
}

final reportProvider = StateNotifierProvider<ReportNotifier, ReportState>(
  (ref) => ReportNotifier(repository: ref.watch(trustRepositoryProvider)),
);

final adminReportsProvider = FutureProvider<List<ReportEntity>>((ref) async {
  final repository = ref.watch(trustRepositoryProvider);
  final result = await repository.adminListReports(status: 'reported');
  return result.fold(
    (failure) => throw Exception(failure.message),
    (items) => items,
  );
});
