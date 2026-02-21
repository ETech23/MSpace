// lib/features/home/presentation/widgets/modern_featured_artisan_card.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/artisan_entity.dart';

// ✅ Provider to fetch live category for featured artisan
final featuredArtisanLiveCategoryProvider =
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
    print('Error fetching category: $e');
    return 'General';
  }
});

// ✅ Provider to fetch live rating for featured artisan
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

  return {
    'rating': avgRating,
    'reviewCount': reviewCount,
  };
});

class FeaturedArtisanCard extends ConsumerWidget {
  final ArtisanEntity artisan;

  const FeaturedArtisanCard({
    super.key,
    required this.artisan,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    // ✅ Watch live category and rating
    final liveCategoryAsync = ref.watch(featuredArtisanLiveCategoryProvider(artisan.userId));
    final liveRatingAsync = ref.watch(featuredArtisanLiveRatingProvider(artisan.userId));

    return GestureDetector(
      onTap: () {
        context.push('/artisan/${artisan.userId}', extra: artisan);
      },
      child: Container(
        width: 150,
        //margin: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
          color: colorScheme.outlineVariant.withOpacity(0.5),
          width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 15,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Section
            Stack(
              children: [
                Container(
                  height: 100,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                    gradient: LinearGradient(
                      colors: [
                        colorScheme.primaryContainer.withOpacity(0.4),
                        colorScheme.secondaryContainer.withOpacity(0.4),
                      ],
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                    child: artisan.photoUrl != null
                        ? Image.network(
                            artisan.photoUrl!,
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _buildPlaceholder(colorScheme),
                          )
                        : _buildPlaceholder(colorScheme),
                  ),
                ),
                // Premium Badge
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    
                    
                  ),
                ),
                // Verified Badge
                if (artisan.isVerified)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.verified,
                        size: 10,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),

            // Content Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name
                  Text(
                    artisan.name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface,
                    ),

                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),

                  // ✅ Live Category
                  liveCategoryAsync.when(
                    data: (category) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        category,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    loading: () => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const SizedBox(
                        width: 80,
                        height: 14,
                        child: LinearProgressIndicator(minHeight: 2),
                      ),
                    ),
                    error: (_, __) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        artisan.category,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),

                  // ✅ Live Rating
                  liveRatingAsync.when(
                    data: (ratingData) {
                      final rating = ratingData['rating'] as double;
                      final reviewCount = ratingData['reviewCount'] as int;
                      
                      return Row(
                        children: [
                          Icon(
                            Icons.star,
                            size: 18,
                            color: Colors.amber[700],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            rating.toStringAsFixed(1),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '($reviewCount reviews)',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      );
                    },
                    loading: () => Row(
                      children: [
                        Icon(
                          Icons.star,
                          size: 18,
                          color: Colors.amber[700],
                        ),
                        const SizedBox(width: 8),
                        const SizedBox(
                          width: 60,
                          height: 14,
                          child: LinearProgressIndicator(minHeight: 2),
                        ),
                      ],
                    ),
                    error: (_, __) => Row(
                      children: [
                        Icon(
                          Icons.star,
                          size: 18,
                          color: Colors.amber[700],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          artisan.rating.toStringAsFixed(1),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '(${artisan.reviewCount} reviews)',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Location
                  if (artisan.distance != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 16,
                          color: colorScheme.secondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${artisan.distance!.toStringAsFixed(1)}km away',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.secondary,
                            fontWeight: FontWeight.w500,
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
        child: Icon(
          Icons.person,
          size: 60,
          color: colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}