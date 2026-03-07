import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/injection_container.dart';
import '../../domain/repositories/artisan_repository.dart';
import '../../domain/entities/artisan_entity.dart';

class HomeResolvedLocation {
  final double latitude;
  final double longitude;
  final bool isApproximate;

  const HomeResolvedLocation({
    required this.latitude,
    required this.longitude,
    required this.isApproximate,
  });
}

final homeResolvedLocationProvider =
    StateProvider<HomeResolvedLocation?>((ref) => null);

// Provider for repository
final artisanRepositoryProvider = Provider<ArtisanRepository>(
  (ref) => getIt<ArtisanRepository>(),
);

// State class
class ArtisanState {
  final List<ArtisanEntity> featuredArtisans;
  final List<ArtisanEntity> nearbyArtisans;
  final bool isLoadingFeatured;
  final bool isLoadingNearby;
  final bool isLoadingMore;
  final bool isSearchingWider;
  final String? error;
  final int currentPage;
  final bool hasMore;
  final double? currentSearchRadius;
  final String? searchMessage;

  ArtisanState({
    this.featuredArtisans = const [],
    this.nearbyArtisans = const [],
    this.isLoadingFeatured = false,
    this.isLoadingNearby = false,
    this.isLoadingMore = false,
    this.isSearchingWider = false,
    this.error,
    this.currentPage = 0,
    this.hasMore = true,
    this.currentSearchRadius,
    this.searchMessage,
  });

  ArtisanState copyWith({
    List<ArtisanEntity>? featuredArtisans,
    List<ArtisanEntity>? nearbyArtisans,
    bool? isLoadingFeatured,
    bool? isLoadingNearby,
    bool? isLoadingMore,
    bool? isSearchingWider,
    String? error,
    int? currentPage,
    bool? hasMore,
    double? currentSearchRadius,
    String? searchMessage,
  }) {
    return ArtisanState(
      featuredArtisans: featuredArtisans ?? this.featuredArtisans,
      nearbyArtisans: nearbyArtisans ?? this.nearbyArtisans,
      isLoadingFeatured: isLoadingFeatured ?? this.isLoadingFeatured,
      isLoadingNearby: isLoadingNearby ?? this.isLoadingNearby,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isSearchingWider: isSearchingWider ?? this.isSearchingWider,
      error: error,
      currentPage: currentPage ?? this.currentPage,
      hasMore: hasMore ?? this.hasMore,
      currentSearchRadius: currentSearchRadius ?? this.currentSearchRadius,
      searchMessage: searchMessage,
    );
  }
}

// Notifier
class ArtisanNotifier extends StateNotifier<ArtisanState> {
  final ArtisanRepository repository;
  DateTime? _featuredFetchedAtUtc;
  static const Duration _featuredTtl = Duration(minutes: 3);

  ArtisanNotifier(this.repository) : super(ArtisanState());

  // Search radiuses to try (in km): 10, 25, 50, 100, 200, 500
  static const List<double> searchRadiuses = [10, 25, 50, 100, 200, 500];

  Future<void> loadFeaturedArtisans({
    int limit = 10,
    double? latitude,
    double? longitude,
    bool nationwide = false,
    bool forceRefresh = false,
  }) async {
    final now = DateTime.now().toUtc();
    final hasFreshCache = !forceRefresh &&
        state.featuredArtisans.isNotEmpty &&
        _featuredFetchedAtUtc != null &&
        now.difference(_featuredFetchedAtUtc!) < _featuredTtl;

    if (hasFreshCache) {
      return;
    }

    state = state.copyWith(isLoadingFeatured: true, error: null);

    final result = await repository.getFeaturedArtisans(
      limit: limit,
      latitude: latitude,
      longitude: longitude,
      nationwide: nationwide,
    );

    result.fold(
      (failure) {
        state = state.copyWith(
          isLoadingFeatured: false,
          error: failure.message,
        );
      },
      (artisans) {
        _featuredFetchedAtUtc = DateTime.now().toUtc();
        state = state.copyWith(
          featuredArtisans: artisans,
          isLoadingFeatured: false,
          error: null,
        );
      },
    );
  }

