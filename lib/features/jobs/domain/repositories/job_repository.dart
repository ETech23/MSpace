// ================================================================
// JOB REPOSITORY
// lib/features/jobs/domain/repositories/job_repository.dart
// ================================================================

import 'package:artisan_marketplace/features/jobs/data/datasources/job_remote_datasource.dart';
import 'package:artisan_marketplace/features/jobs/data/models/job_model.dart';

abstract class JobRepository {
  Future<JobModel> postJob(JobFormModel form, String customerId);
  Future<List<JobModel>> getCustomerJobs(String customerId);
  Future<JobModel> getJobById(String jobId);
  Future<List<JobMatchModel>> getArtisanJobMatches(String artisanId);
  Future<JobModel> acceptJob(String jobId, String artisanId);
  Future<void> rejectJob(String jobId, String artisanId);
  Future<JobModel> updateJobStatus(String jobId, String status);
  Future<void> cancelJob(String jobId);
}

class JobRepositoryImpl implements JobRepository {
  final JobRemoteDataSource remoteDataSource;

  JobRepositoryImpl({required this.remoteDataSource});

  @override
  Future<JobModel> postJob(JobFormModel form, String customerId) {
    return remoteDataSource.postJob(form, customerId);
  }

  @override
  Future<List<JobModel>> getCustomerJobs(String customerId) {
    return remoteDataSource.getCustomerJobs(customerId);
  }

  @override
  Future<JobModel> getJobById(String jobId) {
    return remoteDataSource.getJobById(jobId);
  }

  @override
  Future<List<JobMatchModel>> getArtisanJobMatches(String artisanId) {
    return remoteDataSource.getArtisanJobMatches(artisanId);
  }

  @override
  Future<JobModel> acceptJob(String jobId, String artisanId) {
    return remoteDataSource.acceptJob(jobId, artisanId);
  }

  @override
  Future<void> rejectJob(String jobId, String artisanId) {
    return remoteDataSource.rejectJob(jobId, artisanId);
  }

  @override
  Future<JobModel> updateJobStatus(String jobId, String status) {
    return remoteDataSource.updateJobStatus(jobId, status);
  }

  @override
  Future<void> cancelJob(String jobId) {
    return remoteDataSource.cancelJob(jobId);
  }
}