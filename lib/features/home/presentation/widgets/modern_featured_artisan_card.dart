// lib/features/home/presentation/widgets/modern_featured_artisan_card.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/artisan_entity.dart';

final featuredArtisanLiveRatingProvider =
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

class FeaturedArtisanCard extends ConsumerWidget {
  final ArtisanEntity artisan;

  const FeaturedArtisanCard({super.key, required this.artisan});

  String _formatDistance(double km) {
    if (km < 1) return '${(km * 1000).toInt()}m';
    if (km < 10) return '${km.toStringAsFixed(1)}km';
    return '${km.toInt()}km';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final isBusiness = artisan.userType == 'business';
    final liveRatingAsync =
        ref.watch(featuredArtisanLiveRatingProvider(artisan.userId));

    final cardSurface = isDark
        ? Color.alphaBlend(Colors.white.withOpacity(0.06), colorScheme.surface)
        : colorScheme.surface;

    return GestureDetector(
      onTap: () => context.push('/artisan/${artisan.userId}', extra: artisan),
      child: Container(
        width: 148,
        decoration: BoxDecoration(
          color: cardSurface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isDark
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.32),
                    blurRadius: 18,
                    offset: const Offset(0, 5),
                  ),
                ]
              : [
                  BoxShadow(
                    color: colorScheme.primary.withOpacity(0.07),
                    blurRadius: 22,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Image ──────────────────────────────────────────────────────
            Stack(
              children: [
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(18)),
                  child: SizedBox(
                    height: 110,
                    width: double.infinity,
                    child: artisan.photoUrl != null
                        ? Image.network(
                            artisan.photoUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _buildPlaceholder(colorScheme),
                          )
                        : _buildPlaceholder(colorScheme),
                  ),
                ),

                // Gradient scrim so name is legible if we ever overlay
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withOpacity(0.28),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),

                // Verified badge
                if (artisan.isVerified)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A73E8),
                        shape: BoxShape.circle,
                        border: Border.all(color: cardSurface, width: 1.5),
                      ),
                      child: const Icon(Icons.verified_rounded,
                          size: 10, color: Colors.white),
                    ),
                  ),
              ],
            ),

            // ── Info ───────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Name
                  Text(
                    artisan.name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface,
                      letterSpacing: -0.2,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),

                  // Category + business pill
                  Row(
                    children: [
                      Flexible(
                        fit: FlexFit.loose,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: _SmallCategoryPill(
                            label: artisan.category,
                            colorScheme: colorScheme,
                          ),
                        ),
                      ),
                      if (isBusiness) ...[
                        const SizedBox(width: 6),
                        _RolePill(label: 'Business', colorScheme: colorScheme),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Rating row
                  _SmallRatingRow(
                    rating: liveRatingAsync.maybeWhen(
                      data: (data) => data['rating'] as double,
                      orElse: () => artisan.rating,
                    ),
                    count: liveRatingAsync.maybeWhen(
                      data: (data) => data['reviewCount'] as int,
                      orElse: () => artisan.reviewCount,
                    ),
                    colorScheme: colorScheme,
                    theme: theme,
                  ),

                  // Distance
                  if (artisan.distance != null) ...[
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Icon(Icons.location_on_rounded,
                            size: 11,
                            color: colorScheme.primary.withOpacity(0.7)),
                        const SizedBox(width: 3),
                        Text(
                          '${_formatDistance(artisan.distance!)} away',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
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
            size: 44,
            color: colorScheme.onSurfaceVariant.withOpacity(0.35)),
      ),
    );
  }
}

// ── Sub-widgets ────────────────────────────────────────────────────────────────

class _SmallCategoryPill extends StatelessWidget {
  const _SmallCategoryPill(
      {required this.label, required this.colorScheme});
  final String label;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: colorScheme.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: colorScheme.primary,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _RolePill extends StatelessWidget {
  const _RolePill({required this.label, required this.colorScheme});

  final String label;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF2E7D32).withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF2E7D32),
          fontSize: 9,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _SmallRatingRow extends StatelessWidget {
  const _SmallRatingRow({
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
        const Icon(Icons.star_rounded, size: 12, color: Color(0xFFFFC107)),
        const SizedBox(width: 4),
        SizedBox(
          width: 30,
          height: 6,
          child: LinearProgressIndicator(
            minHeight: 2,
            color: colorScheme.primary.withOpacity(0.3),
            backgroundColor: colorScheme.surfaceContainerHighest,
          ),
        ),
      ]);
    }
    return Row(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.star_rounded, size: 12, color: Color(0xFFFFC107)),
      const SizedBox(width: 3),
      Text(
        rating!.toStringAsFixed(1),
        style: theme.textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: colorScheme.onSurface,
          fontSize: 11,
        ),
      ),
      const SizedBox(width: 3),
      Text(
        '(${count ?? 0})',
        style: theme.textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
          fontSize: 10,
        ),
      ),
    ]);
  }
}

class FeaturedHeroArtisanCard extends ConsumerWidget {
  const FeaturedHeroArtisanCard({
    super.key,
    required this.artisan,
    required this.isActive,
    this.accentIndex = 0,
  });

  final ArtisanEntity artisan;
  final bool isActive;
  final int accentIndex;

  static const List<List<Color>> _heroPalettes = [
    [Color(0xFF102542), Color(0xFF1B4D8C), Color(0xFF2A7DE1)],
    [Color(0xFF16311D), Color(0xFF236B36), Color(0xFF3BA85B)],
    [Color(0xFF4A1F15), Color(0xFF9B3D20), Color(0xFFE17E33)],
    [Color(0xFF3B174B), Color(0xFF7B2CBF), Color(0xFFC77DFF)],
  ];

