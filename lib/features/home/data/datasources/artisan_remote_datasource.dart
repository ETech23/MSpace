import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/artisan_model.dart';
import '../../../../core/error/exceptions.dart';
import 'dart:math' show cos, sqrt, asin, sin;

abstract class ArtisanRemoteDataSource {
  Future<List<ArtisanModel>> getFeaturedArtisans({int limit = 10});
  
  Future<List<ArtisanModel>> getNearbyArtisans({
    required double latitude,
    required double longitude,
    String? category,
    required double radiusKm,
    int limit = 20,
    int offset = 0,
  });
  
  Future<List<ArtisanModel>> searchArtisans({
    String? query,
    String? category,
    double? minRating,
    int limit = 20,
  });
  
  Future<ArtisanModel> getArtisanById(String id);
}

class ArtisanRemoteDataSourceImpl implements ArtisanRemoteDataSource {
  final SupabaseClient supabaseClient;

  ArtisanRemoteDataSourceImpl({required this.supabaseClient});

  @override
  Future<List<ArtisanModel>> getFeaturedArtisans({int limit = 10}) async {
    try {
      print('🌟 Fetching featured artisans...');
      
      final artisansResponse = await supabaseClient
          .from('artisan_profiles')
          .select('*')
          .eq('premium', true)
          .order('rating', ascending: false)
          .limit(limit);

      print('📊 Got ${(artisansResponse as List).length} premium artisan profiles');

      if ((artisansResponse as List).isEmpty) {
        return [];
      }

      final userIds = (artisansResponse as List)
          .map((a) => (a as Map<String, dynamic>)['user_id'] as String)
          .toSet()
          .toList();

      final usersResponse = await supabaseClient.rpc(
        'get_users_with_location', 
        params: {'user_ids': userIds}
      );

      print('📊 Got ${(usersResponse as List).length} user records');

      final usersMap = Map<String, Map<String, dynamic>>.fromEntries(
        (usersResponse).map((u) {
          final userMap = u as Map<String, dynamic>;
          return MapEntry(userMap['id'] as String, userMap);
        })
      );

      final mergedData = (artisansResponse as List).map((artisan) {
        final artisanMap = artisan as Map<String, dynamic>;
        final userId = artisanMap['user_id'] as String;
        final user = usersMap[userId];
        
        return <String, dynamic>{
          ...artisanMap,
          'users': user,
        };
      }).toList();

      print('✅ Merged data for ${mergedData.length} artisans');

      return mergedData.map((json) => ArtisanModel.fromJson(json)).toList();
    } on PostgrestException catch (e) {
      print('❌ PostgrestException: ${e.message}');
      throw ServerException(message: e.message);
    } catch (e) {
      print('❌ Error: $e');
      throw ServerException(message: 'Failed to load featured artisans: $e');
    }
  }

  @override
  Future<List<ArtisanModel>> getNearbyArtisans({
    required double latitude,
    required double longitude,
    String? category,
    required double radiusKm,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      print('📍 Fetching nearby artisans...');
      print('   User location: ($latitude, $longitude)');
      print('   Radius: ${radiusKm}km, Limit: $limit, Offset: $offset');

      // ✅ Try database function first (much faster!)
      try {
        final response = await supabaseClient.rpc(
          'find_nearby_artisans',
          params: {
            'user_lat': latitude,
            'user_lng': longitude,
            'radius_km': radiusKm,
            'limit_count': limit,
            'offset_count': offset,
          },
        );

        print('📊 Database function returned: ${(response as List).length} artisans');

        final responseList = response as List;

        if (responseList.isEmpty) {
          print('⚠️ No artisans found within ${radiusKm}km');
          return [];
        }

        // Get user details for each artisan
        final userIds = (responseList)
            .map((item) => (item as Map<String, dynamic>)['user_id'] as String)
            .toSet()
            .toList();

        final usersResponse = await supabaseClient.rpc(
          'get_users_with_location',
          params: {'user_ids': userIds},
        );

        print('📊 Got ${(usersResponse as List).length} user records');

        // Create users map
        final usersMap = Map<String, Map<String, dynamic>>.fromEntries(
          (usersResponse).map((u) {
            final userMap = u as Map<String, dynamic>;
            return MapEntry(userMap['id'] as String, userMap);
          }),
        );

        // Debug first user
        if ((usersResponse).isNotEmpty) {
          final firstUser = (usersResponse).first as Map<String, dynamic>;
          print('🔍 Sample user location data:');
          print('   Name: ${firstUser['name']}');
          print('   Address: ${firstUser['address']}');
          print('   Latitude: ${firstUser['latitude']}');
          print('   Longitude: ${firstUser['longitude']}');
        }

        // Merge and parse
        final artisans = <ArtisanModel>[];
        
        for (var artisanData in responseList) {
          try {
            final artisanJson = artisanData as Map<String, dynamic>;
            final userId = artisanJson['user_id'] as String;
            final userJson = usersMap[userId];
            
            if (userJson == null) {
              print('⚠️ No user found for artisan user_id: $userId');
              continue;
            }

            final mergedJson = <String, dynamic>{
              ...artisanJson,
              'users': userJson,
            };

            artisans.add(ArtisanModel.fromJson(mergedJson));
          } catch (e) {
            print('⚠️ Error parsing artisan: $e');
            continue;
          }
        }

        final filteredArtisans = _filterByCategoryOrSkill(artisans, category);

        print('✅ Parsed ${artisans.length} artisans successfully');
        print('✅ Returning ${filteredArtisans.length} artisans within ${radiusKm}km');
        
        return filteredArtisans;

      } catch (dbFunctionError) {
        print('⚠️ Database function error: $dbFunctionError');
        print('⚠️ Falling back to client-side filtering...');
        
        // Fallback to client-side filtering
        return _getNearbyArtisansClientSide(
          latitude: latitude,
          longitude: longitude,
          category: category,
          radiusKm: radiusKm,
          limit: limit,
          offset: offset,
        );
      }
      
    } on PostgrestException catch (e) {
      print('❌ PostgrestException: ${e.message}');
      throw ServerException(message: e.message);
    } catch (e) {
      print('❌ Error: $e');
      throw ServerException(message: 'Failed to load nearby artisans: $e');
    }
  }