 /// Smart proximity search - expands radius until artisans are found
  /// ALWAYS finds artisans by expanding to unlimited radius if needed
  Future<void> loadNearbyArtisans({
    double? latitude,
    double? longitude,
    String? category,
  }) async {
    print('🌍 Provider: Loading nearby artisans...');
    print('   Coordinates: ($latitude, $longitude)');
    
    if (latitude == null || longitude == null) {
      print('❌ Provider: No coordinates provided');
      state = state.copyWith(
        isLoadingNearby: false,
        error: 'Location not available. Please enable location services.',
        searchMessage: 'Unable to get your location',
      );
      return;
    }

    state = state.copyWith(
      isLoadingNearby: true,
      isSearchingWider: false,
      error: null,
      currentPage: 0,
      searchMessage: 'Finding artisans near you...',
    );

    bool foundArtisans = false;
    
    // Try each radius until we find artisans
    for (int i = 0; i < searchRadiuses.length; i++) {
      final radius = searchRadiuses[i];
      
      print('🔍 Provider: Searching radius ${radius}km (attempt ${i + 1}/${searchRadiuses.length})');
      
      // Update message for expanding search
      if (i > 0) {
        state = state.copyWith(
          isSearchingWider: true,
          searchMessage: 'Expanding search to ${radius.toInt()}km...',
        );
      }

      final result = await repository.getNearbyArtisans(
        latitude: latitude,
        longitude: longitude,
        category: category,
        radiusKm: radius,
        limit: 20,
        offset: 0,
      );

      final success = result.fold(
        (failure) {
          print('❌ Provider: Search at ${radius}km failed - ${failure.message}');
          return false;
        },
        (artisans) {
          if (artisans.isNotEmpty) {
            // Found artisans!
            final radiusMessage = i == 0 
                ? 'Found ${artisans.length} artisans nearby'
                : 'Found ${artisans.length} artisans within ${radius.toInt()}km';

            print('✅ Provider: $radiusMessage');
            
            state = state.copyWith(
              nearbyArtisans: artisans,
              isLoadingNearby: false,
              isSearchingWider: false,
              currentPage: 1,
              hasMore: artisans.length >= 20,
              currentSearchRadius: radius,
              searchMessage: radiusMessage,
              error: null,
            );
            foundArtisans = true;
            return true;
          }
          print('⚠ Provider: No artisans at ${radius}km, trying wider...');
          return false;
        },
      );

      if (success) break;
    }

    // If still no artisans found after all radiuses, get ALL artisans regardless of distance
    if (!foundArtisans) {
      print('🌐 Provider: Searching nationwide (unlimited radius)...');
      
      final result = await repository.getNearbyArtisans(
        latitude: latitude,
        longitude: longitude,
        category: category,
        radiusKm: 50000, // 50,000km - effectively unlimited
        limit: 20,
        offset: 0,
      );

      result.fold(
        (failure) {
          print('❌ Provider: Nationwide search failed - ${failure.message}');
          state = state.copyWith(
            nearbyArtisans: [],
            isLoadingNearby: false,
            isSearchingWider: false,
            searchMessage: 'Unable to load artisans',
            error: failure.message,
          );
        },
        (artisans) {
          if (artisans.isNotEmpty) {
            print('✅ Provider: Found ${artisans.length} artisans nationwide');
            state = state.copyWith(
              nearbyArtisans: artisans,
              isLoadingNearby: false,
              isSearchingWider: false,
              currentPage: 1,
              hasMore: artisans.length >= 20,
              currentSearchRadius: 50000,
              searchMessage: 'Showing ${artisans.length} artisans nationwide',
              error: null,
            );
          } else {
            print('❌ Provider: No artisans found anywhere');
            state = state.copyWith(
              nearbyArtisans: [],
              isLoadingNearby: false,
              isSearchingWider: false,
              searchMessage: 'No artisans available',
              error: null,
            );
          }
        },
      );
    }
  }

  Future<void> loadNationwideArtisans({
    required double latitude,
    required double longitude,
    String? category,
  }) async {
    state = state.copyWith(
      isLoadingNearby: true,
      isSearchingWider: false,
      error: null,
      currentPage: 0,
      searchMessage: 'Loading artisans nationwide...',
    );

    final result = await repository.getNearbyArtisans(
      latitude: latitude,
      longitude: longitude,
      category: category,
      radiusKm: 50000,
      limit: 20,
      offset: 0,
    );

    result.fold(
      (failure) {
        state = state.copyWith(
          nearbyArtisans: [],
          isLoadingNearby: false,
          currentPage: 0,
          hasMore: false,
          currentSearchRadius: 50000,
          searchMessage: 'Unable to load artisans nationwide',
          error: failure.message,
        );
      },
      (artisans) {
        state = state.copyWith(
          nearbyArtisans: artisans,
          isLoadingNearby: false,
          currentPage: 1,
          hasMore: artisans.length >= 20,
          currentSearchRadius: 50000,
          searchMessage: 'Showing ${artisans.length} artisans nationwide',
          error: null,
        );
      },
    );
  }

  Future<void> resetNearbySearch({
    required double latitude,
    required double longitude,
    String? category,
  }) async {
    await _loadNearbyAtRadius(
      latitude: latitude,
      longitude: longitude,
      category: category,
      radiusKm: searchRadiuses.first,
      loadingMessage: 'Searching nearby artisans...',
      resultMessageBuilder: (count, radiusKm) =>
          count == 0 ? 'No artisans nearby yet' : 'Found $count artisans nearby',
    );
  }

