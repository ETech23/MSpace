// lib/features/search/data/datasources/search_remote_datasource.dart

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/error/exceptions.dart';
import '../../../home/domain/entities/artisan_entity.dart';
import '../../presentation/providers/search_provider.dart';
import 'dart:math';

abstract class SearchRemoteDataSource {
  Future<List<ArtisanEntity>> fuzzySearchArtisans({
    required String query,
    String? category,
    String? city,
    double? minRating,
    double? maxDistance,
    double? userLat,
    double? userLng,
    required int limit,
    required int offset,
  });

  Future<List<SearchSuggestion>> getSearchSuggestions(String query);
  
  Future<String> logSearchAnalytics({
    required String query,
    required Map<String, dynamic> filters,
    required int resultsCount,
    required int durationMs,
  });

  Future<void> logSearchClick(String searchId, String artisanId);
  
  Future<List<String>> getPopularSearches();
}

class SearchRemoteDataSourceImpl implements SearchRemoteDataSource {
  final SupabaseClient _supabase;

  SearchRemoteDataSourceImpl(this._supabase);

  @override
  Future<List<ArtisanEntity>> fuzzySearchArtisans({
    required String query,
    String? category,
    String? city,
    double? minRating,
    double? maxDistance,
    double? userLat,
    double? userLng,
    required int limit,
    required int offset,
  }) async {
    try {
      debugPrint('🔍 Search: Starting search for "$query"');
      
      // Use direct query search (no RPC needed)
      return await _directSearch(
        query: query,
        category: category,
        city: city,
        minRating: minRating,
        maxDistance: maxDistance,
        userLat: userLat,
        userLng: userLng,
        limit: limit,
        offset: offset,
      );
    } catch (e) {
      debugPrint('❌ Search failed: $e');
      throw ServerException(message: 'Search failed: $e');
    }
  }

