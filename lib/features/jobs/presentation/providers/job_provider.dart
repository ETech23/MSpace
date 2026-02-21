// ================================================================
// JOB PROVIDER (CORRECTED)
// lib/features/jobs/presentation/providers/job_provider.dart
// ================================================================

//import 'package:artisan_marketplace/features/jobs/data/models/job_match_model.dart';
import 'package:artisan_marketplace/features/jobs/domain/repositories/job_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models/job_model.dart';
import '../../data/datasources/job_remote_datasource.dart';
//import '../../domain/repositories/job_repository.dart';

// ================================================================
// STATE CLASS
// ================================================================

class JobState {
  final List<JobModel> customerJobs;
  final List<JobMatchModel> artisanMatches;
  final bool isLoading;
  final bool isPosting;
  final String? error;
  final JobModel? activeJob;

  JobState({
    this.customerJobs = const [],
    this.artisanMatches = const [],
    this.isLoading = false,
    this.isPosting = false,
    this.error,
    this.activeJob,
  });

  JobState copyWith({
    List<JobModel>? customerJobs,
    List<JobMatchModel>? artisanMatches,
    bool? isLoading,
    bool? isPosting,
    String? error,
    JobModel? activeJob,
  }) {
    return JobState(
      customerJobs: customerJobs ?? this.customerJobs,
      artisanMatches: artisanMatches ?? this.artisanMatches,
      isLoading: isLoading ?? this.isLoading,
      isPosting: isPosting ?? this.isPosting,
      error: error,
      activeJob: activeJob ?? this.activeJob,
    );
  }
}

// ================================================================
// PROVIDERS
// ================================================================

// Supabase client provider
final supabaseProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

// Data source provider
final jobRemoteDataSourceProvider = Provider<JobRemoteDataSource>((ref) {
  final supabase = ref.watch(supabaseProvider);
  return JobRemoteDataSourceImpl(supabaseClient: supabase);
});

// Repository provider
final jobRepositoryProvider = Provider<JobRepository>((ref) {
  final dataSource = ref.watch(jobRemoteDataSourceProvider);
  return JobRepositoryImpl(remoteDataSource: dataSource);
});

// Main job provider
final jobProvider = StateNotifierProvider<JobNotifier, JobState>((ref) {
  final repository = ref.watch(jobRepositoryProvider);
  return JobNotifier(repository);
});

// ================================================================
// NOTIFIER
// ================================================================

class JobNotifier extends StateNotifier<JobState> {
  final JobRepository _repository;

  JobNotifier(this._repository) : super(JobState());

  Future<JobModel?> postJob(JobFormModel form, String customerId) async {
    state = state.copyWith(isPosting: true, error: null);

    try {
      final job = await _repository.postJob(form, customerId);
      
      state = state.copyWith(
        isPosting: false,
        customerJobs: [job, ...state.customerJobs],
        activeJob: job,
      );

      return job;
    } catch (e) {
      state = state.copyWith(
        isPosting: false,
        error: e.toString(),
      );
      return null;
    }
  }
/**
  Future<void> loadCustomerJobs(String customerId) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final jobs = await _repository.getCustomerJobs(customerId);
      state = state.copyWith(
        isLoading: false,
        customerJobs: jobs,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }**/


Future<void> loadCustomerJobs(String userId) async {
  state = state.copyWith(isLoading: true, error: null);

  try {
    final jobs = await _repository.getCustomerJobs(userId);
    state = state.copyWith(
      isLoading: false,
      customerJobs: jobs,
    );
  } catch (e) {
    state = state.copyWith(
      isLoading: false,
      error: e.toString(),
    );
  }
}

  Future<void> loadArtisanMatches(String artisanId) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final matches = await _repository.getArtisanJobMatches(artisanId);
      state = state.copyWith(
        isLoading: false,
        artisanMatches: matches,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<JobModel?> acceptJob(String jobId, String artisanId) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      // ✅ This now creates a booking automatically via the trigger
      final job = await _repository.acceptJob(jobId, artisanId);
      
      state = state.copyWith(
        isLoading: false,
        artisanMatches: state.artisanMatches
            .where((m) => m.jobId != jobId)
            .toList(),
        activeJob: job,
      );

      return job;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      return null;
    }
  }


/**
  Future<JobModel?> acceptJob(String jobId, String artisanId) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final job = await _repository.acceptJob(jobId, artisanId);
      
      state = state.copyWith(
        isLoading: false,
        artisanMatches: state.artisanMatches
            .where((m) => m.jobId != jobId)
            .toList(),
        activeJob: job,
      );

      return job;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      return null;
    }
  } **/

  Future<void> rejectJob(String jobId, String artisanId) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      await _repository.rejectJob(jobId, artisanId);
      state = state.copyWith(
        isLoading: false,
        artisanMatches: state.artisanMatches
            .where((m) => !(m.jobId == jobId && m.artisanId == artisanId))
            .toList(),
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  // New: Load a single job by id (used by JobDetailsScreen and deep links)
  Future<void> loadJobById(String jobId) async {
    // Avoid re-fetching if already loading
    if (state.isLoading) return;

    state = state.copyWith(isLoading: true, error: null);
    print('🔍 Loading job by id: $jobId' );

    try {
      final job = await _repository.getJobById(jobId);

      // Add to customerJobs if not present for easier navigation
      final exists = state.customerJobs.any((j) => j.id == job.id);
      final updatedJobs = exists ? state.customerJobs : [job, ...state.customerJobs];

      state = state.copyWith(isLoading: false, activeJob: job, customerJobs: updatedJobs);
      print('✅ Loaded job: ${job.id}');
    } catch (e) {
      print('❌ Failed to load job: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
  Future<void> updateJobStatus(String jobId, String status) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final job = await _repository.updateJobStatus(jobId, status);
      
      state = state.copyWith(
        isLoading: false,
        activeJob: job,
        customerJobs: state.customerJobs
            .map((j) => j.id == jobId ? job : j)
            .toList(),
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> cancelJob(String jobId) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      await _repository.cancelJob(jobId);
      
      state = state.copyWith(
        isLoading: false,
        customerJobs: state.customerJobs
            .map((j) => j.id == jobId ? j.copyWith(status: 'cancelled') : j)
            .toList(),
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

// ================================================================
// COMPUTED PROVIDERS
// ================================================================

final activeJobsCountProvider = Provider<int>((ref) {
  final jobs = ref.watch(jobProvider).customerJobs;
  return jobs.where((j) => 
    j.status != 'completed' && j.status != 'cancelled'
  ).length;
});

final unreadMatchesCountProvider = Provider<int>((ref) {
  return ref.watch(jobProvider).artisanMatches
      .where((m) => m.viewedAt == null)
      .length;
});