  Future<void> expandNearbySearch({
    required double latitude,
    required double longitude,
    String? category,
  }) async {
    final current = state.currentSearchRadius ?? searchRadiuses.first;
    double nextRadius = 50000;

    for (final radius in searchRadiuses) {
      if (radius > current) {
        nextRadius = radius;
        break;
      }
    }

    await _loadNearbyAtRadius(
      latitude: latitude,
      longitude: longitude,
      category: category,
      radiusKm: nextRadius,
      loadingMessage: nextRadius >= 50000
          ? 'Searching nationwide...'
          : 'Expanding search to ${nextRadius.toInt()}km...',
      resultMessageBuilder: (count, radiusKm) => radiusKm >= 50000
          ? 'Showing $count artisans nationwide'
          : (count == 0
              ? 'No artisans within ${radiusKm.toInt()}km yet'
              : 'Found $count artisans within ${radiusKm.toInt()}km'),
    );
  }

  Future<void> _loadNearbyAtRadius({
    required double latitude,
    required double longitude,
    required double radiusKm,
    required String loadingMessage,
    required String Function(int count, double radiusKm) resultMessageBuilder,
    String? category,
  }) async {
    state = state.copyWith(
      isLoadingNearby: true,
      isSearchingWider: radiusKm > searchRadiuses.first,
      error: null,
      currentPage: 0,
      searchMessage: loadingMessage,
    );

    final result = await repository.getNearbyArtisans(
      latitude: latitude,
      longitude: longitude,
      category: category,
      radiusKm: radiusKm,
      limit: 20,
      offset: 0,
    );

    result.fold(
      (failure) {
        state = state.copyWith(
          nearbyArtisans: [],
          isLoadingNearby: false,
          isSearchingWider: false,
          hasMore: false,
          currentSearchRadius: radiusKm,
          searchMessage: 'Unable to load artisans',
          error: failure.message,
        );
      },
      (artisans) {
        state = state.copyWith(
          nearbyArtisans: artisans,
          isLoadingNearby: false,
          isSearchingWider: false,
          currentPage: 1,
          hasMore: artisans.length >= 20,
          currentSearchRadius: radiusKm,
          searchMessage: resultMessageBuilder(artisans.length, radiusKm),
          error: null,
        );
      },
    );
  }
  
  Future<void> loadMoreArtisans({
    double? latitude,
    double? longitude,
    String? category,
  }) async {
    if (state.isLoadingMore || !state.hasMore) return;
    if (latitude == null || longitude == null) return;
    if (state.currentSearchRadius == null) return;

    state = state.copyWith(isLoadingMore: true);

    final result = await repository.getNearbyArtisans(
      latitude: latitude,
      longitude: longitude,
      category: category,
      radiusKm: state.currentSearchRadius!,
      limit: 20,
      offset: state.currentPage * 20,
    );

    result.fold(
      (failure) {
        state = state.copyWith(
          isLoadingMore: false,
          error: failure.message,
        );
      },
      (artisans) {
        final updatedList = [...state.nearbyArtisans, ...artisans];
        state = state.copyWith(
          nearbyArtisans: updatedList,
          isLoadingMore: false,
          currentPage: state.currentPage + 1,
          hasMore: artisans.length >= 20,
          searchMessage: 'Loaded ${updatedList.length} artisans',
        );
      },
    );
  }

  Future<void> refresh({
    double? latitude,
    double? longitude,
    String? category,
    bool nationwide = false,
  }) async {
    await Future.wait([
      loadFeaturedArtisans(
        latitude: latitude,
        longitude: longitude,
        nationwide: nationwide,
        forceRefresh: true,
      ),
      loadNearbyArtisans(
        latitude: latitude,
        longitude: longitude,
        category: category,
      ),
    ]);
  }

  Future<void> searchArtisans({
    String? query,
    String? category,
    double? minRating,
  }) async {
    state = state.copyWith(
      isLoadingNearby: true,
      error: null,
      searchMessage: 'Searching artisans...',
    );

    final result = await repository.searchArtisans(
      query: query ?? '',
      category: category,
      minRating: minRating,
      limit: 20,
    );

    result.fold(
      (failure) {
        state = state.copyWith(
          isLoadingNearby: false,
          error: failure.message,
          searchMessage: 'Search failed',
        );
      },
      (artisans) {
        final message = artisans.isEmpty
            ? 'No artisans found'
            : 'Found ${artisans.length} artisans';

        state = state.copyWith(
          nearbyArtisans: artisans,
          isLoadingNearby: false,
          searchMessage: message,
          error: null,
        );
      },
    );
  }

  void clearSearch() {
    state = state.copyWith(
      nearbyArtisans: [],
      searchMessage: null,
      currentSearchRadius: null,
    );
  }
}

// Provider
final artisanProvider = StateNotifierProvider<ArtisanNotifier, ArtisanState>(
  (ref) {
    final repository = ref.watch(artisanRepositoryProvider);
    return ArtisanNotifier(repository);
  },
);
