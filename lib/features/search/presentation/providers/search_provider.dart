// lib/features/search/presentation/providers/search_provider.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../home/domain/entities/artisan_entity.dart';
import '../../data/datasources/search_remote_datasource.dart';

// Search filters model
class SearchFilters {
  final String? category;
  final String? city;
  final double? minRating;
  final double? maxDistance;
  final double? minPrice;
  final double? maxPrice;
  final bool? isAvailable;

  const SearchFilters({
    this.category,
    this.city,
    this.minRating,
    this.maxDistance,
    this.minPrice,
    this.maxPrice,
    this.isAvailable,
  });

  SearchFilters copyWith({
    String? category,
    String? city,
    double? minRating,
    double? maxDistance,
    double? minPrice,
    double? maxPrice,
    bool? isAvailable,
    bool clearCategory = false,
    bool clearCity = false,
    bool clearRating = false,
    bool clearDistance = false,
    bool clearPrice = false,
  }) {
    return SearchFilters(
      category: clearCategory ? null : (category ?? this.category),
      city: clearCity ? null : (city ?? this.city),
      minRating: clearRating ? null : (minRating ?? this.minRating),
      maxDistance: clearDistance ? null : (maxDistance ?? this.maxDistance),
      minPrice: clearPrice ? null : (minPrice ?? this.minPrice),
      maxPrice: clearPrice ? null : (maxPrice ?? this.maxPrice),
      isAvailable: isAvailable ?? this.isAvailable,
    );
  }

  bool get hasActiveFilters =>
      category != null ||
      city != null ||
      minRating != null ||
      maxDistance != null ||
      minPrice != null ||
      maxPrice != null ||
      isAvailable == true;

  int get activeFilterCount {
    int count = 0;
    if (category != null) count++;
    if (city != null) count++;
    if (minRating != null) count++;
    if (maxDistance != null) count++;
    if (minPrice != null || maxPrice != null) count++;
    if (isAvailable == true) count++;
    return count;
  }

  Map<String, dynamic> toJson() => {
    if (category != null) 'category': category,
    if (city != null) 'city': city,
    if (minRating != null) 'minRating': minRating,
    if (maxDistance != null) 'maxDistance': maxDistance,
    if (minPrice != null) 'minPrice': minPrice,
    if (maxPrice != null) 'maxPrice': maxPrice,
    if (isAvailable != null) 'isAvailable': isAvailable,
  };

  SearchFilters clear() => const SearchFilters();
}

// Search suggestion model
class SearchSuggestion {
  final String text;
  final String type;
  final int? count;

  const SearchSuggestion({
    required this.text,
    required this.type,
    this.count,
  });
}

// Search state
class SearchState {
  final List<ArtisanEntity> results;
  final List<String> recentSearches;
  final List<SearchSuggestion> suggestions;
  final List<String> popularSearches;
  final SearchFilters filters;
  final bool isLoading;
  final bool isLoadingSuggestions;
  final bool isSearching;
  final bool isListening;
  final String? error;
  final String query;
  final int totalResults;
  final int searchDurationMs;
  final List<String> availableCategories;

  const SearchState({
    this.results = const [],
    this.recentSearches = const [],
    this.suggestions = const [],
    this.popularSearches = const [],
    this.filters = const SearchFilters(),
    this.isLoading = false,
    this.isLoadingSuggestions = false,
    this.isSearching = false,
    this.isListening = false,
    this.error,
    this.query = '',
    this.totalResults = 0,
    this.searchDurationMs = 0,
    this.availableCategories = const [
      'Plumber', 'Electrician', 'Carpenter', 'Painter', 'Mechanic',
      'Tailor', 'Barber', 'Mason', 'Welder', 'AC Repair', 'Cleaner',
    ],
  });

  SearchState copyWith({
    List<ArtisanEntity>? results,
    List<String>? recentSearches,
    List<SearchSuggestion>? suggestions,
    List<String>? popularSearches,
    SearchFilters? filters,
    bool? isLoading,
    bool? isLoadingSuggestions,
    bool? isSearching,
    bool? isListening,
    String? error,
    String? query,
    int? totalResults,
    int? searchDurationMs,
    List<String>? availableCategories,
    bool clearError = false,
  }) {
    return SearchState(
      results: results ?? this.results,
      recentSearches: recentSearches ?? this.recentSearches,
      suggestions: suggestions ?? this.suggestions,
      popularSearches: popularSearches ?? this.popularSearches,
      filters: filters ?? this.filters,
      isLoading: isLoading ?? this.isLoading,
      isLoadingSuggestions: isLoadingSuggestions ?? this.isLoadingSuggestions,
      isSearching: isSearching ?? this.isSearching,
      isListening: isListening ?? this.isListening,
      error: clearError ? null : error,
      query: query ?? this.query,
      totalResults: totalResults ?? this.totalResults,
      searchDurationMs: searchDurationMs ?? this.searchDurationMs,
      availableCategories: availableCategories ?? this.availableCategories,
    );
  }
}

// Search notifier
class SearchNotifier extends StateNotifier<SearchState> {
  final SearchRemoteDataSource _dataSource;
  
  Timer? _debounceTimer;
  Timer? _suggestionTimer;
  
  static const _recentSearchesKey = 'recent_searches_v2';
  static const _maxRecentSearches = 15;
  static const _searchDebounce = Duration(milliseconds: 400);

  double? userLatitude;
  double? userLongitude;

