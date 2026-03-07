// lib/features/home/presentation/widgets/modern_featured_artisan_card.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../domain/entities/artisan_entity.dart';

class FeaturedArtisanCard extends StatelessWidget {
  final ArtisanEntity artisan;

  const FeaturedArtisanCard({super.key, required this.artisan});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final cardSurface = isDark
        ? Color.alphaBlend(Colors.white.withOpacity(0.06), colorScheme.surface)
        : colorScheme.surface;

    return GestureDetector(
      onTap: () => context.push('/artisan/${artisan.userId}', extra: artisan),
      child: Container(
        width: 148,
        decoration: BoxDecoration(
          color: cardSurface,
          borderRadius: BorderRadius.circular(18),
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

                  // Category pill
                  _SmallCategoryPill(
                    label: artisan.category,
                    colorScheme: colorScheme,
                  ),
                  const SizedBox(height: 6),

                  // Rating row
                  _SmallRatingRow(
                    rating: artisan.rating,
                    count: artisan.reviewCount,
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
                          '${artisan.distance!.toStringAsFixed(1)}km away',
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
