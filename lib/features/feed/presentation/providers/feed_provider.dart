// lib/features/feed/presentation/providers/feed_provider.dart
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/services/realtime_service.dart';
import '../../../home/domain/entities/artisan_entity.dart';
import '../../../home/domain/repositories/artisan_repository.dart';
import '../../../home/presentation/providers/artisan_provider.dart';
import '../../../jobs/data/models/job_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

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
  final authState = ref.watch(authProvider);
  final currentUserId = authState.user?.id;
  final locationService = LocationService();
  var disposed = false;
  final controller = StreamController<List<FeedItemModel>>();
  StreamSubscription<List<Map<String, dynamic>>>? feedSub;
  StreamSubscription<List<Map<String, dynamic>>>? tipsSub;
  List<Map<String, dynamic>> latestFeedRows = [];
  List<Map<String, dynamic>> latestTipRows = [];

  ref.onDispose(() {
    disposed = true;
    feedSub?.cancel();
    tipsSub?.cancel();
    controller.close();
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

  Future<List<FeedItemModel>> emitMerged() async {
    final baseItems = latestFeedRows
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
      currentUserId: currentUserId,
    );

    final tipItems = latestTipRows
        .map((row) => _tipRowToFeedItem(row))
        .toList(growable: false);

    final combined = [...tipItems, ...merged]
      ..sort((a, b) {
        final byPriority = b.priority.compareTo(a.priority);
        if (byPriority != 0) return byPriority;
        return b.publishedAt.compareTo(a.publishedAt);
      });

    _cachedFeedItems = combined;
    if (!controller.isClosed) {
      controller.add(combined);
    }
    return combined;
  }

  // Fast initial load so first open does not wait for realtime stream emission.
  try {
    final initialFeedRows = await supabase
        .from('feed_items')
        .select()
        .order('priority', ascending: false)
        .order('published_at', ascending: false)
        .limit(50)
        .timeout(const Duration(seconds: 8));

    final initialTipRows = await supabase
        .from('feed_tips')
        .select()
        .eq('is_active', true)
        .order('created_at', ascending: false)
        .limit(10)
        .timeout(const Duration(seconds: 8));

    latestFeedRows = (initialFeedRows as List)
        .where((row) {
          final map = row as Map<String, dynamic>;
          if (!map.containsKey('is_active')) return true;
          return map['is_active'] == true;
        })
        .map((row) => row as Map<String, dynamic>)
        .toList(growable: false);

    latestTipRows = (initialTipRows as List)
        .where((row) => row is Map<String, dynamic>)
        .map((row) => row as Map<String, dynamic>)
        .toList(growable: false);

    final combined = await emitMerged();
    yield combined;
  } catch (e) {
    print('Initial feed load failed: $e');
  }

  // Realtime updates with retry to avoid "stuck loading" after transient failures.
  while (!disposed) {
    try {
      feedSub?.cancel();
      tipsSub?.cancel();

      feedSub = realtimeService.listenToFeedUpdates().listen((rows) async {
        if (disposed) return;
        latestFeedRows = rows;
        await emitMerged();
      });

      tipsSub = supabase
          .from('feed_tips')
          .stream(primaryKey: ['id'])
          .eq('is_active', true)
          .order('created_at', ascending: false)
          .limit(10)
          .listen((rows) async {
        if (disposed) return;
        latestTipRows = rows;
        await emitMerged();
      });

      yield* controller.stream;
    } catch (e) {
      print('Feed realtime stream failed: $e');
      await Future<void>.delayed(const Duration(seconds: 2));
    }
  }
});

class FeedTipQuery {
  final String userId;
  final String userType;

  const FeedTipQuery({required this.userId, required this.userType});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FeedTipQuery &&
          runtimeType == other.runtimeType &&
          userId == other.userId &&
          userType == other.userType;

  @override
  int get hashCode => userId.hashCode ^ userType.hashCode;
}

final feedTipUnreadCountProvider =
    FutureProvider.family<int, FeedTipQuery>((ref, query) async {
  final supabase = ref.watch(feedSupabaseProvider);
  final userType = query.userType.toLowerCase();
  final lastSeenRow = await supabase
      .from('feed_tip_reads')
      .select('last_seen_at')
      .eq('user_id', query.userId)
      .maybeSingle();
  final lastSeenRaw = lastSeenRow?['last_seen_at'] as String?;
  final lastSeen =
      lastSeenRaw == null ? null : DateTime.tryParse(lastSeenRaw);

  final rows = await supabase
      .from('feed_tips')
      .select('id,created_at')
      .eq('is_active', true)
      .or('user_type.eq.all,user_type.eq.$userType')
      .order('created_at', ascending: false)
      .limit(25);

  final hasUnread = (rows as List).any((row) {
    final createdAtRaw = (row as Map<String, dynamic>)['created_at'] as String?;
    if (createdAtRaw == null) return false;
    final createdAt = DateTime.tryParse(createdAtRaw);
    if (createdAt == null) return false;
    if (lastSeen == null) return true;
    return createdAt.isAfter(lastSeen);
  });
  return hasUnread ? 1 : 0;
});

final feedTipActionsProvider = Provider<FeedTipActions>((ref) {
  final supabase = ref.watch(feedSupabaseProvider);
  return FeedTipActions(supabase);
});

class FeedTipActions {
  FeedTipActions(this._client);
  final SupabaseClient _client;

  Future<void> markTipsSeen({required String userId}) async {
    await _client.from('feed_tip_reads').upsert({
      'user_id': userId,
      'last_seen_at': DateTime.now().toIso8601String(),
    });
  }
}

FeedItemModel _tipRowToFeedItem(Map<String, dynamic> row) {
  final createdAt = row['created_at'] as String?;
  final published = createdAt != null
      ? DateTime.parse(createdAt).toLocal()
      : DateTime.now();
  return FeedItemModel(
    id: 'tip_${row['id']}',
    itemType: 'tip',
    title: row['title'] as String? ?? 'Tip',
    description: row['tip'] as String? ?? row['description'] as String?,
    targetUserType: row['user_type'] as String? ?? 'all',
    publishedAt: published,
    priority: row['priority'] as int? ?? 0,
    isActive: row['is_active'] as bool? ?? true,
  );
}

Future<List<FeedItemModel>> _mergeWithNearbyData({
  required SupabaseClient supabase,
  required ArtisanRepository artisanRepository,
  required LocationService locationService,
  required double latitude,
  required double longitude,
  required List<FeedItemModel> baseItems,
  required String? currentUserId,
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
      currentUserId: currentUserId,
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
    // DB column names are fixed; do not rename (customer_id in DB).
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

    const visibleStatuses = {
      'pending',
      'matched',
      'accepted',
      'completed',
      'open',
      'active',
      'new',
    };

    final jobs = (response as List)
        .where((row) =>
            row is Map<String, dynamic> &&
            row['latitude'] != null &&
            row['longitude'] != null)
        .map((row) => JobModel.fromJson(row as Map<String, dynamic>))
        .where((job) => visibleStatuses.contains(job.status))
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
  required String? currentUserId,
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
          // Exclude current user's own profile from feed
          if (currentUserId != null && artisan.userId == currentUserId) continue;
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
            // Exclude current user's own profile from feed
            if (currentUserId != null && artisan.userId == currentUserId) continue;
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


