import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../booking/presentation/providers/booking_provider.dart';
import '../../../reviews/presentation/providers/review_provider.dart';
import '../providers/profile_view_analytics_provider.dart';
import '../providers/user_profile_provider.dart';

class ProfileAnalyticsScreen extends ConsumerStatefulWidget {
  const ProfileAnalyticsScreen({super.key});

  @override
  ConsumerState<ProfileAnalyticsScreen> createState() =>
      _ProfileAnalyticsScreenState();
}

class _ProfileAnalyticsScreenState
    extends ConsumerState<ProfileAnalyticsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAnalytics());
  }

  void _loadAnalytics() {
    final user = ref.read(authProvider).user;
    if (user == null) {
      return;
    }
    ref.read(userProfileProvider.notifier).loadUserProfile(
          userId: user.id,
          userType: user.userType,
        );
    ref.read(bookingProvider.notifier).loadUserBookings(
          userId: user.id,
          userType: user.userType,
        );
    ref.read(bookingProvider.notifier).loadBookingStats(
          userId: user.id,
          userType: user.userType,
        );
    ref.invalidate(profileViewAnalyticsProvider);
    if (user.isArtisan) {
      ref.read(reviewProvider.notifier).loadArtisanReviews(user.id);
    } else {
      ref.read(reviewProvider.notifier).loadUserReviews(user.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final user = ref.watch(authProvider).user;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please sign in to view analytics.')),
      );
    }

    final profileState = ref.watch(userProfileProvider);
    final bookingState = ref.watch(bookingProvider);
    final reviewState = ref.watch(reviewProvider);
    final profileViewsAsync = ref.watch(profileViewAnalyticsProvider);
    final profileViews =
        profileViewsAsync.valueOrNull ?? const ProfileViewAnalyticsSummary.empty();
    final stats = profileState.stats ?? const <String, dynamic>{};

    final totalBookings = (stats['totalBookings'] as int?) ??
        bookingState.stats?['total'] ??
        bookingState.bookings.length;
    final completedBookings =
        (stats['completedBookings'] as int?) ?? bookingState.stats?['completed'] ?? 0;
    final pendingBookings =
        (stats['pendingBookings'] as int?) ?? bookingState.stats?['pending'] ?? 0;
    final cancelledBookings =
        (stats['cancelledBookings'] as int?) ?? bookingState.stats?['cancelled'] ?? 0;
    final reviewsCount = reviewState.reviews.length;
    final averageRating = reviewsCount == 0
        ? 0.0
        : reviewState.reviews
                .fold<double>(0, (sum, review) => sum + review.rating) /
            reviewsCount;
    final completionRate =
        totalBookings == 0 ? 0.0 : completedBookings / totalBookings;

    final chartData = <_ChartPoint>[
      _ChartPoint('Views', profileViews.totalViews, const Color(0xFF00897B)),
      _ChartPoint('Viewers', profileViews.uniqueViewers, const Color(0xFF5E35B1)),
      _ChartPoint('Completed', completedBookings, const Color(0xFF2E7D32)),
      _ChartPoint('Pending', pendingBookings, const Color(0xFFF9A825)),
      _ChartPoint('Cancelled', cancelledBookings, const Color(0xFFC62828)),
      _ChartPoint(
        user.isArtisan ? 'Reviews' : 'Feedback',
        reviewsCount,
        const Color(0xFF6A1B9A),
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('My Analytics')),
      body: RefreshIndicator(
        onRefresh: () async => _loadAnalytics(),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: user.isBusiness
                      ? const [Color(0xFF1B5E20), Color(0xFF2E7D32)]
                      : user.isArtisan
                          ? const [Color(0xFF0D47A1), Color(0xFF1565C0)]
                          : const [Color(0xFF4A148C), Color(0xFF6A1B9A)],
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Performance snapshot',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Everything is on one page. Expand a section when you want the deeper detail.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withOpacity(0.92),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: _HeroMetric(
                          label: 'Completion Rate',
                          value: '${(completionRate * 100).round()}%',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _HeroMetric(
                          label: 'Profile Views',
                          value: '${profileViews.totalViews}',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _ChartCard(data: chartData),
            const SizedBox(height: 12),
            _ExpansionCard(
              title: 'Booking breakdown',
              subtitle: 'Tap to unfold booking counts and quick reading',
              child: Column(
                children: [
                  _MetricRow(label: 'Total bookings', value: '$totalBookings'),
                  _MetricRow(label: 'Completed', value: '$completedBookings'),
                  _MetricRow(label: 'Pending', value: '$pendingBookings'),
                  _MetricRow(label: 'Cancelled', value: '$cancelledBookings'),
                  const SizedBox(height: 8),
                  Text(
                    'A strong completion rate usually means tighter communication and fewer abandoned jobs.',
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _ExpansionCard(
              title: 'Profile reach',
              subtitle: 'Tap to unfold profile view totals and audience activity',
              child: Column(
                children: [
                  _MetricRow(label: 'Total profile views', value: '${profileViews.totalViews}'),
                  _MetricRow(label: 'Unique viewers', value: '${profileViews.uniqueViewers}'),
                  _MetricRow(label: 'Anonymous views', value: '${profileViews.anonymousViews}'),
                  _MetricRow(
                    label: 'Last profile view',
                    value: _formatViewedAt(profileViews.lastViewedAt),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This helps you see whether your profile is being discovered, even before a chat or booking starts.',
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _ExpansionCard(
              title: 'Quality signals',
              subtitle: 'Tap to unfold ratings and reputation details',
              child: Column(
                children: [
                  _MetricRow(
                    label: user.isArtisan ? 'Average rating' : 'Reviews',
                    value: user.isArtisan
                        ? averageRating.toStringAsFixed(1)
                        : '$reviewsCount',
                  ),
                  _MetricRow(label: 'Review count', value: '$reviewsCount'),
                  const SizedBox(height: 8),
                  Text(
                    user.isArtisan
                        ? 'Ask for reviews right after a completed job while the experience is still fresh.'
                        : 'Your feedback history becomes a useful record when comparing providers for repeat work.',
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _ExpansionCard(
              title: profileViews.canSeeViewers
                  ? 'Who viewed your profile'
                  : 'Viewer identities',
              subtitle: profileViews.canSeeViewers
                  ? 'Tap to unfold recent premium viewer insights'
                  : 'Tap to see how premium viewer insights work',
              child: profileViews.canSeeViewers
                  ? _ViewerList(
                      viewers: profileViews.viewers,
                      emptyLabel:
                          'You have view counts already. Named viewers will appear here as more signed-in users visit.',
                    )
                  : Text(
                      'Viewer names are available on premium profiles. Your total view count still updates for every profile.',
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                    ),
            ),
            const SizedBox(height: 12),
            _ExpansionCard(
              title: 'Action notes',
              subtitle: 'Tap to unfold suggestions based on your activity',
              child: Text(
                user.isArtisan
                    ? 'Focus on improving two things together: profile reach and booking completion. More views tell you discovery is working; more completed jobs tell you conversion is improving.'
                    : 'Use invoices and reviews together: invoices help keep records clean, and reviews help you remember which providers delivered well.',
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
              ),
            ),
            if (profileState.isLoading || bookingState.isLoading || profileViewsAsync.isLoading) ...[
              const SizedBox(height: 20),
              const Center(child: CircularProgressIndicator()),
            ],
            if (profileState.error != null) ...[
              const SizedBox(height: 20),
              Text(
                profileState.error!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.error,
                ),
              ),
            ],
            if (profileViewsAsync.hasError) ...[
              const SizedBox(height: 12),
              Text(
                'Profile view analytics could not be loaded right now.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ChartPoint {
  const _ChartPoint(this.label, this.value, this.color);

  final String label;
  final int value;
  final Color color;
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white)),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.data});

  final List<_ChartPoint> data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Visual summary',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'A quick chart of the activity that matters most right now.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 190,
            child: CustomPaint(
              painter: _BarChartPainter(data),
              child: const SizedBox.expand(),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpansionCard extends StatelessWidget {
  const _ExpansionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
          childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          title: Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          subtitle: Text(subtitle),
          children: [child],
        ),
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
          Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ViewerList extends StatelessWidget {
  const _ViewerList({
    required this.viewers,
    required this.emptyLabel,
  });

  final List<ProfileViewerSummary> viewers;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    if (viewers.isEmpty) {
      return Text(
        emptyLabel,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.45),
      );
    }

    return Column(
      children: viewers
          .take(8)
          .map((viewer) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundImage: viewer.viewerPhotoUrl != null &&
                              viewer.viewerPhotoUrl!.isNotEmpty
                          ? NetworkImage(viewer.viewerPhotoUrl!)
                          : null,
                      child: viewer.viewerPhotoUrl == null ||
                              viewer.viewerPhotoUrl!.isEmpty
                          ? Text(
                              viewer.viewerName.isNotEmpty
                                  ? viewer.viewerName.substring(0, 1).toUpperCase()
                                  : '?',
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            viewer.viewerName,
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            [
                              if (viewer.viewerUserType != null &&
                                  viewer.viewerUserType!.isNotEmpty)
                                viewer.viewerUserType!,
                              '${viewer.totalViews} view${viewer.totalViews == 1 ? '' : 's'}',
                              _formatViewedAt(viewer.lastViewedAt),
                            ].join(' • '),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ))
          .toList(),
    );
  }
}

String _formatViewedAt(DateTime? value) {
  if (value == null) {
    return 'No recent activity';
  }
  return timeago.format(value.toLocal());
}

class _BarChartPainter extends CustomPainter {
  _BarChartPainter(this.data);

  final List<_ChartPoint> data;

  @override
  void paint(Canvas canvas, Size size) {
    final maxValue = math.max(1, data.fold<int>(0, (max, item) => item.value > max ? item.value : max));
    final labelPainter = TextPainter(textDirection: TextDirection.ltr);
    final barWidth = size.width / (data.length * 2);
    final chartHeight = size.height - 36;
    final baseY = chartHeight;

    final axisPaint = Paint()
      ..color = const Color(0x22000000)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, baseY), Offset(size.width, baseY), axisPaint);

    for (var i = 0; i < data.length; i++) {
      final point = data[i];
      final left = (i * 2 + 0.5) * barWidth;
      final heightFactor = point.value / maxValue;
      final barHeight = chartHeight * heightFactor;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, baseY - barHeight, barWidth, barHeight),
        const Radius.circular(10),
      );
      final barPaint = Paint()..color = point.color;
      canvas.drawRRect(rect, barPaint);

      labelPainter.text = TextSpan(
        text: point.label,
        style: const TextStyle(fontSize: 10, color: Color(0xFF607D8B)),
      );
      labelPainter.layout(maxWidth: barWidth * 2);
      labelPainter.paint(
        canvas,
        Offset(left - (barWidth / 2), size.height - 18),
      );

      final valuePainter = TextPainter(
        text: TextSpan(
          text: '${point.value}',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: point.color,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: barWidth * 2);
      valuePainter.paint(
        canvas,
        Offset(left - (barWidth / 4), math.max(0, baseY - barHeight - 18)),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BarChartPainter oldDelegate) {
    return oldDelegate.data != data;
  }
}
