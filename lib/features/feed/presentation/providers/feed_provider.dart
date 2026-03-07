// lib/features/feed/presentation/providers/feed_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/services/realtime_service.dart';
import '../../../home/domain/entities/artisan_entity.dart';
import '../../../home/domain/repositories/artisan_repository.dart';
import '../../../home/presentation/providers/artisan_provider.dart';
import '../../../jobs/data/models/job_model.dart';

final feedSupabaseProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final feedRealtimeServiceProvider = Provider<RealtimeService>((ref) {
  final supabase = ref.watch(feedSupabaseProvider);
  return RealtimeService(supabase);
});

// Cache only Home-provided location as a fallback for feed refreshes.
HomeResolvedLocation? _cachedHomeLocation;
List<FeedItemModel>? _cachedFeedItems;

// Keep feed stream alive globally so feed opens immediately when user navigates.
final feedPreloadProvider = Provider<void>((ref) {
  ref.watch(feedStreamProvider);
});

// Main feed provider
final feedStreamProvider = StreamProvider<List<FeedItemModel>>((ref) async* {
  final realtimeService = ref.watch(feedRealtimeServiceProvider);
  final supabase = ref.watch(feedSupabaseProvider);
  final artisanRepository = ref.watch(artisanRepositoryProvider);
  final locationService = LocationService();
  var disposed = false;

  ref.onDispose(() {
    disposed = true;
  });

  final homeLocation = ref.watch(homeResolvedLocationProvider);
  if (homeLocation != null) {
    _cachedHomeLocation = homeLocation;
  }

  final latitude = homeLocation?.latitude ??
      _cachedHomeLocation?.latitude ??
      LocationService.defaultLatitude;
  final longitude = homeLocation?.longitude ??
      _cachedHomeLocation?.longitude ??
      LocationService.defaultLongitude;

  if (_cachedFeedItems != null && _cachedFeedItems!.isNotEmpty) {
    yield _cachedFeedItems!;
  }

  // Fast initial load so first open does not wait for realtime stream emission.
  try {
    final initialRows = await supabase
        .from('feed_items')
        .select()
        .order('priority', ascending: false)
        .order('published_at', ascending: false)
        .limit(50)
        .timeout(const Duration(seconds: 8));

    final baseItems = (initialRows as List)
        .where((row) {
          final map = row as Map<String, dynamic>;
          if (!map.containsKey('is_active')) return true;
          return map['is_active'] == true;
        })
        .map((row) => FeedItemModel.fromJson(row as Map<String, dynamic>))
        .toList(growable: false);

    final filteredBaseItems = await _filterInactiveFeedItems(
      supabase: supabase,
      items: baseItems,
    );

    final merged = await _mergeWithNearbyData(
      supabase: supabase,
      artisanRepository: artisanRepository,
      locationService: locationService,
      latitude: latitude,
      longitude: longitude,
      baseItems: filteredBaseItems,
    );

    _cachedFeedItems = merged;
    yield merged;
  } catch (e) {
    print('Initial feed load failed: $e');
  }

  // Realtime updates with retry to avoid "stuck loading" after transient failures.
  while (!disposed) {
    try {
      await for (final rows in realtimeService.listenToFeedUpdates()) {
        if (disposed) break;
        final baseItems = rows
            .map((row) => FeedItemModel.fromJson(row))
            .toList(growable: false);

        final filteredBaseItems = await _filterInactiveFeedItems(
          supabase: supabase,
          items: baseItems,
        );

        final merged = await _mergeWithNearbyData(
          supabase: supabase,
          artisanRepository: artisanRepository,
          locationService: locationService,
          latitude: latitude,
          longitude: longitude,
          baseItems: filteredBaseItems,
        );

        _cachedFeedItems = merged;
        yield merged;
      }
    } catch (e) {
      print('Feed realtime stream failed: $e');
      await Future<void>.delayed(const Duration(seconds: 2));
    }
  }
});

