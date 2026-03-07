// lib/features/booking/data/datasources/booking_remote_datasource.dart
// FIXED: All notification inserts now include sub_type and related_id

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/error/exceptions.dart';
import '../models/booking_model.dart';

abstract class BookingRemoteDataSource {
  Future<BookingModel> createBooking({
    required String clientId,
    required String artisanId,
    required String artisanProfileId,
    required String serviceType,
    required String description,
    required DateTime scheduledDate,
    required String locationAddress,
    double? locationLatitude,
    double? locationLongitude,
    double? estimatedPrice,
    String? customerNotes,
  });

  Future<List<BookingModel>> getUserBookings({
    required String userId,
    required String userType,
    String? status,
    int limit = 20,
    int offset = 0,
  });

  Future<BookingModel> getBookingById(String bookingId);

  Future<void> updateBookingStatus({
    required String bookingId,
    required String newStatus,
    String? reason,
  });

  Future<void> cancelBooking({
    required String bookingId,
    required String cancelledBy,
    required String reason,
  });

  Future<void> acceptBooking(String bookingId);

  Future<void> rejectBooking({
    required String bookingId,
    required String reason,
  });

  Future<void> startBooking(String bookingId);

  Future<void> completeBooking(String bookingId);

  Future<Map<String, int>> getBookingStats({
    required String userId,
    required String userType,
  });
}

class BookingRemoteDataSourceImpl implements BookingRemoteDataSource {
  final SupabaseClient client;

  BookingRemoteDataSourceImpl({required this.client});

  
@override
Future<BookingModel> createBooking({
  required String clientId,
  required String artisanId,
  required String artisanProfileId,
  required String serviceType,
  required String description,
  required DateTime scheduledDate,
  required String locationAddress,
  double? locationLatitude,
  double? locationLongitude,
  double? estimatedPrice,
  String? customerNotes,
}) async {
  try {
    print('📝 Creating booking...');
    final userRows = await client
        .from('users')
        .select('id,moderation_status')
        .inFilter('id', [clientId, artisanId]);
    final statusByUser = <String, String>{};
    for (final row in (userRows as List)) {
      final map = row as Map<String, dynamic>;
      statusByUser[map['id'] as String] =
          (map['moderation_status'] as String?) ?? 'active';
    }

    final clientStatus = statusByUser[clientId] ?? 'active';
    if (clientStatus != 'active') {
      throw const ServerException(
        message: 'Your account is restricted from booking at this time.',
      );
    }

    final artisanStatus = statusByUser[artisanId] ?? 'active';
    if (artisanStatus != 'active') {
      throw const ServerException(
        message: 'This artisan is currently unavailable for bookings.',
      );
    }

    final artisanProfile = await client
        .from('artisan_profiles')
        .select('availability_status')
        .eq('id', artisanProfileId)
        .maybeSingle();
    if (artisanProfile == null) {
      throw const ServerException(message: 'Artisan profile not found.');
    }
    final availabilityStatus =
        (artisanProfile['availability_status'] as String?) ?? 'available';
    if (availabilityStatus != 'available') {
      throw const ServerException(
        message: 'This artisan is currently unavailable for bookings.',
      );
    }
    final bookingData = {
      'client_id': clientId,
      'artisan_id': artisanId,
      'artisan_profile_id': artisanProfileId,
      'service_type': serviceType,
      'description': description,
      'scheduled_date': scheduledDate.toIso8601String(),
      'location_address': locationAddress,
      'location_latitude': locationLatitude,
      'location_longitude': locationLongitude,
      'estimated_price': estimatedPrice,
      'customer_notes': customerNotes,
      'status': 'pending',
      'payment_status': 'unpaid',
    };

    final response = await client
        .from('bookings')
        .insert(bookingData)
        .select()
        .single();

    // ✅ REMOVED: Manual notification insert
    // The database trigger will handle it automatically

    print('✅ Booking created: ${response['id']}');
    return BookingModel.fromJson(response);
  } catch (e) {
    print('❌ Error creating booking: $e');
    throw ServerException(message: 'Failed to create booking: ${e.toString()}');
  }
}

