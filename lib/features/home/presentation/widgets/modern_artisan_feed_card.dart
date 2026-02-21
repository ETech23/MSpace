// lib/features/home/presentation/widgets/modern_artisan_feed_card.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/artisan_entity.dart';

// ✅ Provider to fetch live category for an artisan
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
    print('Error fetching category: $e');
    return 'General';
  }
});

// ✅ Provider to fetch live rating for an artisan
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

  return {
    'rating': avgRating,
    'reviewCount': reviewCount,
  };
});


class ArtisanFeedCard extends ConsumerWidget {
  final ArtisanEntity artisan;

  const ArtisanFeedCard({
    super.key,
    required this.artisan,
  });

  String _formatDistance(double km) {
    if (km < 1) {
      return '${(km * 1000).toInt()}m';
    } else if (km < 10) {
      return '${km.toStringAsFixed(1)}km';
    } else {
      return '${km.toInt()}km';
    }
  }

  String? _getShortAddress(String? fullAddress) {
    if (fullAddress == null || fullAddress.isEmpty) return null;
    
    final parts = fullAddress.split(',').map((e) => e.trim()).toList();
    
    if (parts.length >= 2) {
      if (parts.length >= 3) {
        return '${parts[parts.length - 3]}, ${parts[parts.length - 2]}';
      }
      return parts[parts.length - 2];
    }
    
    return parts.first;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final shortAddress = _getShortAddress(artisan.address);
    
    // ✅ Watch live rating and category data
    final liveRatingAsync = ref.watch(artisanLiveRatingProvider(artisan.userId));
    final liveCategoryAsync = ref.watch(artisanLiveCategoryProvider(artisan.userId));

    return GestureDetector(
      onTap: () {
        context.push('/artisan/${artisan.userId}', extra: artisan);
      },
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colorScheme.outlineVariant.withOpacity(0.5),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Image
            Stack(
              children: [
                Container(
                  width: 100,
                  height: 100,
                  margin: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                      colors: [
                        colorScheme.primaryContainer.withOpacity(0.3),
                        colorScheme.secondaryContainer.withOpacity(0.3),
                      ],
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: artisan.photoUrl != null
                        ? Image.network(
                            artisan.photoUrl!,
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _buildPlaceholder(),
                          )
                        : _buildPlaceholder(),
                  ),
                ),
                if (artisan.isVerified)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
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
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),

            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 12, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name and Featured Badge
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            artisan.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (artisan.isFeatured) ...[
                          const SizedBox(width: 8),
                          Icon(
                            Icons.star,
                            size: 16,
                            color: Colors.amber[700],
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),

                    // ✅ Live Category Display
                    liveCategoryAsync.when(
                      data: (category) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          category,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      loading: () => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const SizedBox(
                          width: 60,
                          height: 12,
                          child: LinearProgressIndicator(minHeight: 2),
                        ),
                      ),
                      error: (_, __) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          artisan.category,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Location
                    if (artisan.distance != null || shortAddress != null)
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 14,
                            color: colorScheme.secondary,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              [
                                if (artisan.distance != null) _formatDistance(artisan.distance!),
                                if (shortAddress != null) shortAddress,
                              ].join(' • '),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.secondary,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 8),

                    // Bio
                    if (artisan.bio != null)
                      Text(
                        artisan.bio!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 8),

                    // Stats Row with Live Rating
                    Row(
                      children: [
                        // ✅ Live Rating Display
                        liveRatingAsync.when(
                          data: (ratingData) {
                            final rating = ratingData['rating'] as double;
                            final reviewCount = ratingData['reviewCount'] as int;
                            
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.star,
                                  size: 16,
                                  color: Colors.amber[700],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  rating.toStringAsFixed(1),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '($reviewCount)',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            );
                          },
                          loading: () => Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.star,
                                size: 16,
                                color: Colors.amber[700],
                              ),
                              const SizedBox(width: 8),
                              const SizedBox(
                                width: 40,
                                height: 12,
                                child: LinearProgressIndicator(minHeight: 2),
                              ),
                            ],
                          ),
                          error: (_, __) => Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.star,
                                size: 16,
                                color: Colors.amber[700],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                artisan.rating.toStringAsFixed(1),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '(${artisan.reviewCount})',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const Spacer(),

                        // Action Button
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
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
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.arrow_forward,
                                size: 14,
                                color: colorScheme.onPrimary,
                              ),
                            ],
                          ),
                        ),
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

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey[200],
      child: const Center(
        child: Icon(
          Icons.person,
          size: 40,
          color: Colors.grey,
        ),
      ),
    );
  }
}