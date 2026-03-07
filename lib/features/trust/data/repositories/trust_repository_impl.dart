// lib/features/trust/data/repositories/trust_repository_impl.dart
// COMPLETE UNIVERSAL VERIFICATION VERSION
// Supports verification for BOTH artisans and customers

import 'dart:io';
import 'package:dartz/dartz.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/identity_verification_entity.dart';
import '../../domain/entities/dispute_entity.dart';
import '../../domain/entities/report_entity.dart';
import '../../domain/entities/blocked_user_entity.dart';
import '../../domain/entities/dispute_message_entity.dart';
import '../../domain/entities/dispute_event_entity.dart';
import '../../domain/entities/admin_user_entity.dart';
import '../../domain/entities/platform_analytics_entity.dart';
import '../../domain/repositories/trust_repository.dart';
import '../models/identity_verification_model.dart';
import '../models/dispute_model.dart';
import '../models/report_model.dart';

class TrustRepositoryImpl implements TrustRepository {
  final SupabaseClient supabaseClient;

  TrustRepositoryImpl({required this.supabaseClient});

  // ---------------------------
  // Identity Verification
  // ---------------------------
  @override
  Future<Either<Failure, IdentityVerificationEntity?>>
      getLatestIdentityVerification(String userId) async {
    try {
      final response = await supabaseClient
          .from('identity_verifications')
          .select()
          .eq('user_id', userId)
          .order('submitted_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) {
        return const Right(null);
      }

      return Right(IdentityVerificationModel.fromJson(
          Map<String, dynamic>.from(response)));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, IdentityVerificationEntity>>
      submitIdentityVerification({
    required String userId,
    required String docType,
    required String docFilePath,
    required String selfieFilePath,
  }) async {
    try {
      final authUser = supabaseClient.auth.currentUser;
      print('🔐 Auth user: ${authUser?.id}');
      
      if (authUser == null) {
        return Left(ServerFailure(message: 'Not authenticated in Supabase.'));
      }
      if (authUser.id != userId) {
        print('⚠️ User ID mismatch. auth=${authUser.id}, param=$userId');
      }
      final ownerId = authUser.id;

      print('📤 Uploading verification documents...');
      final docUrl = await _uploadImage(
        bucket: 'identity-docs',
        userId: ownerId,
        filePath: docFilePath,
        prefix: 'doc',
      );
      final selfieUrl = await _uploadImage(
        bucket: 'identity-selfies',
        userId: ownerId,
        filePath: selfieFilePath,
        prefix: 'selfie',
      );

      final payload = {
        'user_id': ownerId,
        'doc_type': docType,
        'doc_url': docUrl,
        'selfie_url': selfieUrl,
        'status': 'pending',
        'submitted_at': DateTime.now().toIso8601String(),
      };

      print('💾 Saving verification to database...');
      final response = await supabaseClient
          .from('identity_verifications')
          .insert(payload)
          .select()
          .single();

      print('✅ Verification submitted successfully');
      return Right(IdentityVerificationModel.fromJson(
          Map<String, dynamic>.from(response)));
    } catch (e) {
      print('❌ submitIdentityVerification failed: $e');
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<IdentityVerificationEntity>>>
      adminListIdentityVerifications({String? status}) async {
    try {
      var query = supabaseClient.from('identity_verifications').select();

      if (status != null && status.isNotEmpty) {
        query = query.eq('status', status);
      }

      final response = await query.order('submitted_at', ascending: false);
      final list = (response as List)
          .map((item) => IdentityVerificationModel.fromJson(
              Map<String, dynamic>.from(item)))
          .toList();

      return Right(list);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> adminReviewIdentityVerification({
    required String verificationId,
    required String status,
    String? rejectionReason,
  }) async {
    try {
      print('🔄 Starting UNIVERSAL verification review...');
      print('   Verification ID: $verificationId');
      print('   New Status: $status');
      
      // Get user_id first
      final verification = await supabaseClient
          .from('identity_verifications')
          .select('user_id')
          .eq('id', verificationId)
          .single();

      final userId = verification['user_id'] as String;
      print('   User ID: $userId');

      final shouldBeVerified = status == 'verified';

      // Check if user is an artisan from source-of-truth users.user_type,
      // then ensure artisan profile exists for artisan accounts.
      final userRow = await supabaseClient
          .from('users')
          .select('user_type')
          .eq('id', userId)
          .single();

      final isArtisan = (userRow['user_type'] as String?) == 'artisan';
      print('   User Type: ${isArtisan ? "ARTISAN" : "CUSTOMER"}');

      if (isArtisan) {
        final artisanProfile = await supabaseClient
            .from('artisan_profiles')
            .select('id')
            .eq('user_id', userId)
            .maybeSingle();
        if (artisanProfile == null) {
          throw Exception(
            'Verification sync failed: artisan profile not found for artisan user $userId.',
          );
        }
      }

      // Update verification status in identity_verifications table
      await supabaseClient.from('identity_verifications').update({
        'status': status,
        'reviewed_at': DateTime.now().toIso8601String(),
        'rejection_reason': rejectionReason,
      }).eq('id', verificationId);
      
      print('✅ Verification status updated in identity_verifications');

      // ✅ UNIVERSAL UPDATE: Keep users.verified and artisan_profiles.verified in sync.
      if (status == 'verified' || status == 'rejected') {
        print('🔄 Setting users.verified=$shouldBeVerified ...');

        final userUpdateResult = await supabaseClient
            .from('users')
            .update({'verified': shouldBeVerified})
            .eq('id', userId)
            .select('id');

        if ((userUpdateResult as List).isEmpty) {
          throw Exception('Verification sync failed: users row was not updated for $userId.');
        }
        print('✅ Users table updated: ${userUpdateResult.length} rows');

        if (isArtisan) {
          print('🔄 Setting artisan_profiles.verified=$shouldBeVerified ...');

          final artisanUpdateResult = await supabaseClient
              .from('artisan_profiles')
              .update({'verified': shouldBeVerified})
              .eq('user_id', userId)
              .select('id');

          if ((artisanUpdateResult as List).isEmpty) {
            throw Exception(
              'Verification sync failed: artisan profile was not updated for $userId.',
            );
          }
          print('✅ Artisan profile updated: ${artisanUpdateResult.length} rows');
        }
      }

      // ✅ VERIFY: Check that users.verified was actually updated
      final userCheck = await supabaseClient
          .from('users')
          .select('verified')
          .eq('id', userId)
          .single();
      
      final userVerified = userCheck['verified'] as bool?;
      print('📊 Final verification status in users table: $userVerified');
      
      if ((status == 'verified' || status == 'rejected') &&
          userVerified != shouldBeVerified) {
        print('❌ WARNING: Verification status not synced to users table!');
        throw Exception('Failed to sync verification status to users table');
      }
      
      // If artisan, also verify artisan_profiles was updated
      if (isArtisan) {
        final artisanCheckResult = await supabaseClient
            .from('artisan_profiles')
            .select('verified')
            .eq('user_id', userId)
            .single();
        final artisanVerified = artisanCheckResult['verified'] as bool?;
        print('📊 Final verification status in artisan_profiles: $artisanVerified');

        if ((status == 'verified' || status == 'rejected') &&
            artisanVerified != shouldBeVerified) {
          print('❌ WARNING: Verification status not synced to artisan_profiles!');
          throw Exception('Failed to sync verification status to artisan_profiles');
        }
      }

      print('✅ UNIVERSAL verification review completed successfully');
      print('   ✓ users.verified = ${userVerified}');
      if (isArtisan) {
        print('   ✓ artisan_profiles.verified = true');
      }
      
      return const Right(null);
    } catch (e) {
      print('❌ adminReviewIdentityVerification failed: $e');
      return Left(ServerFailure(message: e.toString()));
    }
  }

  // ---------------------------
  // Disputes
  // ---------------------------
  @override
  Future<Either<Failure, DisputeEntity>> openDispute({
    required String bookingId,
    required String openedBy,
    required String reason,
    List<String> evidenceFilePaths = const [],
  }) async {
    try {
      final authUser = supabaseClient.auth.currentUser;
      if (authUser == null) {
        return Left(ServerFailure(message: 'Not authenticated in Supabase.'));
      }
      if (authUser.id != openedBy) {
        print('⚠️ OpenedBy mismatch. auth=${authUser.id}, param=$openedBy');
      }
      final ownerId = authUser.id;

      final evidenceUrls = <String>[];
      for (final path in evidenceFilePaths) {
        try {
          final url = await _uploadImage(
            bucket: 'dispute-evidence',
            userId: ownerId,
            filePath: path,
            prefix: 'evidence',
          );
          evidenceUrls.add(url);
        } catch (e) {
          print('⚠️ Failed to upload evidence file: $e');
          // Continue with other files even if one fails
        }
      }

      final payload = {
        'booking_id': bookingId,
        'raised_by': ownerId,
        'reason': reason,
        'evidence_urls': evidenceUrls,
        'status': 'open',
        'opened_at': DateTime.now().toIso8601String(),
      };

      print('📤 Creating dispute with payload: $payload');

      final response = await supabaseClient
          .from('disputes')
          .insert(payload)
          .select()
          .single();

      final disputeId = response['id'] as String;

      print('✅ Dispute created successfully');

      // Mark booking as disputed for UI visibility
      await supabaseClient
          .from('bookings')
          .update({'status': 'disputed', 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', bookingId);

      await _logDisputeEvent(
        disputeId: disputeId,
        actorId: ownerId,
        eventType: 'opened',
        note: reason,
      );
      await _notifyDisputeOpened(
        disputeId: disputeId,
        bookingId: bookingId,
        openedBy: ownerId,
      );

      return Right(DisputeModel.fromJson(
          Map<String, dynamic>.from(response)));
    } catch (e) {
      print('❌ openDispute failed: $e');
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<DisputeEntity>>> getDisputesForBooking(
    String bookingId,
  ) async {
    try {
      final response = await supabaseClient
          .from('disputes')
          .select()
          .eq('booking_id', bookingId)
          .order('opened_at', ascending: false);

      final disputes = (response as List)
          .map((item) => DisputeModel.fromJson(
              Map<String, dynamic>.from(item)))
          .toList();

      return Right(disputes);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<DisputeEntity>>> getMyDisputes(
    String userId,
  ) async {
    try {
      final response = await supabaseClient
          .from('disputes')
          .select()
          .eq('raised_by', userId)
          .order('opened_at', ascending: false);

      final disputes = (response as List)
          .map((item) => DisputeModel.fromJson(
              Map<String, dynamic>.from(item)))
          .toList();

      return Right(disputes);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<DisputeEntity>>> adminListDisputes({
    String? status,
  }) async {
    try {
      var query = supabaseClient.from('disputes').select();

      if (status != null && status.isNotEmpty) {
        query = query.eq('status', status);
      }

      final response = await query.order('opened_at', ascending: false);
      final disputes = (response as List)
          .map((item) => DisputeModel.fromJson(
              Map<String, dynamic>.from(item)))
          .toList();

      return Right(disputes);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> adminResolveDispute({
    required String disputeId,
    required String status,
    String? resolutionNotes,
  }) async {
    try {
      await supabaseClient.from('disputes').update({
        'status': status,
        'resolution_notes': resolutionNotes,
        'resolved_at': DateTime.now().toIso8601String(),
      }).eq('id', disputeId);

      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  // ---------------------------
  // Moderation Reports
  // ---------------------------
  @override
  Future<Either<Failure, ReportEntity>> submitReport({
    required String reporterId,
    required String targetType,
    required String targetId,
    required String reason,
  }) async {
    try {
      final authUser = supabaseClient.auth.currentUser;
      if (authUser == null) {
        return Left(ServerFailure(message: 'Not authenticated in Supabase.'));
      }
      if (authUser.id != reporterId) {
        print('⚠️ Reporter mismatch. auth=${authUser.id}, param=$reporterId');
      }
      final ownerId = authUser.id;

      final payload = {
        'reporter_id': ownerId,
        'target_type': targetType,
        'target_id': targetId,
        'reason': reason,
        'status': 'reported',
        'created_at': DateTime.now().toIso8601String(),
      };

      final response = await supabaseClient
          .from('reports')
          .insert(payload)
          .select()
          .single();

      return Right(ReportModel.fromJson(
          Map<String, dynamic>.from(response)));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<ReportEntity>>> getMyReports(
    String userId,
  ) async {
    try {
      final response = await supabaseClient
          .from('reports')
          .select()
          .eq('reporter_id', userId)
          .order('created_at', ascending: false);

      final reports = (response as List)
          .map((item) => ReportModel.fromJson(
              Map<String, dynamic>.from(item)))
          .toList();

      return Right(reports);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<ReportEntity>>> adminListReports({
    String? status,
  }) async {
    try {
      var query = supabaseClient.from('reports').select();

      if (status != null && status.isNotEmpty) {
        query = query.eq('status', status);
      }

      final response = await query.order('created_at', ascending: false);
      final reports = (response as List)
          .map((item) => ReportModel.fromJson(
              Map<String, dynamic>.from(item)))
          .toList();

      return Right(reports);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> adminUpdateReport({
    required String reportId,
    required String status,
    String? actionTaken,
  }) async {
    try {
      await supabaseClient.from('reports').update({
        'status': status,
        'action_taken': actionTaken,
        'reviewed_at': DateTime.now().toIso8601String(),
      }).eq('id', reportId);

      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  // ---------------------------
  // User blocking
  // ---------------------------
  @override
  Future<Either<Failure, void>> blockUser({
    required String blockerId,
    required String blockedUserId,
    String? reason,
  }) async {
    try {
      if (blockerId == blockedUserId) {
        return Left(ServerFailure(message: 'You cannot block yourself.'));
      }

      await supabaseClient.from('user_blocks').upsert({
        'blocker_id': blockerId,
        'blocked_user_id': blockedUserId,
        'reason': reason,
        'created_at': DateTime.now().toIso8601String(),
      }, onConflict: 'blocker_id,blocked_user_id');

      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> unblockUser({
    required String blockerId,
    required String blockedUserId,
  }) async {
    try {
      await supabaseClient
          .from('user_blocks')
          .delete()
          .eq('blocker_id', blockerId)
          .eq('blocked_user_id', blockedUserId);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<BlockedUserEntity>>> getBlockedUsers({
    required String blockerId,
  }) async {
    try {
      final rows = await supabaseClient
          .from('user_blocks')
          .select('blocked_user_id,reason,created_at')
          .eq('blocker_id', blockerId)
          .order('created_at', ascending: false);

      final blockRows = (rows as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      if (blockRows.isEmpty) {
        return const Right([]);
      }

      final blockedIds = blockRows
          .map((e) => e['blocked_user_id'] as String)
          .toList(growable: false);

      final users = await supabaseClient
          .from('users')
          .select('id,name,photo_url')
          .inFilter('id', blockedIds);

      final byId = <String, Map<String, dynamic>>{};
      for (final item in (users as List)) {
        final userMap = Map<String, dynamic>.from(item as Map);
        byId[userMap['id'] as String] = userMap;
      }

      final blocked = blockRows.map((row) {
        final blockedId = row['blocked_user_id'] as String;
        final profile = byId[blockedId];
        return BlockedUserEntity(
          blockedUserId: blockedId,
          name: profile?['name'] as String?,
          photoUrl: profile?['photo_url'] as String?,
          reason: row['reason'] as String?,
          blockedAt: DateTime.tryParse(row['created_at'] as String? ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0),
        );
      }).toList(growable: false);

      return Right(blocked);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  // ---------------------------
  // Dispute hearing
  // ---------------------------
  @override
  Future<Either<Failure, List<DisputeMessageEntity>>> getDisputeMessages({
    required String disputeId,
  }) async {
    try {
      final response = await supabaseClient
          .from('dispute_messages')
          .select()
          .eq('dispute_id', disputeId)
          .order('created_at', ascending: true);

      final items = (response as List).map((e) {
        final row = Map<String, dynamic>.from(e as Map);
        final evidence = row['evidence_urls'];
        return DisputeMessageEntity(
          id: row['id'] as String,
          disputeId: row['dispute_id'] as String,
          senderId: row['sender_id'] as String,
          message: row['message'] as String,
          evidenceUrls: evidence is List
              ? evidence.map((x) => x.toString()).toList()
              : const [],
          createdAt: DateTime.parse(row['created_at'] as String),
        );
      }).toList(growable: false);

      return Right(items);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<DisputeEventEntity>>> getDisputeEvents({
    required String disputeId,
  }) async {
    try {
      final response = await supabaseClient
          .from('dispute_events')
          .select()
          .eq('dispute_id', disputeId)
          .order('created_at', ascending: true);

      final items = (response as List).map((e) {
        final row = Map<String, dynamic>.from(e as Map);
        return DisputeEventEntity(
          id: row['id'] as String,
          disputeId: row['dispute_id'] as String,
          actorId: row['actor_id'] as String,
          eventType: row['event_type'] as String,
          note: row['note'] as String?,
          createdAt: DateTime.parse(row['created_at'] as String),
        );
      }).toList(growable: false);

      return Right(items);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> submitDisputeMessage({
    required String disputeId,
    required String senderId,
    required String message,
    List<String> evidenceFilePaths = const [],
  }) async {
    try {
      final evidenceUrls = <String>[];
      for (final path in evidenceFilePaths) {
        final url = await _uploadImage(
          bucket: 'dispute-evidence',
          userId: senderId,
          filePath: path,
          prefix: 'hearing',
        );
        evidenceUrls.add(url);
      }

      await supabaseClient.from('dispute_messages').insert({
        'dispute_id': disputeId,
        'sender_id': senderId,
        'message': message,
        'evidence_urls': evidenceUrls,
        'created_at': DateTime.now().toIso8601String(),
      });

      await _logDisputeEvent(
        disputeId: disputeId,
        actorId: senderId,
        eventType: 'message_submitted',
        note: message,
      );
      await _notifyDisputeUpdate(
        disputeId: disputeId,
        title: 'New dispute response',
        body: 'A new response was submitted in a dispute hearing.',
      );

      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> updateDisputeStatus({
    required String disputeId,
    required String actorId,
    required String status,
    String? note,
  }) async {
    try {
      final normalizedStatus = _normalizeDisputeStatus(status);
      await _updateDisputeStatusWithFallback(
        disputeId: disputeId,
        status: normalizedStatus,
        note: note,
      );

      await _logDisputeEvent(
        disputeId: disputeId,
        actorId: actorId,
        eventType: 'status_updated',
        note: normalizedStatus,
      );
      await _notifyDisputeUpdate(
        disputeId: disputeId,
        title: 'Dispute status updated',
        body: 'Dispute status changed to ${normalizedStatus.replaceAll('_', ' ')}.',
      );

      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  String _normalizeDisputeStatus(String input) {
    switch (input) {
      case 'awaiting_respondent':
      case 'opened':
        return 'open';
      case 'under_review':
        return 'in_review';
      default:
        return input;
    }
  }

  Future<void> _updateDisputeStatusWithFallback({
    required String disputeId,
    required String status,
    String? note,
  }) async {
    final candidates = <String>[status];
    if (status == 'open') {
      candidates.add('opened');
    } else if (status == 'in_review') {
      candidates.add('under_review');
    }

    Object? lastError;
    for (final candidate in candidates) {
      try {
        await supabaseClient.from('disputes').update({
          'status': candidate,
          'resolution_notes': note,
          'resolved_at': candidate.startsWith('resolved')
              ? DateTime.now().toIso8601String()
              : null,
        }).eq('id', disputeId);
        return;
      } catch (e) {
        lastError = e;
      }
    }
    throw lastError ?? Exception('Failed to update dispute status.');
  }

  // ---------------------------
  // Admin user management and analytics
  // ---------------------------
  @override
  Future<Either<Failure, List<AdminUserEntity>>> adminListUsers({
    String? query,
    String? moderationStatus,
  }) async {
    try {
      var req = supabaseClient.from('users').select();
      if (query != null && query.trim().isNotEmpty) {
        final q = query.trim();
        req = req.or('name.ilike.%$q%,email.ilike.%$q%');
      }
      if (moderationStatus != null && moderationStatus.isNotEmpty) {
        req = req.eq('moderation_status', moderationStatus);
      }

      final response = await req.order('created_at', ascending: false).limit(200);
      final users = (response as List).map((e) {
        final row = Map<String, dynamic>.from(e as Map);
        return AdminUserEntity(
          id: row['id'] as String,
          name: (row['name'] as String?) ?? 'Unknown',
          email: (row['email'] as String?) ?? '',
          userType: (row['user_type'] as String?) ?? 'customer',
          verified: (row['verified'] as bool?) ?? false,
          moderationStatus: (row['moderation_status'] as String?) ?? 'active',
          createdAt: DateTime.tryParse(row['created_at']?.toString() ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0),
        );
      }).toList(growable: false);

      return Right(users);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> adminSetUserModerationStatus({
    required String targetUserId,
    required String status,
    required String reason,
  }) async {
    try {
      final actor = supabaseClient.auth.currentUser;
      if (actor == null) {
        return Left(ServerFailure(message: 'Not authenticated.'));
      }

      await supabaseClient.from('users').update({
        'moderation_status': status,
      }).eq('id', targetUserId);

      final shouldBeAvailable = status == 'active';
      await supabaseClient.from('artisan_profiles').update({
        'availability_status': shouldBeAvailable ? 'available' : 'unavailable',
      }).eq('user_id', targetUserId);

      await supabaseClient.from('user_moderation_actions').insert({
        'target_user_id': targetUserId,
        'actor_id': actor.id,
        'action': status,
        'reason': reason,
        'created_at': DateTime.now().toIso8601String(),
      });

      final isRestricted = status == 'suspended' || status == 'blocked';
      await supabaseClient.from('notifications').insert({
        'user_id': targetUserId,
        'title': 'Account status updated',
        'body': isRestricted
            ? 'Your account has been ${status.replaceAll('_', ' ')}. You can appeal this decision.'
            : 'Your account status changed to ${status.replaceAll('_', ' ')}.',
        'type': 'system',
        'read': false,
        'data': {
          'action': isRestricted ? 'open_appeal' : 'open_notifications',
          'type': 'moderation',
          'subType': status,
          'reason': reason,
        },
        'created_at': DateTime.now().toIso8601String(),
      });

      return const Right(null);
    } on PostgrestException catch (e) {
      final message = e.message.toLowerCase();
      if (e.code == '42501' || message.contains('permission denied')) {
        return const Left(
          ServerFailure(
            message:
                'Permission denied updating users. Run play_store_compliance.sql to add admin update policy on users.',
          ),
        );
      }
      if (message.contains('moderation_status')) {
        return const Left(
          ServerFailure(
            message:
                'users.moderation_status is missing. Run play_store_compliance.sql in Supabase.',
          ),
        );
      }
      return Left(ServerFailure(message: 'Database error: ${e.message}'));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, PlatformAnalyticsEntity>> adminGetPlatformAnalytics() async {
    try {
      final totalUsersRes = await supabaseClient.from('users').select('id').count();
      final totalArtisansRes = await supabaseClient
          .from('users')
          .select('id')
          .eq('user_type', 'artisan')
          .count();
      final verifiedUsersRes = await supabaseClient
          .from('users')
          .select('id')
          .eq('verified', true)
          .count();
      final openDisputesRes = await supabaseClient
          .from('disputes')
          .select('id')
          .not('status', 'in', '(resolved_refund,resolved_release)')
          .count();
      final pendingReportsRes = await supabaseClient
          .from('reports')
          .select('id')
          .eq('status', 'reported')
          .count();

      final startOfDay = DateTime.now()
          .toLocal()
          .copyWith(hour: 0, minute: 0, second: 0, millisecond: 0)
          .toUtc()
          .toIso8601String();
      final bookingsTodayRes = await supabaseClient
          .from('bookings')
          .select('id')
          .gte('created_at', startOfDay)
          .count();

      return Right(
        PlatformAnalyticsEntity(
          totalUsers: totalUsersRes.count,
          totalArtisans: totalArtisansRes.count,
          verifiedUsers: verifiedUsersRes.count,
          openDisputes: openDisputesRes.count,
          pendingReports: pendingReportsRes.count,
          bookingsToday: bookingsTodayRes.count,
        ),
      );
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  Future<void> _logDisputeEvent({
    required String disputeId,
    required String actorId,
    required String eventType,
    String? note,
  }) async {
    await supabaseClient.from('dispute_events').insert({
      'dispute_id': disputeId,
      'actor_id': actorId,
      'event_type': eventType,
      'note': note,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> _notifyDisputeOpened({
    required String disputeId,
    required String bookingId,
    required String openedBy,
  }) async {
    try {
      final booking = await supabaseClient
          .from('bookings')
          .select('client_id,artisan_id')
          .eq('id', bookingId)
          .single();

      final clientId = booking['client_id'] as String?;
      final artisanId = booking['artisan_id'] as String?;
      final recipientIds = <String>{
        if (clientId != null) clientId,
        if (artisanId != null) artisanId,
      }..remove(openedBy);

      for (final recipientId in recipientIds) {
        await supabaseClient.from('notifications').insert({
          'user_id': recipientId,
          'title': 'Dispute opened',
          'body': 'A dispute was opened for one of your bookings.',
          'type': 'system',
          'read': false,
          'data': {
            'action': 'open_booking',
            'bookingId': bookingId,
            'type': 'dispute',
            'subType': 'opened',
            'relatedId': disputeId,
          },
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      final admins = await supabaseClient
          .from('users')
          .select('id')
          .eq('user_type', 'admin');
      for (final admin in (admins as List)) {
        final id = (admin as Map)['id']?.toString();
        if (id == null) continue;
        await supabaseClient.from('notifications').insert({
          'user_id': id,
          'title': 'New dispute opened',
          'body': 'A new dispute requires moderation review.',
          'type': 'system',
          'read': false,
          'data': {
            'action': 'open_notifications',
            'type': 'dispute',
            'subType': 'admin_new_dispute',
            'relatedId': disputeId,
          },
          'created_at': DateTime.now().toIso8601String(),
        });
      }
    } catch (_) {
      // Non-fatal for dispute opening flow.
    }
  }

  Future<void> _notifyDisputeUpdate({
    required String disputeId,
    required String title,
    required String body,
  }) async {
    try {
      final dispute = await supabaseClient
          .from('disputes')
          .select('booking_id')
          .eq('id', disputeId)
          .single();
      final bookingId = dispute['booking_id'] as String;

      final booking = await supabaseClient
          .from('bookings')
          .select('client_id,artisan_id')
          .eq('id', bookingId)
          .single();

      final recipientIds = <String>{
        if (booking['client_id'] != null) booking['client_id'] as String,
        if (booking['artisan_id'] != null) booking['artisan_id'] as String,
      };

      for (final recipientId in recipientIds) {
        await supabaseClient.from('notifications').insert({
          'user_id': recipientId,
          'title': title,
          'body': body,
          'type': 'system',
          'read': false,
          'data': {
            'action': 'open_booking',
            'bookingId': bookingId,
            'type': 'dispute',
            'relatedId': disputeId,
          },
          'created_at': DateTime.now().toIso8601String(),
        });
      }
    } catch (_) {
      // Ignore notification failure.
    }
  }

  // ---------------------------
  // Helpers
  // ---------------------------
  Future<String> _uploadImage({
    required String bucket,
    required String userId,
    required String filePath,
    required String prefix,
  }) async {
    await _ensureAuthSession();
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('File not found: $filePath');
    }
    final bytes = await file.readAsBytes();
    final extension = _fileExtension(filePath);
    final fileName =
        '${prefix}_${userId}_${DateTime.now().millisecondsSinceEpoch}.$extension';
    final storagePath = '$userId/$fileName';

    try {
      await supabaseClient.storage.from(bucket).uploadBinary(
            storagePath,
            bytes,
            fileOptions: FileOptions(
              contentType: _contentTypeForExtension(extension),
              upsert: true,
            ),
          );
    } catch (e) {
      print('❌ Storage upload failed (bucket=$bucket, path=$storagePath): $e');
      rethrow;
    }

    return supabaseClient.storage.from(bucket).getPublicUrl(storagePath);
  }

  Future<void> _ensureAuthSession() async {
    final session = supabaseClient.auth.currentSession;
    if (session != null) {
      return;
    }
    await supabaseClient.auth.refreshSession();
    final refreshed = supabaseClient.auth.currentSession;
    if (refreshed == null) {
      throw Exception('No active session for storage upload.');
    }
  }

  String _fileExtension(String path) {
    final parts = path.split('.');
    if (parts.length < 2) return 'jpg';
    return parts.last.toLowerCase();
  }

  String _contentTypeForExtension(String ext) {
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'heic':
        return 'image/heic';
      default:
        return 'image/jpeg';
    }
  }
}