  SearchNotifier(this._dataSource) : super(const SearchState()) {
    _loadRecentSearches();
    _loadPopularSearches();
  }

  void setUserLocation(double lat, double lng) {
    userLatitude = lat;
    userLongitude = lng;
  }

  Future<void> _loadRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final searches = prefs.getStringList(_recentSearchesKey) ?? [];
      state = state.copyWith(recentSearches: searches);
    } catch (_) {}
  }

  Future<void> _loadPopularSearches() async {
    try {
      final popular = await _dataSource.getPopularSearches();
      state = state.copyWith(popularSearches: popular);
    } catch (_) {}
  }

  Future<void> _saveRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_recentSearchesKey, state.recentSearches);
    } catch (_) {}
  }

  void _addToRecentSearches(String query) {
    if (query.trim().isEmpty) return;
    final updated = [query.trim()];
    for (final search in state.recentSearches) {
      if (search.toLowerCase() != query.toLowerCase() &&
          updated.length < _maxRecentSearches) {
        updated.add(search);
      }
    }
    state = state.copyWith(recentSearches: updated);
    _saveRecentSearches();
  }

  void removeFromRecentSearches(String query) {
    final updated = state.recentSearches
        .where((s) => s.toLowerCase() != query.toLowerCase())
        .toList();
    state = state.copyWith(recentSearches: updated);
    _saveRecentSearches();
  }

  void clearRecentSearches() {
    state = state.copyWith(recentSearches: []);
    _saveRecentSearches();
  }

  void updateQuery(String query) {
    state = state.copyWith(
      query: query,
      isSearching: query.isNotEmpty,
      clearError: true,
    );

    _debounceTimer?.cancel();
    _suggestionTimer?.cancel();

    if (query.trim().isEmpty) {
      state = state.copyWith(
        results: [],
        suggestions: [],
        isLoading: false,
        isSearching: false,
        totalResults: 0,
      );
      return;
    }

    state = state.copyWith(isLoading: true);

    _debounceTimer = Timer(_searchDebounce, () {
      _performSearch(query);
    });

    _suggestionTimer = Timer(const Duration(milliseconds: 200), () {
      _loadSuggestions(query);
    });
  }

  Future<void> _loadSuggestions(String query) async {
    if (query.length < 2) return;
    try {
      final suggestions = await _dataSource.getSearchSuggestions(query);
      final matchingRecent = state.recentSearches
          .where((s) => s.toLowerCase().contains(query.toLowerCase()))
          .take(3)
          .map((s) => SearchSuggestion(text: s, type: 'recent'));
      state = state.copyWith(
        suggestions: [...matchingRecent, ...suggestions].take(8).toList(),
      );
    } catch (_) {}
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) return;

    debugPrint('🔍 Provider: Searching for "$query"');
    final stopwatch = Stopwatch()..start();

    try {
      final results = await _dataSource.fuzzySearchArtisans(
        query: query,
        category: state.filters.category,
        city: state.filters.city,
        minRating: state.filters.minRating,
        maxDistance: state.filters.maxDistance,
        userLat: userLatitude,
        userLng: userLongitude,
        limit: 30,
        offset: 0,
      );

      stopwatch.stop();
      debugPrint('✅ Provider: Got ${results.length} results');

      // CRITICAL: Update state with new results
      state = state.copyWith(
        results: List<ArtisanEntity>.from(results), // Create new list
        isLoading: false,
        totalResults: results.length,
        searchDurationMs: stopwatch.elapsedMilliseconds,
        error: null,
      );

      debugPrint('📊 Provider: State now has ${state.results.length} results');

    } catch (e) {
      debugPrint('❌ Provider: Search error - $e');
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
        results: [],
        totalResults: 0,
      );
    }
  }

  void submitSearch(String query) {
    if (query.trim().isEmpty) return;
    debugPrint('📤 Submit search: "$query"');
    
    // UPDATE: Set the query state AND isSearching flag immediately
    state = state.copyWith(
      query: query,
      isSearching: true,
      isLoading: true,
      clearError: true,
    );
    
    _addToRecentSearches(query);
    _debounceTimer?.cancel();
    _performSearch(query);
  }

  void updateFilters(SearchFilters filters) {
    state = state.copyWith(filters: filters);
    if (state.query.isNotEmpty) {
      _performSearch(state.query);
    }
  }

  void clearFilters() {
    state = state.copyWith(filters: const SearchFilters());
    if (state.query.isNotEmpty) {
      _performSearch(state.query);
    }
  }

  void setListening(bool listening) {
    state = state.copyWith(isListening: listening);
  }

  void onVoiceResult(String text) {
    debugPrint('🎤 Voice result: "$text"');
    state = state.copyWith(
      query: text,
      isListening: false,
      isSearching: true,
    );
    submitSearch(text);
  }

  void clearSearch() {
    _debounceTimer?.cancel();
    _suggestionTimer?.cancel();
    state = state.copyWith(
      query: '',
      results: [],
      suggestions: [],
      isSearching: false,
      isLoading: false,
      totalResults: 0,
      clearError: true,
    );
  }

  Future<void> logResultClick(String artisanId) async {}

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _suggestionTimer?.cancel();
    super.dispose();
  }
}

// PROVIDER - Direct instantiation
final searchProvider = StateNotifierProvider<SearchNotifier, SearchState>((ref) {
  final dataSource = SearchRemoteDataSourceImpl(Supabase.instance.client);
  return SearchNotifier(dataSource);
});