  /// Direct search using ILIKE queries - matches YOUR database schema
  Future<List<ArtisanEntity>> _directSearch({
    required String query,
    String? category,
    String? city,
    double? minRating,
    double? maxDistance,
    double? userLat,
    double? userLng,
    required int limit,
    required int offset,
  }) async {
    try {
      debugPrint('🔍 Direct search for: "$query"');

      // Fetch artisan profiles
      final artisanResponse = await _supabase
          .from('artisan_profiles')
          .select('*')
          .order('rating', ascending: false);

      debugPrint('📊 Got ${(artisanResponse as List).length} artisan profiles');

      // Fetch business profiles
      final businessResponse = await _supabase
          .from('business_profiles')
          .select('*')
          .order('updated_at', ascending: false);

      debugPrint('📊 Got ${(businessResponse as List).length} business profiles');

      if (artisanResponse.isEmpty && businessResponse.isEmpty) return [];

      // Get all user IDs from both sources
      final allUserIds = <String>{};
      for (final p in (artisanResponse as List)) {
        final uid = p['user_id'] as String?;
        if (uid != null) allUserIds.add(uid);
      }
      for (final p in (businessResponse as List)) {
        final uid = p['user_id'] as String?;
        if (uid != null) allUserIds.add(uid);
      }

      final visibleUserIds = await _getVisibleUserIds(allUserIds.toList());
      if (visibleUserIds.isEmpty) {
        return [];
      }

      // Fetch user details
      Map<String, Map<String, dynamic>> usersMap = {};
      if (visibleUserIds.isNotEmpty) {
        final usersResponse = await _supabase
            .from('users')
            .select('*')
            .inFilter('id', visibleUserIds.toList());

        for (final user in (usersResponse as List)) {
          usersMap[user['id'] as String] = user;
        }
        debugPrint('📊 Got ${usersMap.length} user records');
      }

      // Fetch all reviews for rating calculations
      Map<String, List<Map<String, dynamic>>> reviewsMap = {};
      try {
        final reviewsResponse = await _supabase
            .from('reviews')
            .select('artisan_id, rating')
            .inFilter('artisan_id', visibleUserIds.toList());

        for (final review in (reviewsResponse as List)) {
          final artisanId = review['artisan_id'] as String?;
          if (artisanId != null) {
            reviewsMap.putIfAbsent(artisanId, () => []);
            reviewsMap[artisanId]!.add(review);
          }
        }
        debugPrint('📊 Got reviews for ${reviewsMap.length} artisans/businesses');
      } catch (e) {
        debugPrint('⚠️ Could not fetch reviews: $e');
      }

      // Filter and parse results
      final queryLower = query.toLowerCase().trim();
      final List<ArtisanEntity> results = [];

      // Process artisan profiles
      for (final profile in (artisanResponse as List)) {
        final userId = profile['user_id'] as String?;
        if (userId == null || !visibleUserIds.contains(userId)) {
          continue;
        }
        final user = usersMap[userId];
        final moderationStatus =
            (user?['moderation_status'] as String?) ?? 'active';
        if (moderationStatus != 'active') {
          continue;
        }

        // Get searchable fields from profile
        final name = (user?['name'] as String? ?? '').toLowerCase();
        final categoryStr = (profile['category'] as String? ?? '').toLowerCase();
        final bio = (profile['bio'] as String? ?? '').toLowerCase();
        final address = (profile['address'] as String? ?? 
                        user?['address'] as String? ?? '').toLowerCase();
        final skills = profile['skills'] as List? ?? [];
        final skillsStr = skills.map((s) => s.toString().toLowerCase()).join(' ');

        // Check if query matches any field
        bool matches = false;
        String matchType = 'none';

        if (name.contains(queryLower) || _fuzzyMatch(queryLower, name)) {
          matches = true;
          matchType = 'name_match';
        } else if (categoryStr.contains(queryLower) || _fuzzyMatch(queryLower, categoryStr)) {
          matches = true;
          matchType = 'category_match';
        } else if (address.contains(queryLower)) {
          matches = true;
          matchType = 'location_match';
        } else if (skillsStr.contains(queryLower)) {
          matches = true;
          matchType = 'skill_match';
        } else if (bio.contains(queryLower)) {
          matches = true;
          matchType = 'bio_match';
        }

        // Apply category filter
        if (category != null && category.isNotEmpty) {
          if (!categoryStr.contains(category.toLowerCase())) {
            continue;
          }
        }

        // Calculate rating from reviews
        double rating = 0.0;
        int reviewCount = 0;
        if (reviewsMap.containsKey(userId)) {
          final reviews = reviewsMap[userId]!;
          reviewCount = reviews.length;
          if (reviewCount > 0) {
            rating = reviews
                .map((r) => (r['rating'] as num?)?.toDouble() ?? 0.0)
                .reduce((a, b) => a + b) / reviewCount;
          }
        }

        // Apply rating filter
        if (minRating != null && rating < minRating) {
          continue;
        }
        final isAvailable = (profile['is_available'] as bool?) ?? true;
        if (!isAvailable) {
          continue;
        }

        if (!matches) continue;

        // Calculate distance if coordinates available
        double? distance;
        final lat = (profile['latitude'] as num?)?.toDouble() ?? 
                   (user?['latitude'] as num?)?.toDouble();
        final lng = (profile['longitude'] as num?)?.toDouble() ?? 
                   (user?['longitude'] as num?)?.toDouble();

        if (userLat != null && userLng != null && lat != null && lng != null) {
          distance = _calculateDistance(userLat, userLng, lat, lng);
          
          // Apply distance filter
          if (maxDistance != null && distance > maxDistance) {
            continue;
          }
        }

        // Parse to entity
        results.add(ArtisanEntity(
          id: profile['id'] as String,
          userId: userId ?? '',
          name: user?['name'] as String? ?? 'Unknown Artisan',
          email: user?['email'] as String? ?? '',
          phoneNumber: user?['phone'] as String?,
          photoUrl: profile['photo_url'] as String? ?? user?['photo_url'] as String?,
          category: profile['category'] as String? ?? 'General',
          bio: profile['bio'] as String?,
          address: profile['address'] as String? ?? user?['address'] as String?,
          latitude: lat,
          longitude: lng,
          rating: rating,
          reviewCount: reviewCount,
          isVerified: profile['is_verified'] as bool? ?? false,
          premium: profile['premium'] as bool? ?? false,
          isFeatured: profile['is_featured'] as bool? ?? false,
          isAvailable: profile['is_available'] as bool? ?? true,
          distance: distance,
          skills: skills.isNotEmpty 
              ? skills.map((s) => s.toString()).toList() 
              : null,
          completedJobs: profile['completed_jobs'] as int? ?? 0,
          certifications: (profile['certifications'] as List?)
              ?.map((c) => c.toString()).toList(),
          hourlyRate: (profile['hourly_rate'] as num?)?.toDouble(),
          experienceYears: profile['experience_years']?.toString(),
          matchType: matchType,
          relevanceScore: _calculateRelevance(queryLower, name, categoryStr, skillsStr),
          createdAt: profile['created_at'] != null 
              ? DateTime.parse(profile['created_at']) 
              : DateTime.now(),
          updatedAt: profile['updated_at'] != null 
              ? DateTime.parse(profile['updated_at']) 
              : null,
        ));
      }

      // Process business profiles
      for (final profile in (businessResponse as List)) {
        final userId = profile['user_id'] as String?;
        if (userId == null || !visibleUserIds.contains(userId)) {
          continue;
        }
        final user = usersMap[userId];
        if (user == null) continue;
        
        final moderationStatus = (user['moderation_status'] as String?) ?? 'active';
        if (moderationStatus != 'active') {
          continue;
        }

        // Get searchable fields
        final businessName = (profile['business_name'] as String? ?? '').toLowerCase();
        final serviceCategories = profile['service_categories'] as List? ?? [];
        final serviceCategoriesStr = serviceCategories.map((s) => s.toString().toLowerCase()).join(' ');
        final description = (profile['description'] as String? ?? '').toLowerCase();
        final coverageArea = (profile['coverage_area'] as String? ?? '').toLowerCase();
        final address = (user['address'] as String? ?? '').toLowerCase();

        // Check if query matches any field
        bool matches = false;
        String matchType = 'none';

        if (businessName.contains(queryLower) || _fuzzyMatch(queryLower, businessName)) {
          matches = true;
          matchType = 'business_name_match';
        } else if (serviceCategoriesStr.contains(queryLower)) {
          matches = true;
          matchType = 'service_category_match';
        } else if (description.contains(queryLower)) {
          matches = true;
          matchType = 'description_match';
        } else if (address.contains(queryLower)) {
          matches = true;
          matchType = 'location_match';
        } else if (coverageArea.contains(queryLower)) {
          matches = true;
          matchType = 'coverage_match';
        }

        // Apply category filter
        if (category != null && category.isNotEmpty) {
          if (!serviceCategoriesStr.contains(category.toLowerCase())) {
            continue;
          }
        }

        // Calculate rating from reviews
        double rating = 0.0;
        int reviewCount = 0;
        if (reviewsMap.containsKey(userId)) {
          final reviews = reviewsMap[userId]!;
          reviewCount = reviews.length;
          if (reviewCount > 0) {
            rating = reviews
                .map((r) => (r['rating'] as num?)?.toDouble() ?? 0.0)
                .reduce((a, b) => a + b) / reviewCount;
          }
        }

        // Apply rating filter
        if (minRating != null && rating < minRating) {
          continue;
        }

        if (!matches) continue;

        // Calculate distance if coordinates available
        double? distance;
        final lat = (user['latitude'] as num?)?.toDouble();
        final lng = (user['longitude'] as num?)?.toDouble();

        if (userLat != null && userLng != null && lat != null && lng != null) {
          distance = _calculateDistance(userLat, userLng, lat, lng);
          
          if (maxDistance != null && distance > maxDistance) {
            continue;
          }
        }

        // Create synthetic ID from userId for business since business_profiles has no id column
        final syntheticId = 'biz_${userId}';

        // Parse to entity
        results.add(ArtisanEntity(
          id: syntheticId,
          userId: userId,
          name: businessName.isNotEmpty ? businessName : (user['name'] as String? ?? 'Unknown Business'),
          email: user['email'] as String? ?? '',
          phoneNumber: profile['contact_phone'] as String? ?? user['phone'] as String?,
          photoUrl: profile['logo_url'] as String? ?? user['photo_url'] as String?,
          category: serviceCategories.isNotEmpty ? serviceCategories.first.toString() : 'Business',
          bio: description.isNotEmpty ? description : null,
          address: address,
          latitude: lat,
          longitude: lng,
          rating: rating,
          reviewCount: reviewCount,
          isVerified: false,
          premium: false,
          isFeatured: false,
          isAvailable: true,
          distance: distance,
          skills: serviceCategories.isNotEmpty 
              ? serviceCategories.map((s) => s.toString()).toList() 
              : null,
          completedJobs: 0,
          certifications: null,
          hourlyRate: null,
          experienceYears: null,
          matchType: matchType,
          relevanceScore: _calculateRelevance(queryLower, businessName, serviceCategoriesStr, description),
          createdAt: profile['created_at'] != null 
              ? DateTime.parse(profile['created_at']) 
              : DateTime.now(),
          updatedAt: profile['updated_at'] != null 
              ? DateTime.parse(profile['updated_at']) 
              : null,
        ));
      }

      // Sort by relevance score
      results.sort((a, b) {
        final scoreA = a.relevanceScore ?? 0;
        final scoreB = b.relevanceScore ?? 0;
        return scoreB.compareTo(scoreA);
      });

      debugPrint('✅ Search found ${results.length} matching results (artisans & businesses)');
      return results.take(limit).toList();

    } on PostgrestException catch (e) {
      debugPrint('❌ Database error: ${e.message}');
      throw ServerException(message: 'Search failed: ${e.message}');
    } catch (e) {
      debugPrint('❌ Search error: $e');
      throw ServerException(message: 'Search failed: $e');
    }
  }

