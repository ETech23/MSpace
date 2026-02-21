import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:artisan_marketplace/features/jobs/presentation/providers/job_provider.dart';
import 'package:artisan_marketplace/features/jobs/data/models/job_model.dart';
import 'package:artisan_marketplace/features/jobs/data/models/job_model.dart' as models;
import 'package:artisan_marketplace/features/jobs/data/datasources/job_remote_datasource.dart';
import 'package:artisan_marketplace/features/jobs/data/datasources/job_remote_datasource.dart' as ds;
import 'package:artisan_marketplace/core/error/exceptions.dart';

// Mock repository
class MockJobRepository extends Mock implements JobRepository {}

void main() {
  late MockJobRepository mockRepository;
  late JobNotifier notifier;

  setUp(() {
    mockRepository = MockJobRepository();
    notifier = JobNotifier(mockRepository);
  });

  group('acceptJob', () {
    final jobId = 'job-1';
    final artisanId = 'artisan-1';

    test('successfully accepts a pending job and removes match', () async {
      final job = JobModel(
        id: jobId,
        customerId: 'cust-1',
        title: 'Test Job',
        description: 'Desc',
        category: 'Plumbing',
        latitude: 0.0,
        longitude: 0.0,
        createdAt: DateTime.now(),
      );

      // prepare a job match
      final match = JobMatchModel(
        id: 'match-1',
        jobId: jobId,
        artisanId: artisanId,
        distanceKm: 1.0,
        matchScore: 90.0,
        isPremiumArtisan: false,
        priorityTier: 0,
        notificationDelaySeconds: 0,
        notifiedAt: DateTime.now(),
      );

      // seed state with match
      notifier.state = notifier.state.copyWith(artisanMatches: [match]);

      when(() => mockRepository.acceptJob(jobId, artisanId)).thenAnswer((_) async => job);

      final result = await notifier.acceptJob(jobId, artisanId);

      expect(result, isNotNull);
      expect(notifier.state.artisanMatches.every((m) => m.jobId != jobId), isTrue);
      expect(notifier.state.activeJob?.id, equals(jobId));
      expect(notifier.state.error, isNull);
    });

    test('returns error when job already accepted', () async {
      when(() => mockRepository.acceptJob(jobId, artisanId)).thenThrow(const ServerException(message: 'Job has already been accepted'));

      // seed state with a match to ensure it is not removed on failure
      final match = JobMatchModel(
        id: 'match-1',
        jobId: jobId,
        artisanId: artisanId,
        distanceKm: 1.0,
        matchScore: 90.0,
        isPremiumArtisan: false,
        priorityTier: 0,
        notificationDelaySeconds: 0,
        notifiedAt: DateTime.now(),
      );
      notifier.state = notifier.state.copyWith(artisanMatches: [match]);

      final result = await notifier.acceptJob(jobId, artisanId);

      expect(result, isNull);
      expect(notifier.state.error, contains('Job has already been accepted'));
      expect(notifier.state.artisanMatches.length, equals(1));
    });

    test('returns error when job is cancelled', () async {
      when(() => mockRepository.acceptJob(jobId, artisanId)).thenThrow(const ServerException(message: 'Job is no longer available'));

      final match = JobMatchModel(
        id: 'match-1',
        jobId: jobId,
        artisanId: artisanId,
        distanceKm: 1.0,
        matchScore: 90.0,
        isPremiumArtisan: false,
        priorityTier: 0,
        notificationDelaySeconds: 0,
        notifiedAt: DateTime.now(),
      );
      notifier.state = notifier.state.copyWith(artisanMatches: [match]);

      final result = await notifier.acceptJob(jobId, artisanId);

      expect(result, isNull);
      expect(notifier.state.error, contains('Job is no longer available'));
      expect(notifier.state.artisanMatches.length, equals(1));
    });
  });
}