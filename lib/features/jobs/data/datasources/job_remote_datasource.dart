// ================================================================
// JOB REMOTE DATA SOURCE (FIXED - Only shows pending/matched jobs)
// lib/features/jobs/data/datasources/job_remote_datasource.dart
// ================================================================

import 'dart:math' as math;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/job_model.dart';
import '../../../../core/error/exceptions.dart';

abstract class JobRemoteDataSource {
  Future<JobModel> postJob(JobFormModel form, String customerId);
  Future<List<JobModel>> getCustomerJobs(String customerId);
  Future<JobModel> getJobById(String jobId);
  Future<List<JobMatchModel>> getArtisanJobMatches(String artisanId);
  Future<JobModel> acceptJob(String jobId, String artisanId);
  Future<void> rejectJob(String jobId, String artisanId);
  Future<JobModel> updateJobStatus(String jobId, String status);
  Future<void> cancelJob(String jobId);
}

class JobRemoteDataSourceImpl implements JobRemoteDataSource {
  final SupabaseClient supabaseClient;

  JobRemoteDataSourceImpl({required this.supabaseClient});

  @override
  Future<JobModel> postJob(JobFormModel form, String customerId) async {
    try {
      print('📝 Posting job for customer: $customerId');
      
      final jobData = <String, dynamic>{
        'customer_id': customerId,
        'title': form.title ?? '${form.category} Service',
        'description': form.description,
        'category': form.category,
        'budget_min': form.budgetMin,
        'budget_max': form.budgetMax,
        'latitude': form.latitude,
        'longitude': form.longitude,
        'location': 'POINT(${form.longitude} ${form.latitude})',
        'address': form.address,
        'preferred_date': form.preferredDate?.toIso8601String(),
        'preferred_time_start': form.preferredTimeStart,
        'preferred_time_end': form.preferredTimeEnd,
        'is_urgent': form.isUrgent,
        'images': form.images,
        'status': 'pending',
      };

      final jobResponse = await supabaseClient
          .from('jobs')
          .insert(jobData)
          .select()
          .single();

      final job = JobModel.fromJson(jobResponse);
      print('✅ Job created: ${job.id}');

      // Trigger matching async (don't wait)
      _matchArtisansToJob(
        jobId: job.id,
        latitude: form.latitude!,
        longitude: form.longitude!,
        category: form.category!,
      ).catchError((e) {
        print('⚠️ Matching error (non-blocking): $e');
      });

      return job;
    } on PostgrestException catch (e) {
      print('❌ Database error: ${e.message}');
      throw ServerException(message: e.message);
    } catch (e) {
      print('❌ Error posting job: $e');
      throw ServerException(message: 'Failed to post job: $e');
    }
  }

  // ✅ NEW METHOD: Create notifications for matched artisans
Future<void> _createJobNotifications({
  required String jobId,
  required List<Map<String, dynamic>> matches,
  required double latitude,
  required double longitude,
}) async {
  try {
    // Get job details (use maybeSingle to avoid PGRST116 if the job was removed)
    final jobResponse = await supabaseClient
        .from('jobs')
        .select('title, description, category, customer_id, budget_min, budget_max')
        .eq('id', jobId)
        .maybeSingle();

    if (jobResponse == null) {
      print('⚠️ Job $jobId not found while creating notifications; skipping notifications.');
      return;
    }

    // Get customer name (tolerate missing customer)
    final customerResponse = await supabaseClient
        .from('users')
        .select('name')
        .eq('id', jobResponse['customer_id'])
        .maybeSingle();

    final customerName = customerResponse != null ? (customerResponse['name'] as String) : 'Customer';
    final jobTitle = jobResponse['title'] as String;
    final category = jobResponse['category'] as String;
    final budgetMin = jobResponse['budget_min'];
    final budgetMax = jobResponse['budget_max'];

    String? budgetText;
    if (budgetMin != null && budgetMax != null) {
      budgetText = '₦$budgetMin-₦$budgetMax';
    }

    // ✅ FIXED: Use UTC time consistently
    final now = DateTime.now().toUtc();

    // Create notifications for all matched artisans
    final notifications = matches.map((match) {
      final artisanId = match['artisan_id'] as String;
      final distance = match['distance_km'] as num;
      final matchScore = match['match_score'] as num;

      return {
        'user_id': artisanId,
        'type': 'job',
        'title': '💼 New $category Job',
        'body': '$customerName: $jobTitle (${distance.toStringAsFixed(1)}km away)',
        'related_id': jobId,
        'read': false,
        'created_at': now.toIso8601String(), // ✅ FIXED: Use UTC time
        'data': {
          'subType': 'job_match',
          'jobId': jobId,
          'jobTitle': jobTitle,
          'category': category,
          'customerName': customerName,
          'distanceKm': distance.toStringAsFixed(6),
          'matchScore': matchScore.toStringAsFixed(2),
          'budget': budgetText ?? '',
          'action': 'open_job',
        },
      };
    }).toList();

    // Insert all notifications at once
    await supabaseClient.from('notifications').insert(notifications);

    print('✅ Created ${notifications.length} job notifications');
  } catch (e) {
    print('❌ Error creating job notifications: $e');
  }
}