  /// Simple fuzzy matching for typo tolerance
  bool _fuzzyMatch(String query, String target) {
    if (query.isEmpty || target.isEmpty) return false;
    if (query.length < 2) return target.startsWith(query);
    
    // Check Levenshtein-like similarity
    // If 70%+ of query characters are in target, consider it a match
    int matches = 0;
    for (int i = 0; i < query.length; i++) {
      if (target.contains(query[i])) matches++;
    }
    
    final similarity = matches / query.length;
    
    // Also check if target starts with query (partial match)
    if (target.startsWith(query.substring(0, min(3, query.length)))) {
      return true;
    }
    
    // Check for common typos (transposed letters, missing letters)
    if (query.length >= 3 && target.length >= 3) {
      // Check if first 3 chars match with one error
      int firstThreeMatches = 0;
      for (int i = 0; i < 3 && i < query.length && i < target.length; i++) {
        if (query[i] == target[i]) firstThreeMatches++;
      }
      if (firstThreeMatches >= 2) return true;
    }
    
    return similarity > 0.7;
  }

  /// Calculate relevance score for sorting
  double _calculateRelevance(String query, String name, String category, String skills) {
    double score = 0;
    
    // Exact match in category (highest priority for service search)
    if (category.contains(query)) score += 10;
    
    // Exact match in name
    if (name.contains(query)) score += 8;
    
    // Match in skills
    if (skills.contains(query)) score += 6;
    
    // Partial match (starts with)
    if (category.startsWith(query)) score += 5;
    if (name.startsWith(query)) score += 4;
    
    return score;
  }