  @override
  Future<List<BookingModel>> getUserBookings({
    required String userId,
    required String userType,
    String? status,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      print('📋 Fetching bookings for $userType: $userId');

      var query = client.from('bookings').select('*');

      if (userType.toLowerCase() == 'customer' || userType.toLowerCase() == 'client') {
        query = query.eq('client_id', userId);
      } else if (userType.toLowerCase() == 'artisan') {
        query = query.eq('artisan_id', userId);
      }

      if (status != null && status.isNotEmpty) {
        query = query.eq('status', status);
      }

      final response = await query
          .order('created_at', ascending: false)
          .range(limit * offset, (limit * offset) + limit - 1);

      print('✅ Found ${(response as List).length} bookings');

      final rows = (response as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(growable: false);
      final enriched = await _enrichBookingsWithUserData(rows);
      return enriched.map(BookingModel.fromJson).toList(growable: false);
    } on PostgrestException catch (e) {
      print('❌ Database error: ${e.message}');
      throw ServerException(message: e.message);
    } catch (e) {
      print('❌ Error fetching bookings: $e');
      throw ServerException(message: 'Failed to fetch bookings: ${e.toString()}');
    }
  }

  @override
  Future<BookingModel> getBookingById(String bookingId) async {
    try {
      print('🔍 Fetching booking: $bookingId');

      final bookingResponse = await client
          .from('bookings')
          .select('*')
          .eq('id', bookingId)
          .single();

      final enrichedList = await _enrichBookingsWithUserData([
        Map<String, dynamic>.from(bookingResponse),
      ]);
      final enrichedBooking = enrichedList.first;

      print('✅ Booking found');

      return BookingModel.fromJson(enrichedBooking);
    } on PostgrestException catch (e) {
      print('❌ Database error: ${e.message}');
      throw ServerException(message: e.message);
    } catch (e) {
      print('❌ Error fetching booking: $e');
      throw ServerException(message: 'Failed to fetch booking: ${e.toString()}');
    }
  }

  Future<List<Map<String, dynamic>>> _enrichBookingsWithUserData(
    List<Map<String, dynamic>> bookings,
  ) async {
    try {
      if (bookings.isEmpty) return bookings;

      final clientIds = bookings
          .map((b) => b['client_id'] as String?)
          .whereType<String>()
          .toSet()
          .toList(growable: false);
      final artisanIds = bookings
          .map((b) => b['artisan_id'] as String?)
          .whereType<String>()
          .toSet()
          .toList(growable: false);
      final artisanProfileIds = bookings
          .map((b) => b['artisan_profile_id'] as String?)
          .whereType<String>()
          .toSet()
          .toList(growable: false);

      final userIds = <String>{...clientIds, ...artisanIds}.toList(growable: false);

      Map<String, Map<String, dynamic>> usersById = {};
      Map<String, Map<String, dynamic>> profilesById = {};

      if (userIds.isNotEmpty) {
        final users = await client
            .from('users')
            .select('id,name,email,phone,photo_url')
            .inFilter('id', userIds);
        usersById = {
          for (final row in (users as List))
            (row as Map<String, dynamic>)['id'] as String:
                Map<String, dynamic>.from(row as Map),
        };
      }

      if (artisanProfileIds.isNotEmpty) {
        final profiles = await client
            .from('artisan_profiles')
            .select('id,category,rating,reviews_count')
            .inFilter('id', artisanProfileIds);
        profilesById = {
          for (final row in (profiles as List))
            (row as Map<String, dynamic>)['id'] as String:
                Map<String, dynamic>.from(row as Map),
        };
      }

      for (final booking in bookings) {
        final clientId = booking['client_id'] as String?;
        final artisanId = booking['artisan_id'] as String?;
        final artisanProfileId = booking['artisan_profile_id'] as String?;

        final clientData = clientId == null ? null : usersById[clientId];
        if (clientData != null) {
          booking['customer_name'] = clientData['name'];
          booking['customer_email'] = clientData['email'];
          booking['customer_phone'] = clientData['phone'];
          booking['customer_photo_url'] = clientData['photo_url'];
        }

        final artisanData = artisanId == null ? null : usersById[artisanId];
        if (artisanData != null) {
          booking['artisan_name'] = artisanData['name'];
          booking['artisan_email'] = artisanData['email'];
          booking['artisan_phone'] = artisanData['phone'];
          booking['artisan_photo_url'] = artisanData['photo_url'];
        }

        final profileData =
            artisanProfileId == null ? null : profilesById[artisanProfileId];
        if (profileData != null) {
          booking['artisan_category'] = profileData['category'];
          booking['artisan_rating'] = profileData['rating'];
          booking['artisan_review_count'] = profileData['reviews_count'];
        }
      }

      return bookings;
    } catch (e) {
      print('⚠️ Error enriching booking data: $e');
      return bookings;
    }
  }

  @override
  Future<void> updateBookingStatus({
    required String bookingId,
    required String newStatus,
    String? reason,
  }) async {
    try {
      print('🔄 Updating booking status to: $newStatus');

      final updateData = <String, dynamic>{
        'status': newStatus,
        'updated_at': DateTime.now().toIso8601String(),
      };

      switch (newStatus) {
        case 'accepted':
          updateData['accepted_at'] = DateTime.now().toIso8601String();
          break;
        case 'in_progress':
          updateData['started_at'] = DateTime.now().toIso8601String();
          break;
        case 'completed':
          updateData['completed_at'] = DateTime.now().toIso8601String();
          break;
        case 'rejected':
          updateData['rejected_at'] = DateTime.now().toIso8601String();
          if (reason != null) {
            updateData['rejection_reason'] = reason;
          }
          break;
      }

      await client
          .from('bookings')
          .update(updateData)
          .eq('id', bookingId);

      print('✅ Booking status updated');
    } on PostgrestException catch (e) {
      print('❌ Database error: ${e.message}');
      throw ServerException(message: e.message);
    } catch (e) {
      print('❌ Error updating booking status: $e');
      throw ServerException(message: 'Failed to update booking: ${e.toString()}');
    }
  }

  @override
  Future<void> cancelBooking({
    required String bookingId,
    required String cancelledBy,
    required String reason,
  }) async {
    try {
      print('❌ Cancelling booking: $bookingId');

      await client.from('bookings').update({
        'status': 'cancelled',
        'cancellation_reason': reason,
        'cancelled_by': cancelledBy,
        'cancelled_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', bookingId);

      print('✅ Booking cancelled');
    } on PostgrestException catch (e) {
      print('❌ Database error: ${e.message}');
      throw ServerException(message: e.message);
    } catch (e) {
      print('❌ Error cancelling booking: $e');
      throw ServerException(message: 'Failed to cancel booking: ${e.toString()}');
    }
  }

@override
Future<void> acceptBooking(String bookingId) async {
  // ✅ Check artisan moderation status before accepting
  final bookingRow = await client
      .from('bookings')
      .select('artisan_id')
      .eq('id', bookingId)
      .maybeSingle();

  if (bookingRow == null) {
    throw const ServerException(message: 'Booking not found.');
  }

  final artisanId = bookingRow['artisan_id'] as String?;
  if (artisanId != null) {
    final userRow = await client
        .from('users')
        .select('moderation_status')
        .eq('id', artisanId)
        .maybeSingle();

    final status = (userRow?['moderation_status'] as String?) ?? 'active';
    if (status != 'active') {
      throw const ServerException(
        message: 'Your account is restricted from accepting bookings.',
      );
    }
  }

  // ✅ Just update status - trigger will send notification
  await updateBookingStatus(
    bookingId: bookingId,
    newStatus: 'accepted',
  );
  
  // ✅ REMOVED: Manual notification insert
}

@override
Future<void> rejectBooking({
  required String bookingId,
  required String reason,
}) async {
  // ✅ Just update status - trigger will send notification
  await updateBookingStatus(
    bookingId: bookingId,
    newStatus: 'rejected',
    reason: reason,
  );
  
  // ✅ REMOVED: Manual notification insert
}

  

  @override
  Future<void> startBooking(String bookingId) async {
    await updateBookingStatus(bookingId: bookingId, newStatus: 'in_progress');
  }

  @override
  Future<void> completeBooking(String bookingId) async {
    await updateBookingStatus(bookingId: bookingId, newStatus: 'completed');
  }

  @override
  Future<Map<String, int>> getBookingStats({
    required String userId,
    required String userType,
  }) async {
    try {
      print('📊 Fetching booking stats for $userType: $userId');

      final filterField = userType.toLowerCase() == 'artisan' 
          ? 'artisan_id' 
          : 'client_id';

      final allBookings = await client
          .from('bookings')
          .select('status')
          .eq(filterField, userId);

      final stats = {
        'total': allBookings.length,
        'pending': 0,
        'accepted': 0,
        'completed': 0,
        'cancelled': 0,
        'in_progress': 0,
        'rejected': 0,
      };

      for (final booking in allBookings) {
        final status = (booking['status'] as String).toLowerCase();
        if (stats.containsKey(status)) {
          stats[status] = stats[status]! + 1;
        }
      }

      return stats.map((key, value) => MapEntry(key, value));
    } on PostgrestException catch (e) {
      print('❌ Database error: ${e.message}');
      throw ServerException(message: e.message);
    } catch (e) {
      print('❌ Error fetching booking stats: $e');
      return {
        'total': 0,
        'pending': 0,
        'accepted': 0,
        'completed': 0,
        'cancelled': 0,
      };
    }
  }
}