Future<List<FeedItemModel>> _mergeWithNearbyData({
  required SupabaseClient supabase,
  required ArtisanRepository artisanRepository,
  required LocationService locationService,
  required double latitude,
  required double longitude,
  required List<FeedItemModel> baseItems,
}) async {
  const radiusKm = 25.0;

  final existingJobIds = baseItems
      .where((item) => item.jobId != null)
      .map((item) => item.jobId!)
      .toSet();

  final existingArtisanIds = baseItems
      .where((item) => item.artisanId != null)
      .map((item) => item.artisanId!)
      .toSet();

  // Run jobs and artisans queries in parallel
  final results = await Future.wait<List<FeedItemModel>>([
    _fetchNearbyJobs(
      supabase: supabase,
      locationService: locationService,
      latitude: latitude,
      longitude: longitude,
      existingJobIds: existingJobIds,
    ),
    _fetchNearbyArtisans(
      artisanRepository: artisanRepository,
      existingArtisanIds: existingArtisanIds,
      latitude: latitude,
      longitude: longitude,
      radiusKm: radiusKm,
    ),
  ]);

  final jobAndCompletedItems = results[0];
  final artisanItems = results[1];

  final combined = [
    ...baseItems,
    ...jobAndCompletedItems,
    ...artisanItems,
  ];

  // Sort by priority and date
  combined.sort((a, b) {
    if (a.priority != b.priority) {
      return b.priority.compareTo(a.priority);
    }
    return b.publishedAt.compareTo(a.publishedAt);
  });

  return combined;
}

Future<Set<String>> _getActiveUserIds(
  SupabaseClient supabase,
  Iterable<String> userIds,
) async {
  final ids = userIds.where((id) => id.isNotEmpty).toSet();
  if (ids.isEmpty) return <String>{};
  final rows = await supabase
      .from('users')
      .select('id,moderation_status')
      .inFilter('id', ids.toList(growable: false));

  final active = <String>{};
  for (final row in (rows as List)) {
    final map = row as Map<String, dynamic>;
    final status = (map['moderation_status'] as String?) ?? 'active';
    if (status == 'active') {
      active.add(map['id'] as String);
    }
  }
  return active;
}

Future<List<FeedItemModel>> _filterInactiveFeedItems({
  required SupabaseClient supabase,
  required List<FeedItemModel> items,
}) async {
  if (items.isEmpty) return items;
  final userIds = <String>{};
  final jobIdsNeedingLookup = <String>{};
  for (final item in items) {
    if (item.artisanId != null) {
      userIds.add(item.artisanId!);
    }
    final job = item.job;
    if (job != null) {
      userIds.add(job.customerId);
      if (job.acceptedBy != null && job.acceptedBy!.isNotEmpty) {
        userIds.add(job.acceptedBy!);
      }
    } else if (item.jobId != null && item.jobId!.isNotEmpty) {
      jobIdsNeedingLookup.add(item.jobId!);
    }
  }
  Map<String, Map<String, dynamic>> jobById = {};
  if (jobIdsNeedingLookup.isNotEmpty) {
    final jobsResponse = await supabase
        .from('jobs')
        .select('id,customer_id,accepted_by')
        .inFilter('id', jobIdsNeedingLookup.toList(growable: false));
    for (final row in (jobsResponse as List)) {
      final map = row as Map<String, dynamic>;
      jobById[map['id'] as String] = map;
      final customerId = map['customer_id'] as String?;
      final acceptedBy = map['accepted_by'] as String?;
      if (customerId != null && customerId.isNotEmpty) {
        userIds.add(customerId);
      }
      if (acceptedBy != null && acceptedBy.isNotEmpty) {
        userIds.add(acceptedBy);
      }
    }
  }

  if (userIds.isEmpty) return items;

  final activeUserIds = await _getActiveUserIds(supabase, userIds);

  return items.where((item) {
    if (item.artisanId != null && !activeUserIds.contains(item.artisanId)) {
      return false;
    }
    final job = item.job;
    if (job != null) {
      if (!activeUserIds.contains(job.customerId)) return false;
      if (job.acceptedBy != null &&
          job.acceptedBy!.isNotEmpty &&
          !activeUserIds.contains(job.acceptedBy!)) {
        return false;
      }
    } else if (item.jobId != null && item.jobId!.isNotEmpty) {
      final jobRow = jobById[item.jobId!];
      if (jobRow != null) {
        final customerId = jobRow['customer_id'] as String?;
        final acceptedBy = jobRow['accepted_by'] as String?;
        if (customerId != null && !activeUserIds.contains(customerId)) {
          return false;
        }
        if (acceptedBy != null &&
            acceptedBy.isNotEmpty &&
            !activeUserIds.contains(acceptedBy)) {
          return false;
        }
      }
    }
    return true;
  }).toList(growable: false);
}