  String _formatDistance(double km) {
    if (km < 1) return '${(km * 1000).toInt()}m away';
    if (km < 10) return '${km.toStringAsFixed(1)}km away';
    return '${km.toInt()}km away';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final liveRatingAsync =
        ref.watch(featuredArtisanLiveRatingProvider(artisan.userId));
    final palette = _heroPalettes[accentIndex % _heroPalettes.length];
    final titleLabel = artisan.userType == 'business'
        ? 'Business Spotlight'
        : 'Artisan Spotlight';

    return AnimatedSlide(
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
      offset: isActive ? Offset.zero : const Offset(0.08, 0),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeOutCubic,
        scale: isActive ? 1 : 0.97,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 320),
          opacity: isActive ? 1 : 0.82,
          child: GestureDetector(
            onTap: () => context.push('/artisan/${artisan.userId}', extra: artisan),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 390;
                final metricChips = <Widget>[
                  liveRatingAsync.maybeWhen(
                    data: (data) => _HeroMetricChip(
                      icon: Icons.star_rounded,
                      label:
                          '${(data['rating'] as double).toStringAsFixed(1)} (${data['reviewCount']})',
                    ),
                    orElse: () => _HeroMetricChip(
                      icon: Icons.star_rounded,
                      label:
                          '${artisan.rating.toStringAsFixed(1)} (${artisan.reviewCount})',
                    ),
                  ),
                  if (artisan.distance != null)
                    _HeroMetricChip(
                      icon: Icons.near_me_rounded,
                      label: _formatDistance(artisan.distance!),
                    ),
                  _HeroMetricChip(
                    icon: artisan.userType == 'business'
                        ? Icons.groups_rounded
                        : Icons.handyman_rounded,
                    label: artisan.userType == 'business'
                        ? 'Business profile'
                        : 'Top provider',
                  ),
                ];

                return Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: palette,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: palette.last.withOpacity(0.28),
                        blurRadius: 24,
                        offset: const Offset(0, 14),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        top: -34,
                        right: -10,
                        child: Container(
                          width: isCompact ? 104 : 128,
                          height: isCompact ? 104 : 128,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.09),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: -46,
                        left: -22,
                        child: Container(
                          width: isCompact ? 120 : 146,
                          height: isCompact ? 120 : 146,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      Positioned(
                        top: isCompact ? 24 : 34,
                        right: isCompact ? 112 : 148,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.16),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          isCompact ? 16 : 20,
                          isCompact ? 16 : 20,
                          isCompact ? 16 : 18,
                          isCompact ? 16 : 18,
                        ),
                        child: isCompact
                            ? _buildCompactHeroLayout(
                                theme: theme,
                                colorScheme: colorScheme,
                                titleLabel: titleLabel,
                                metricChips: metricChips,
                              )
                            : _buildWideHeroLayout(
                                theme: theme,
                                colorScheme: colorScheme,
                                titleLabel: titleLabel,
                                metricChips: metricChips,
                              ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWideHeroLayout({
    required ThemeData theme,
    required ColorScheme colorScheme,
    required String titleLabel,
    required List<Widget> metricChips,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _HeroBadge(
                    icon: Icons.auto_awesome_rounded,
                    label: titleLabel,
                  ),
                  if (artisan.isVerified)
                    const _HeroBadge(
                      icon: Icons.verified_rounded,
                      label: 'Verified',
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                artisan.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.8,
                  height: 1.04,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                artisan.category,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: Colors.white.withOpacity(0.9),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: metricChips,
              ),
              const Spacer(),
              _buildHeroCta(colorScheme),
            ],
          ),
        ),
        const SizedBox(width: 12),
        _buildHeroImage(width: 110, height: 152),
      ],
    );
  }

  Widget _buildCompactHeroLayout({
    required ThemeData theme,
    required ColorScheme colorScheme,
    required String titleLabel,
    required List<Widget> metricChips,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            const _HeroBadge(
              icon: Icons.auto_awesome_rounded,
              label: 'Spotlight',
            ),
            if (artisan.isVerified)
              const _HeroBadge(
                icon: Icons.verified_rounded,
                label: 'Verified',
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    artisan.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.6,
                      height: 1.05,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    artisan.category,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: Colors.white.withOpacity(0.9),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    titleLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white.withOpacity(0.78),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            _buildHeroImage(width: 105, height: 125),
          ],
        ),
        const SizedBox(height: 8),
        ClipRect(
          child: SizedBox(
            height: 28,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: metricChips.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (_, index) => metricChips[index],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeroCta(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.white.withOpacity(0.18),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'View profile',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 6),
          Icon(
            Icons.arrow_forward_rounded,
            size: 16,
            color: colorScheme.onPrimary,
          ),
        ],
      ),
    );
  }

  Widget _buildHeroImage({
    required double width,
    required double height,
  }) {
    return SizedBox(
      width: width,
      child: Align(
        alignment: Alignment.centerRight,
        child: Hero(
          tag: 'featured-hero-${artisan.userId}',
          child: Container(
            height: height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: Colors.white.withOpacity(0.18),
              border: Border.all(
                color: Colors.white.withOpacity(0.16),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 12,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: artisan.photoUrl != null
                  ? Image.network(
                      artisan.photoUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildHeroPlaceholder(),
                    )
                  : _buildHeroPlaceholder(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroPlaceholder() {
    return Container(
      color: Colors.white.withOpacity(0.1),
      alignment: Alignment.center,
      child: const Icon(
        Icons.person_rounded,
        size: 56,
        color: Colors.white70,
      ),
    );
  }
}

class _HeroBadge extends StatelessWidget {
  const _HeroBadge({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 180),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.16),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withOpacity(0.14)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: Colors.white),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroMetricChip extends StatelessWidget {
  const _HeroMetricChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 140),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: Colors.white),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