  // Client-side filtering fallback
  Future<List<ArtisanModel>> _getNearbyArtisansClientSide({
    required double latitude,
    required double longitude,
    String? category,
    required double radiusKm,
    int limit = 20,
    int offset = 0,
  }) async {
    print('📍 Using client-side distance calculation...');
    
    final artisansResponse = await supabaseClient
        .from('artisan_profiles')
        .select('*')
        .eq('availability_status', 'available')
        .order('rating', ascending: false);

    print('📊 Raw query returned: ${(artisansResponse as List).length} artisans');

    if ((artisansResponse as List).isEmpty) {
      print('⚠️ No artisans found in database');
      return [];
    }

    final userIds = (artisansResponse as List)
        .map((a) => (a as Map<String, dynamic>)['user_id'] as String)
        .toSet()
        .toList();

    final usersResponse = await supabaseClient.rpc(
      'get_users_with_location',
      params: {'user_ids': userIds},
    );

    print('📊 Got ${(usersResponse as List).length} user records');

    // Debug first user
    if ((usersResponse).isNotEmpty) {
      final firstUser = (usersResponse).first as Map<String, dynamic>;
      print('🔍 Sample user location data:');
      print('   Name: ${firstUser['name']}');
      print('   Address: ${firstUser['address']}');
      print('   Latitude: ${firstUser['latitude']}');
      print('   Longitude: ${firstUser['longitude']}');
    }

    final usersMap = Map<String, Map<String, dynamic>>.fromEntries(
      (usersResponse).map((u) {
        final userMap = u as Map<String, dynamic>;
        return MapEntry(userMap['id'] as String, userMap);
      }),
    );

    final List<ArtisanModel> allArtisans = [];
    
    for (var artisanData in (artisansResponse as List)) {
      try {
        final artisanJson = artisanData as Map<String, dynamic>;
        final userId = artisanJson['user_id'] as String;
        final userJson = usersMap[userId];
        
        if (userJson == null) {
          print('⚠️ No user found for artisan user_id: $userId');
          continue;
        }

        final mergedJson = <String, dynamic>{
          ...artisanJson,
          'users': userJson,
        };

        final artisan = ArtisanModel.fromJson(mergedJson);
        
        double distance;
        
        if (artisan.latitude != null && artisan.longitude != null) {
          distance = _calculateDistance(
            latitude,
            longitude,
            artisan.latitude!,
            artisan.longitude!,
          );
          print('📏 Distance to ${artisan.name}: ${distance.toStringAsFixed(2)}km');
        } else {
          distance = 9999.0;
          print('⚠️ No location for ${artisan.name}, setting distance to 9999km');
        }
        
        final artisanWithDistance = ArtisanModel(
          id: artisan.id,
          userId: artisan.userId,
          name: artisan.name,
          email: artisan.email,
          phoneNumber: artisan.phoneNumber,
          photoUrl: artisan.photoUrl,
          category: artisan.category,
          bio: artisan.bio,
          address: artisan.address,
          latitude: artisan.latitude,
          longitude: artisan.longitude,
          rating: artisan.rating,
          reviewCount: artisan.reviewCount,
          isVerified: artisan.isVerified,
          premium: artisan.premium,
          isFeatured: artisan.isFeatured,
          isAvailable: artisan.isAvailable,
          distance: distance,
          skills: artisan.skills,
          completedJobs: artisan.completedJobs,
          certifications: artisan.certifications,
          hourlyRate: artisan.hourlyRate,
          experienceYears: artisan.experienceYears,
          createdAt: artisan.createdAt,
          updatedAt: artisan.updatedAt,
        );
        
        allArtisans.add(artisanWithDistance);
      } catch (e) {
        print('⚠️ Error parsing artisan: $e');
        continue;
      }
    }

    print('✅ Parsed ${allArtisans.length} artisans successfully');

    final filteredByCategory = _filterByCategoryOrSkill(allArtisans, category);

    final artisansInRadius = filteredByCategory
        .where((artisan) => artisan.distance! <= radiusKm)
        .toList();

    print('📍 ${artisansInRadius.length} artisans within ${radiusKm}km');

    List<ArtisanModel> finalList;
    if (artisansInRadius.isEmpty && radiusKm >= 1000) {
      print('⚠️ No artisans in ${radiusKm}km radius, returning all sorted by distance');
      finalList = filteredByCategory;
    } else {
      finalList = artisansInRadius;
    }

    finalList.sort((a, b) => (a.distance ?? 9999).compareTo(b.distance ?? 9999));

    final start = offset;
    final end = (offset + limit).clamp(0, finalList.length);
    
    if (start >= finalList.length) {
      print('⚠️ Offset $start exceeds list length ${finalList.length}');
      return [];
    }

    final paginatedList = finalList.sublist(start, end);
    print('✅ Returning ${paginatedList.length} artisans');
    
    return paginatedList;
  }

  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371; // km
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    
    final c = 2 * asin(sqrt(a));
    return earthRadius * c;
  }

  double _toRadians(double degree) {
    return degree * (3.141592653589793 / 180);
  }

  List<ArtisanModel> _filterByCategoryOrSkill(
    List<ArtisanModel> artisans,
    String? query,
  ) {
    if (query == null) return artisans;
    final trimmed = query.trim();
    if (trimmed.length < 2) return artisans;

    final q = trimmed.toLowerCase();

    return artisans.where((artisan) {
      final categoryMatch = artisan.category.toLowerCase().contains(q);
      final skills = artisan.skills ?? const [];
      final skillMatch = skills.any(
        (skill) => skill.toLowerCase().contains(q),
      );
      return categoryMatch || skillMatch;
    }).toList();
  }

  @override
  Future<List<ArtisanModel>> searchArtisans({
    String? query,
    String? category,
    double? minRating,
    int limit = 20,
  }) async {
    try {
      print('🔍 Searching artisans: query=$query, category=$category, minRating=$minRating');
      
      var artisanQuery = supabaseClient.from('artisan_profiles').select('*');

      if (query != null && query.isNotEmpty) {
        artisanQuery = artisanQuery.or(
          'category.ilike.%$query%,bio.ilike.%$query%',
        );
      }

      if (category != null && category.isNotEmpty) {
        artisanQuery = artisanQuery.eq('category', category);
      }

      if (minRating != null) {
        artisanQuery = artisanQuery.gte('rating', minRating);
      }

      final artisansResponse = await artisanQuery
          .order('rating', ascending: false)
          .limit(limit);

      print('📊 Search returned: ${(artisansResponse as List).length} artisans');

      if ((artisansResponse as List).isEmpty) {
        return [];
      }

      final userIds = (artisansResponse as List)
          .map((a) => (a as Map<String, dynamic>)['user_id'] as String)
          .toSet()
          .toList();

      final usersResponse = await supabaseClient.rpc(
        'get_users_with_location', 
        params: {'user_ids': userIds}
      );

      final usersMap = Map<String, Map<String, dynamic>>.fromEntries(
        (usersResponse as List).map((u) {
          final userMap = u as Map<String, dynamic>;
          return MapEntry(userMap['id'] as String, userMap);
        })
      );

      final mergedData = (artisansResponse as List).map((artisan) {
        final artisanMap = artisan as Map<String, dynamic>;
        final userId = artisanMap['user_id'] as String;
        final user = usersMap[userId];
        
        return <String, dynamic>{
          ...artisanMap,
          'users': user,
        };
      }).toList();

      print('✅ Search found: ${mergedData.length} artisans');
      return mergedData.map((json) => ArtisanModel.fromJson(json)).toList();
    } on PostgrestException catch (e) {
      print('❌ Search error: ${e.message}');
      throw ServerException(message: e.message);
    } catch (e) {
      print('❌ Search error: $e');
      throw ServerException(message: 'Failed to search artisans: $e');
    }
  }

  @override
Future<ArtisanModel> getArtisanById(String id) async {
  try {
    print('👤 Fetching artisan by ID: $id');
    
    final artisanResponse = await supabaseClient
        .from('artisan_profiles')
        .select('*')
        .eq('user_id', id)
        .maybeSingle();

    if (artisanResponse == null) {
      throw const ServerException(message: 'Artisan profile not found');
    }

    final artisanMap = artisanResponse;
    final userId = artisanMap['user_id'] as String;

    final usersResponse = await supabaseClient.rpc(
      'get_users_with_location', 
      params: {'user_ids': [userId]}
    );

    final userMap = (usersResponse as List).first as Map<String, dynamic>;

    final mergedJson = <String, dynamic>{
      ...artisanMap,
      'users': userMap,
    };

    print('✅ Found artisan: ${userMap['name']}');
    return ArtisanModel.fromJson(mergedJson);
  } on PostgrestException catch (e) {
    print('❌ Get by ID error: ${e.message}');
    throw ServerException(message: e.message);
  } catch (e) {
    print('❌ Get by ID error: $e');
    throw ServerException(message: 'Failed to load artisan details: $e');
  }
}
}