  // In job_remote_datasource.dart - Update _matchArtisansToJob

Future<void> _matchArtisansToJob({
  required String jobId,
  required double latitude,
  required double longitude,
  required String category,
}) async {
  try {
    print('🔍 Matching artisans for job: $jobId');

    // Get nearby artisans
    final artisansResponse = await supabaseClient
        .from('artisan_profiles')
        .select('user_id, rating, premium, verified, availability_status')
        .eq('category', category)
        .eq('availability_status', 'available');

    if ((artisansResponse as List).isEmpty) {
      print('⚠️ No artisans found for category: $category');
      
      // ✅ Update job with zero matches
      await supabaseClient
          .from('jobs')
          .update({
            'status': 'pending', // Keep as pending, not matched
            'notified_artisan_count': 0,
          })
          .eq('id', jobId);
      
      return;
    }

    // Get user locations
    final userIds = (artisansResponse as List)
        .map((a) => (a as Map<String, dynamic>)['user_id'] as String)
        .toList();

    final usersResponse = await supabaseClient.rpc(
      'get_users_with_location',
      params: {'user_ids': userIds},
    );

    // Calculate distances and match scores
    final matches = <Map<String, dynamic>>[];

    for (var artisan in (artisansResponse as List)) {
      final artisanMap = artisan as Map<String, dynamic>;
      final userId = artisanMap['user_id'] as String;

      final userList = (usersResponse as List);
      final matchesForUser = userList.where((u) => (u as Map<String, dynamic>)['id'] == userId);
      if (matchesForUser.isEmpty) continue;

      final userMap = matchesForUser.first as Map<String, dynamic>;
      final artisanLat = userMap['latitude'];
      final artisanLng = userMap['longitude'];

      if (artisanLat == null || artisanLng == null) continue;

      final distance = _calculateDistance(
        latitude,
        longitude,
        (artisanLat as num).toDouble(),
        (artisanLng as num).toDouble(),
      );

      if (distance > 20) continue;

      final rating = (artisanMap['rating'] as num?)?.toDouble() ?? 0;
      final isPremium = artisanMap['premium'] as bool? ?? false;
      final isVerified = artisanMap['verified'] as bool? ?? false;

      final matchScore = (rating * 10) +
          (isPremium ? 20 : 0) +
          (isVerified ? 10 : 0) +
          (30 - (distance * 3).clamp(0, 30));

      matches.add({
        'job_id': jobId,
        'artisan_id': userId,
        'distance_km': distance,
        'match_score': matchScore,
        'is_premium_artisan': isPremium,
        'priority_tier': isPremium ? 1 : 0,
        'notification_delay_seconds': 0,
      });
    }

    if (matches.isEmpty) {
      print('⚠️ No artisans within 20km');
      
      // ✅ Update job with zero matches
      await supabaseClient
          .from('jobs')
          .update({
            'status': 'pending',
            'notified_artisan_count': 0,
          })
          .eq('id', jobId);
      
      return;
    }

    matches.sort((a, b) => 
      (b['match_score'] as num).compareTo(a['match_score'] as num)
    );

    final topMatches = matches.take(20).toList();

    // ✅ INSERT MATCHES FIRST
    await supabaseClient.from('job_matches').insert(topMatches);

    // ✅ CREATE NOTIFICATIONS (with proper error handling)
    await _createJobNotifications(
      jobId: jobId,
      matches: topMatches,
      latitude: latitude,
      longitude: longitude,
    );

    // ✅ UPDATE JOB STATUS LAST (after notifications created)
    await supabaseClient
        .from('jobs')
        .update({
          'status': 'matched',
          'notified_artisan_count': topMatches.length,
        })
        .eq('id', jobId);

    print('✅ Matched ${topMatches.length} artisans');
  } catch (e) {
    print('❌ Matching error: $e');
    
    // ✅ Update job with error status
    try {
      await supabaseClient
          .from('jobs')
          .update({
            'status': 'pending',
            'notified_artisan_count': 0,
          })
          .eq('id', jobId);
    } catch (_) {}
  }
}