Future<List<FeedItemModel>> _fetchNearbyJobs({
  required SupabaseClient supabase,
  required LocationService locationService,
  required double latitude,
  required double longitude,
  required Set<String> existingJobIds,
}) async {
  final items = <FeedItemModel>[];

  try {
    final response = await supabase
        .from('jobs')
        .select()
        .order('created_at', ascending: false)
        .limit(30);

    final jobs = (response as List)
        .map((row) => JobModel.fromJson(row as Map<String, dynamic>))
        .where((job) => 
            job.status == 'pending' || 
            job.status == 'matched' || 
            job.status == 'completed')
        .toList();

    final jobUserIds = <String>{};
    for (final job in jobs) {
      jobUserIds.add(job.customerId);
      if (job.acceptedBy != null && job.acceptedBy!.isNotEmpty) {
        jobUserIds.add(job.acceptedBy!);
      }
    }
    final activeUserIds = await _getActiveUserIds(supabase, jobUserIds);

    for (final job in jobs) {
      if (!activeUserIds.contains(job.customerId)) {
        continue;
      }
      if (job.acceptedBy != null &&
          job.acceptedBy!.isNotEmpty &&
          !activeUserIds.contains(job.acceptedBy!)) {
        continue;
      }
      if (existingJobIds.contains(job.id)) continue;

      final distance = locationService.calculateDistance(
        latitude,
        longitude,
        job.latitude,
        job.longitude,
      );

      if (job.status == 'pending' || job.status == 'matched') {
        items.add(
          FeedItemModel(
            id: 'job_${job.id}',
            itemType: 'job_request',
            jobId: job.id,
            title: job.title,
            description: job.description,
            category: job.category,
            isBoosted: job.isBoosted,
            publishedAt: job.createdAt,
            job: job.copyWith(distance: distance),
          ),
        );
      } else if (job.status == 'completed') {
        items.add(
          FeedItemModel(
            id: 'completed_${job.id}',
            itemType: 'completed_job',
            jobId: job.id,
            title: 'Completed: ${job.title}',
            description: job.description,
            category: job.category,
            publishedAt: job.completedAt ?? job.createdAt,
            job: job.copyWith(distance: distance),
          ),
        );
      }
    }
  } catch (e) {
    print('Error fetching nearby jobs: $e');
  }

  return items;
}

Future<List<FeedItemModel>> _fetchNearbyArtisans({
  required ArtisanRepository artisanRepository,
  required Set<String> existingArtisanIds,
  required double latitude,
  required double longitude,
  required double radiusKm,
}) async {
  final items = <FeedItemModel>[];

  try {
    final result = await artisanRepository.getNearbyArtisans(
      latitude: latitude,
      longitude: longitude,
      radiusKm: radiusKm,
      limit: 10,
      offset: 0,
    );

    result.fold(
      (failure) => print('Error fetching artisans: $failure'),
      (artisans) {
        for (final artisan in artisans) {
          if (existingArtisanIds.contains(artisan.userId)) continue;
          items.add(_artisanToFeedItem(artisan));
        }
      },
    );

    // Fallback: if no nearby artisans are found, include featured artisans
    // so Artisans/Nearby tabs are not empty on sparse locations.
    if (items.isEmpty) {
      final featuredResult =
          await artisanRepository.getFeaturedArtisans(limit: 10);
      featuredResult.fold(
        (failure) => print('Error fetching featured artisans: $failure'),
        (artisans) {
          for (final artisan in artisans) {
            if (existingArtisanIds.contains(artisan.userId)) continue;
            items.add(_artisanToFeedItem(artisan));
          }
        },
      );
    }
  } catch (e) {
    print('Error fetching nearby artisans: $e');
  }

  return items;
}

FeedItemModel _artisanToFeedItem(ArtisanEntity artisan) {
  return FeedItemModel(
    id: 'artisan_${artisan.userId}',
    itemType: 'featured_artisan',
    artisanId: artisan.userId,
    title: artisan.name,
    description: artisan.bio,
    category: artisan.category,
    isBoosted: artisan.isFeatured || artisan.premium,
    publishedAt: artisan.updatedAt ?? artisan.createdAt,
    artisanName: artisan.name,
    artisanPhotoUrl: artisan.photoUrl,
    artisanRating: artisan.rating,
    artisanCategory: artisan.category,
    distanceKm: artisan.distance,
  );
}
