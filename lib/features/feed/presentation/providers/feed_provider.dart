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

// Cache for location to avoid repeated GPS calls
class _LocationCache {
  final double lat;
  final double lng;
  final DateTime timestamp;

  _LocationCache(this.lat, this.lng, this.timestamp);

  bool get isStale => DateTime.now().difference(timestamp).inMinutes > 5;
}

_LocationCache? _cachedLocation;

// Main feed provider - simplified
final feedStreamProvider = StreamProvider.autoDispose<List<FeedItemModel>>((ref) async* {
  final realtimeService = ref.watch(feedRealtimeServiceProvider);
  final supabase = ref.watch(feedSupabaseProvider);
  final artisanRepository = ref.watch(artisanRepositoryProvider);
  final locationService = LocationService();

  // Get location (use cache if available)
  double latitude;
  double longitude;

  if (_cachedLocation != null && !_cachedLocation!.isStale) {
    latitude = _cachedLocation!.lat;
    longitude = _cachedLocation!.lng;
  } else {
    final position = await locationService.getCurrentLocation();
    latitude = position?.latitude ?? LocationService.defaultLatitude;
    longitude = position?.longitude ?? LocationService.defaultLongitude;
    _cachedLocation = _LocationCache(latitude, longitude, DateTime.now());
  }

  await for (final rows in realtimeService.listenToFeedUpdates()) {
    final baseItems = rows
        .map((row) => FeedItemModel.fromJson(row))
        .toList(growable: false);

    final merged = await _mergeWithNearbyData(
      supabase: supabase,
      artisanRepository: artisanRepository,
      locationService: locationService,
      latitude: latitude,
      longitude: longitude,
      baseItems: baseItems,
    );

    yield merged;
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
  final results = await Future.wait([
    _fetchNearbyJobs(
      supabase: supabase,
      locationService: locationService,
      latitude: latitude,
      longitude: longitude,
      radiusKm: radiusKm,
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

  final jobAndCompletedItems = results[0] as List<FeedItemModel>;
  final artisanItems = results[1] as List<FeedItemModel>;

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

Future<List<FeedItemModel>> _fetchNearbyJobs({
  required SupabaseClient supabase,
  required LocationService locationService,
  required double latitude,
  required double longitude,
  required double radiusKm,
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

    for (final job in jobs) {
      if (existingJobIds.contains(job.id)) continue;

      final distance = locationService.calculateDistance(
        latitude,
        longitude,
        job.latitude,
        job.longitude,
      );

      if (distance > radiusKm) continue;

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
  );
}