  // ✅ FIXED: Use dart:math for accurate calculations
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371;
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    
    final c = 2 * math.asin(math.sqrt(a));
    return earthRadius * c;
  }

  double _toRadians(double degree) => degree * (math.pi / 180);

  @override
  Future<List<JobModel>> getCustomerJobs(String customerId) async {
    try {
      final response = await supabaseClient
          .from('jobs')
          .select()
          .eq('customer_id', customerId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => JobModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw ServerException(message: 'Failed to load jobs: $e');
    }
  }

  // ✅ CRITICAL FIX: Only return jobs that are still pending or matched
  @override
  Future<List<JobMatchModel>> getArtisanJobMatches(String artisanId) async {
    try {
      print('🔍 Loading job matches for artisan: $artisanId');

      final response = await supabaseClient
          .from('job_matches')
          .select()
          .eq('artisan_id', artisanId)
          .isFilter('response', null)
          .order('created_at', ascending: false);

      final matches = <JobMatchModel>[];

      for (var matchData in (response as List)) {
        final match = matchData as Map<String, dynamic>;
        final jobId = match['job_id'] as String;

        // Fetch job details (skip if missing)
        final jobResponse = await supabaseClient
            .from('jobs')
            .select()
            .eq('id', jobId)
            .maybeSingle();

        if (jobResponse == null) {
          print('⚠️ Skipping match because job $jobId not found');
          continue; // skip this match
        }

        final job = JobModel.fromJson(jobResponse);

        // ✅ CRITICAL FIX: Only include jobs that are still pending or matched
        // Skip jobs that have been accepted, completed, or cancelled
        if (job.status != 'pending' && job.status != 'matched') {
          print('⚠️ Skipping job ${job.id} - status is ${job.status}');
          continue;
        }

        // Fetch customer details (tolerate missing customer)
        final customerResponse = await supabaseClient
            .from('users')
            .select('name, photo_url')
            .eq('id', job.customerId)
            .maybeSingle();

        final jobWithCustomer = job.copyWith(
          customerName: customerResponse != null ? customerResponse['name'] as String? : null,
          customerPhotoUrl: customerResponse != null ? customerResponse['photo_url'] as String? : null,
        );

        match['job'] = jobWithCustomer;
        matches.add(JobMatchModel.fromJson(match));
      }

      print('✅ Loaded ${matches.length} available job matches (pending/matched only)');
      return matches;
    } catch (e) {
      print('❌ Error loading matches: $e');
      throw ServerException(message: 'Failed to load job matches: $e');
    }
  }
/** 
  @override
  Future<JobModel> acceptJob(String jobId, String artisanId) async {
    try {
      print('✅ Artisan $artisanId attempting to accept job $jobId');

      // Verify the job exists and is available
      final existingJob = await supabaseClient
          .from('jobs')
          .select()
          .eq('id', jobId)
          .maybeSingle();

      if (existingJob == null) {
        throw ServerException(message: 'Job not found');
      }

      final currentStatus = existingJob['status'] as String?;
      final acceptedBy = existingJob['accepted_by'] as String?;

      print('📊 Job current state:');
      print('   - ID: $jobId');
      print('   - Status: $currentStatus');
      print('   - Accepted by: $acceptedBy');
      print('   - Full job data: $existingJob');

      if (currentStatus == 'cancelled' || currentStatus == 'completed') {
        throw ServerException(message: 'Job is no longer available');
      }

      if (currentStatus == 'accepted' || currentStatus == 'in_progress') {
        throw ServerException(message: 'Job has already been accepted by another artisan');
      }

      if (acceptedBy != null && acceptedBy.isNotEmpty) {
        throw ServerException(message: 'Job has already been accepted by another artisan');
      }

      // Simple atomic update without extra filters - let database constraints handle it
      print('🔄 Attempting to update job...');
      final response = await supabaseClient
          .from('jobs')
          .update({
            'status': 'accepted',
            'accepted_by': artisanId,
            'accepted_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', jobId)
          .select();

      print('📊 Update response: $response');

      if (response == null || (response as List).isEmpty) {
        throw ServerException(message: 'Job has already been accepted by another artisan');
      }

      final updatedJob = (response as List).first;

      // Update the match record for this artisan
      await supabaseClient
          .from('job_matches')
          .update({
            'response': 'accepted',
            'responded_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('job_id', jobId)
          .eq('artisan_id', artisanId);

      print('✅ Job accepted successfully');
      return JobModel.fromJson(updatedJob as Map<String, dynamic>);
    } on PostgrestException catch (e) {
      final errMsg = e.message?.toString() ?? '';
      print('❌ DB error accepting job: $errMsg');
      print('❌ Error details: ${e.details}');
      print('❌ Error code: ${e.code}');

      if (errMsg.contains('PGRST116') || errMsg.contains('result contains 0 rows') || errMsg.contains('Cannot coerce the result')) {
        throw ServerException(message: 'Job has already been accepted by another artisan');
      }

      throw ServerException(message: 'Failed to accept job: $errMsg');
    } catch (e) {
      print('❌ Unknown error accepting job: $e');
      throw ServerException(message: 'Failed to accept job: $e');
    }
  }**/

  @override
  Future<void> rejectJob(String jobId, String artisanId) async {
    try {
      print('❌ Artisan $artisanId rejecting job $jobId');

      await supabaseClient
          .from('job_matches')
          .update({
            'response': 'rejected',
            'responded_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('job_id', jobId)
          .eq('artisan_id', artisanId);

      print('✅ Job rejected successfully');
    } catch (e) {
      throw ServerException(message: 'Failed to reject job: $e');
    }
  }

  // New: get a single job by id
  @override
  Future<JobModel> getJobById(String jobId) async {
    try {
      final jobResponse = await supabaseClient
          .from('jobs')
          .select()
          .eq('id', jobId)
          .maybeSingle();

      if (jobResponse == null) {
        throw ServerException(message: 'Job not found');
      }

      return JobModel.fromJson(jobResponse);
    } catch (e) {
      print('❌ Error fetching job by id: $e');
      throw ServerException(message: 'Failed to load job: $e');
    }
  }

  @override
  Future<JobModel> updateJobStatus(String jobId, String status) async {
    try {
      final updateData = <String, dynamic>{'status': status};

      if (status == 'in_progress') {
        updateData['started_at'] = DateTime.now().toUtc().toIso8601String();
      } else if (status == 'completed') {
        updateData['completed_at'] = DateTime.now().toUtc().toIso8601String();
      }

      final response = await supabaseClient
          .from('jobs')
          .update(updateData)
          .eq('id', jobId)
          .select()
          .single();

      return JobModel.fromJson(response);
    } catch (e) {
      throw ServerException(message: 'Failed to update job: $e');
    }
  }

  @override
Future<JobModel> acceptJob(String jobId, String artisanId) async {
  try {
    print('✅ Artisan $artisanId attempting to accept job $jobId');

    // 1️⃣ Verify the job exists and is available
    final existingJob = await supabaseClient
        .from('jobs')
        .select()
        .eq('id', jobId)
        .maybeSingle();

    if (existingJob == null) {
      throw ServerException(message: 'Job not found');
    }

    final currentStatus = existingJob['status'] as String?;
    final acceptedBy = existingJob['accepted_by'] as String?;

    if (currentStatus == 'cancelled' || currentStatus == 'completed') {
      throw ServerException(message: 'Job is no longer available');
    }

    if (currentStatus == 'accepted' || acceptedBy != null) {
      throw ServerException(message: 'Job has already been accepted by another artisan');
    }

    // 2️⃣ Update the job status
    final jobResponse = await supabaseClient
        .from('jobs')
        .update({
          'status': 'accepted',
          'accepted_by': artisanId,
          'accepted_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', jobId)
        .select()
        .single();

    // 3️⃣ Update the job match
    await supabaseClient
        .from('job_matches')
        .update({
          'response': 'accepted',
          'responded_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('job_id', jobId)
        .eq('artisan_id', artisanId);

    // 🆕 4️⃣ CREATE A BOOKING AUTOMATICALLY
    final job = JobModel.fromJson(jobResponse);
    final bookingId = await _createBookingFromJob(job, artisanId);
    
    print('✅ Job accepted and booking created: $bookingId');

    return job;
  } catch (e) {
    print('❌ Error accepting job: $e');
    throw ServerException(message: 'Failed to accept job: $e');
  }
}

// 🆕 NEW METHOD: Create booking from accepted job
Future<String> _createBookingFromJob(JobModel job, String artisanId) async {
  try {
    print('📝 Creating booking from job ${job.id}');

    // Get artisan profile to get profile_id
    final artisanProfile = await supabaseClient
        .from('artisan_profiles')
        .select('id, category')
        .eq('user_id', artisanId)
        .single();

    // Determine scheduled date
    final scheduledDate = job.preferredDate ?? DateTime.now().add(Duration(days: 1));
    
    // Create the booking
    final bookingData = {
      'client_id': job.customerId,
      'artisan_id': artisanId,
      'artisan_profile_id': artisanProfile['id'],
      'service_type': job.category,
      'description': job.description,
      'scheduled_date': scheduledDate.toIso8601String(),
      'location_address': job.address ?? 'Address not specified',
      'location_latitude': job.latitude,
      'location_longitude': job.longitude,
      'estimated_price': job.budgetMax ?? job.budgetMin,
      'customer_notes': 'Created from job request: ${job.title}',
      'status': 'accepted', // ✅ Start as accepted since job was already accepted
      'accepted_at': DateTime.now().toUtc().toIso8601String(),
      'payment_status': 'unpaid',
      'job_id': job.id, // 🔗 Link back to the job
    };

    final bookingResponse = await supabaseClient
        .from('bookings')
        .insert(bookingData)
        .select()
        .single();

    // Update the job with booking_id reference
    await supabaseClient
        .from('jobs')
        .update({'booking_id': bookingResponse['id']})
        .eq('id', job.id);

    print('✅ Booking created: ${bookingResponse['id']}');
    return bookingResponse['id'] as String;

  } catch (e) {
    print('❌ Error creating booking from job: $e');
    throw ServerException(message: 'Failed to create booking: $e');
  }
}


  @override
  Future<void> cancelJob(String jobId) async {
    try {
      await supabaseClient
          .from('jobs')
          .update({
            'status': 'cancelled',
            'cancelled_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', jobId);
    } catch (e) {
      throw ServerException(message: 'Failed to cancel job: $e');
    }
  }
}