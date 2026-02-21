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

      // Check if user is an artisan
      final artisanCheck = await supabaseClient
          .from('artisan_profiles')
          .select('user_id')
          .eq('user_id', userId)
          .maybeSingle();
      
      final isArtisan = artisanCheck != null;
      print('   User Type: ${isArtisan ? "ARTISAN" : "CUSTOMER"}');

      // Update verification status in identity_verifications table
      await supabaseClient.from('identity_verifications').update({
        'status': status,
        'reviewed_at': DateTime.now().toIso8601String(),
        'rejection_reason': rejectionReason,
      }).eq('id', verificationId);
      
      print('✅ Verification status updated in identity_verifications');

      // ✅ UNIVERSAL UPDATE: Update users.verified for ALL users (artisans AND customers)
      if (status == 'verified') {
        print('🔄 Setting user as verified in users table...');
        
        final userUpdateResult = await supabaseClient
            .from('users')
            .update({'verified': true})
            .eq('id', userId)
            .select();
        
        print('✅ Users table updated: ${userUpdateResult.length} rows');
        
        // Also update artisan_profiles if user is an artisan
        if (isArtisan) {
          print('🔄 Setting artisan profile as verified...');
          
          final artisanUpdateResult = await supabaseClient
              .from('artisan_profiles')
              .update({'verified': true})
              .eq('user_id', userId)
              .select();
          
          print('✅ Artisan profile updated: ${artisanUpdateResult.length} rows');
        }
        
      } else if (status == 'rejected') {
        print('🔄 Removing verification from users table...');
        
        final userUpdateResult = await supabaseClient
            .from('users')
            .update({'verified': false})
            .eq('id', userId)
            .select();
        
        print('✅ Users table updated: ${userUpdateResult.length} rows');
        
        // Also update artisan_profiles if user is an artisan
        if (isArtisan) {
          print('🔄 Removing verification from artisan profile...');
          
          final artisanUpdateResult = await supabaseClient
              .from('artisan_profiles')
              .update({'verified': false})
              .eq('user_id', userId)
              .select();
          
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
      
      if (status == 'verified' && userVerified != true) {
        print('❌ WARNING: Verification status not synced to users table!');
        throw Exception('Failed to sync verification status to users table');
      }
      
      // If artisan, also verify artisan_profiles was updated
      if (isArtisan) {
        final artisanCheckResult = await supabaseClient
            .from('artisan_profiles')
            .select('verified')
            .eq('user_id', userId)
            .maybeSingle();
        
        if (artisanCheckResult != null) {
          final artisanVerified = artisanCheckResult['verified'] as bool?;
          print('📊 Final verification status in artisan_profiles: $artisanVerified');
          
          if (status == 'verified' && artisanVerified != true) {
            print('❌ WARNING: Verification status not synced to artisan_profiles!');
            throw Exception('Failed to sync verification status to artisan_profiles');
          }
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

      print('✅ Dispute created successfully');

      // Mark booking as disputed for UI visibility
      await supabaseClient
          .from('bookings')
          .update({'status': 'disputed', 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', bookingId);

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
