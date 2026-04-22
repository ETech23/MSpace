import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../auth/presentation/providers/auth_provider.dart';

class ProfileViewerSummary {
  const ProfileViewerSummary({
    required this.viewerUserId,
    required this.viewerName,
    this.viewerPhotoUrl,
    this.viewerUserType,
    required this.totalViews,
    this.lastViewedAt,
  });

  final String viewerUserId;
  final String viewerName;
  final String? viewerPhotoUrl;
  final String? viewerUserType;
  final int totalViews;
  final DateTime? lastViewedAt;

  factory ProfileViewerSummary.fromJson(Map<String, dynamic> json) {
    return ProfileViewerSummary(
      viewerUserId: json['viewer_user_id']?.toString() ?? '',
      viewerName: json['viewer_name']?.toString() ?? 'Anonymous viewer',
      viewerPhotoUrl: json['viewer_photo_url']?.toString(),
      viewerUserType: json['viewer_user_type']?.toString(),
      totalViews: (json['total_views'] as num?)?.toInt() ?? 0,
      lastViewedAt: json['last_viewed_at'] == null
          ? null
          : DateTime.tryParse(json['last_viewed_at'].toString()),
    );
  }
}

class ProfileViewAnalyticsSummary {
  const ProfileViewAnalyticsSummary({
    required this.totalViews,
    required this.uniqueViewers,
    required this.anonymousViews,
    required this.canSeeViewers,
    this.lastViewedAt,
    this.viewers = const [],
  });

  final int totalViews;
  final int uniqueViewers;
  final int anonymousViews;
  final bool canSeeViewers;
  final DateTime? lastViewedAt;
  final List<ProfileViewerSummary> viewers;

  const ProfileViewAnalyticsSummary.empty()
      : totalViews = 0,
        uniqueViewers = 0,
        anonymousViews = 0,
        canSeeViewers = false,
        lastViewedAt = null,
        viewers = const [];
}

final profileViewAnalyticsProvider =
    FutureProvider<ProfileViewAnalyticsSummary>((ref) async {
  final user = ref.watch(authProvider).user;
  if (user == null) {
    return const ProfileViewAnalyticsSummary.empty();
  }

  final supabase = Supabase.instance.client;
  Map<String, dynamic> summaryMap;
  try {
    final summaryResponse = await supabase.rpc(
      'get_my_profile_view_summary',
      params: {'p_profile_user_id': user.id},
    );
    summaryMap = _asStringKeyedMap(summaryResponse);
  } catch (_) {
    return const ProfileViewAnalyticsSummary.empty();
  }

  final canSeeViewers = summaryMap['can_see_viewers'] == true;

  var viewers = const <ProfileViewerSummary>[];
  if (canSeeViewers) {
    try {
      final viewersResponse = await supabase.rpc(
        'get_my_profile_viewers',
        params: {'p_profile_user_id': user.id},
      );
      viewers = ((viewersResponse as List?) ?? const [])
          .whereType<Map>()
          .map((row) => row.map(
                (key, value) => MapEntry(key.toString(), value),
              ))
          .map(ProfileViewerSummary.fromJson)
          .where((viewer) => viewer.viewerUserId.isNotEmpty)
          .toList();
    } catch (_) {
      viewers = const [];
    }
  }

  return ProfileViewAnalyticsSummary(
    totalViews: (summaryMap['total_views'] as num?)?.toInt() ?? 0,
    uniqueViewers: (summaryMap['unique_viewers'] as num?)?.toInt() ?? 0,
    anonymousViews: (summaryMap['anonymous_views'] as num?)?.toInt() ?? 0,
    canSeeViewers: canSeeViewers,
    lastViewedAt: summaryMap['last_viewed_at'] == null
        ? null
        : DateTime.tryParse(summaryMap['last_viewed_at'].toString()),
    viewers: viewers,
  );
});

Map<String, dynamic> _asStringKeyedMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, val) => MapEntry(key.toString(), val));
  }
  return <String, dynamic>{};
}
