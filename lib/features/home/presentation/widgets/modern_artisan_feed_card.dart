// lib/features/home/presentation/widgets/modern_artisan_feed_card.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/artisan_entity.dart';

final artisanLiveCategoryProvider =
    FutureProvider.family<String, String>((ref, artisanId) async {
  try {
    final supabase = Supabase.instance.client;
    final response = await supabase
        .from('artisan_profiles')
        .select('category')
        .eq('user_id', artisanId)
        .single();
    return response['category'] as String? ?? 'General';
  } catch (e) {
    return 'General';
  }
});

final artisanLiveRatingProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, artisanId) async {
  final supabase = Supabase.instance.client;
  final response = await supabase
      .from('reviews')
      .select('rating')
      .eq('artisan_id', artisanId);
  final reviewCount = response.length;
  double avgRating = 0.0;
  if (reviewCount > 0) {
    avgRating = response
            .map((r) => (r['rating'] as num).toDouble())
            .reduce((a, b) => a + b) /
        reviewCount;
  }
  return {'rating': avgRating, 'reviewCount': reviewCount};
});

class ArtisanFeedCard extends ConsumerWidget {
  final ArtisanEntity artisan;

  const ArtisanFeedCard({super.key, required this.artisan});

  String _formatDistance(double km) {
    if (km < 1) return '${(km * 1000).toInt()}m';
    if (km < 10) return '${km.toStringAsFixed(1)}km';
    return '${km.toInt()}km';
  }

  String? _getShortAddress(String? fullAddress) {
    if (fullAddress == null || fullAddress.isEmpty) return null;
    final parts = fullAddress.split(',').map((e) => e.trim()).toList();
    if (parts.length >= 3) return '${parts[parts.length - 3]}, ${parts[parts.length - 2]}';
    if (parts.length >= 2) return parts[parts.length - 2];
    return parts.first;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final shortAddress = _getShortAddress(artisan.address);

    final liveRatingAsync = ref.watch(artisanLiveRatingProvider(artisan.userId));
    final liveCategoryAsync = ref.watch(artisanLiveCategoryProvider(artisan.userId));

    // Card surface — slightly lifted from page background
    final cardSurface = isDark
        ? Color.alphaBlend(Colors.white.withOpacity(0.05), colorScheme.surface)
        : colorScheme.surface;

    return GestureDetector(
      onTap: () => context.push('/artisan/${artisan.userId}', extra: artisan),
      child: Container(
        decoration: BoxDecoration(
          color: cardSurface,
          borderRadius: BorderRadius.circular(18),
          boxShadow: isDark
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 18,
                    offset: const Offset(0, 5),
                  ),
                ]
              : [
                  BoxShadow(
                    color: colorScheme.primary.withOpacity(0.05),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Profile Image ──────────────────────────────────────────────
            Stack(
              children: [
                Container(
                  width: 95,
                  height: 95,
                  margin: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: colorScheme.surfaceContainerHighest,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: artisan.photoUrl != null
                        ? Image.network(
                            artisan.photoUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _buildPlaceholder(colorScheme),
                          )
                        : _buildPlaceholder(colorScheme),
                  ),
                ),
                if (artisan.isVerified)
                  Positioned(
                    top: 8,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A73E8),
                        shape: BoxShape.circle,
                        border: Border.all(color: cardSurface, width: 1.5),
                      ),
                      child: const Icon(Icons.verified_rounded,
                          size: 11, color: Colors.white),
                    ),
                  ),
              ],
            ),

            // ── Content ────────────────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 12, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name + featured star
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            artisan.name,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: colorScheme.onSurface,
                              letterSpacing: -0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (artisan.isFeatured) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.star_rounded,
                              size: 14, color: Color(0xFFFFC107)),
                        ],
                      ],
                    ),
                    const SizedBox(height: 5),

                    // Category pill
                    liveCategoryAsync.when(
                      data: (cat) => _CategoryPill(label: cat, colorScheme: colorScheme),
                      loading: () => _CategoryPill(label: '...', colorScheme: colorScheme),
                      error: (_, __) => _CategoryPill(label: artisan.category, colorScheme: colorScheme),
                    ),
                    const SizedBox(height: 7),

                    // Location
                    if (artisan.distance != null || shortAddress != null)
                      Row(
                        children: [
                          Icon(Icons.location_on_rounded,
                              size: 12, color: colorScheme.primary.withOpacity(0.7)),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              [
                                if (artisan.distance != null)
                                  _formatDistance(artisan.distance!),
                                if (shortAddress != null) shortAddress,
                              ].join(' · '),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),

                    // Bio
                    if (artisan.bio != null) ...[
                      const SizedBox(height: 5),
                      Text(
                        artisan.bio!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 11,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 8),

                    // Rating + CTA
                    Row(
                      children: [
                        liveRatingAsync.when(
                          data: (data) => _RatingRow(
                            rating: data['rating'] as double,
                            count: data['reviewCount'] as int,
                            colorScheme: colorScheme,
                            theme: theme,
                          ),
                          loading: () => _RatingRow(
                            rating: null,
                            count: null,
                            colorScheme: colorScheme,
                            theme: theme,
                          ),
                          error: (_, __) => _RatingRow(
                            rating: artisan.rating,
                            count: artisan.reviewCount,
                            colorScheme: colorScheme,
                            theme: theme,
                          ),
                        ),
                        const Spacer(),
                        _ViewButton(colorScheme: colorScheme),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder(ColorScheme colorScheme) {
    return Container(
      color: colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(Icons.person_rounded,
            size: 36, color: colorScheme.onSurfaceVariant.withOpacity(0.4)),
      ),
    );
  }
}

// ── Shared sub-widgets ─────────────────────────────────────────────────────────

class _CategoryPill extends StatelessWidget {
  const _CategoryPill({required this.label, required this.colorScheme});
  final String label;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colorScheme.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: colorScheme.primary,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _RatingRow extends StatelessWidget {
  const _RatingRow({
    required this.rating,
    required this.count,
    required this.colorScheme,
    required this.theme,
  });
  final double? rating;
  final int? count;
  final ColorScheme colorScheme;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    if (rating == null) {
      return Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.star_rounded, size: 13, color: Color(0xFFFFC107)),
        const SizedBox(width: 5),
        SizedBox(
          width: 36,
          height: 8,
          child: LinearProgressIndicator(
            minHeight: 2,
            color: colorScheme.primary.withOpacity(0.3),
            backgroundColor: colorScheme.surfaceContainerHighest,
          ),
        ),
      ]);
    }
    return Row(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.star_rounded, size: 13, color: Color(0xFFFFC107)),
      const SizedBox(width: 3),
      Text(
        rating!.toStringAsFixed(1),
        style: theme.textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: colorScheme.onSurface,
          fontSize: 12,
        ),
      ),
      const SizedBox(width: 3),
      Text(
        '(${count ?? 0})',
        style: theme.textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
          fontSize: 11,
        ),
      ),
    ]);
  }
}

class _ViewButton extends StatelessWidget {
  const _ViewButton({required this.colorScheme});
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: colorScheme.primary,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'View',
            style: TextStyle(
              color: colorScheme.onPrimary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(width: 3),
          Icon(Icons.arrow_forward_rounded,
              size: 12, color: colorScheme.onPrimary),
        ],
      ),
    );
  }
}