  /// Calculate distance between two coordinates (Haversine formula)
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295; // Pi/180
    final a = 0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a)); // 2 * R; R = 6371 km
  }

  @override
  Future<List<SearchSuggestion>> getSearchSuggestions(String query) async {
    if (query.length < 2) return [];
    
    try {
      final suggestions = <SearchSuggestion>[];
      final queryLower = query.toLowerCase();

      // Get distinct categories that match
      final categoriesResponse = await _supabase
          .from('artisan_profiles')
          .select('category')
          .ilike('category', '%$query%')
          .limit(5);

      final seenCategories = <String>{};
      for (final item in (categoriesResponse as List)) {
        final cat = item['category'] as String?;
        if (cat != null && !seenCategories.contains(cat.toLowerCase())) {
          seenCategories.add(cat.toLowerCase());
          suggestions.add(SearchSuggestion(
            text: cat,
            type: 'category',
          ));
        }
      }

      // Get distinct addresses/cities that match
      final addressResponse = await _supabase
          .from('artisan_profiles')
          .select('address')
          .ilike('address', '%$query%')
          .limit(3);

      for (final item in (addressResponse as List)) {
        final addr = item['address'] as String?;
        if (addr != null && addr.isNotEmpty) {
          // Extract city from address (simple heuristic)
          final parts = addr.split(',');
          if (parts.isNotEmpty) {
            final city = parts.last.trim();
            if (city.toLowerCase().contains(queryLower)) {
              suggestions.add(SearchSuggestion(
                text: city,
                type: 'city',
              ));
            }
          }
        }
      }

      return suggestions.take(8).toList();
    } catch (e) {
      debugPrint('Suggestions error: $e');
      return [];
    }
  }

  @override
  Future<String> logSearchAnalytics({
    required String query,
    required Map<String, dynamic> filters,
    required int resultsCount,
    required int durationMs,
  }) async {
    // Skip analytics for now - table may not exist
    return '';
  }

  @override
  Future<void> logSearchClick(String searchId, String artisanId) async {
    // Skip for now
  }

  @override
  Future<List<String>> getPopularSearches() async {
    return [
      'Plumber',
      'Electrician',
      'Carpenter',
      'Painter',
      'Mechanic',
      'AC Repair',
      'Cleaner',
      'Barber',
    ];
  }

  Future<Set<String>> _getVisibleUserIds(Iterable<String> userIds) async {
    final ids = userIds.where((id) => id.isNotEmpty).toSet().toList();
    if (ids.isEmpty) {
      return <String>{};
    }

    try {
      final response = await _supabase
          .from('user_settings')
          .select('user_id, profile_visible')
          .inFilter('user_id', ids);

      final hiddenIds = (response as List)
          .where((row) => row['profile_visible'] == false)
          .map((row) => row['user_id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toSet();

      return ids.where((id) => !hiddenIds.contains(id)).toSet();
    } catch (_) {
      return ids.toSet();
    }
  }
}
