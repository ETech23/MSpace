// lib/features/reviews/presentation/screens/user_reviews_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/review_provider.dart';
import '../../domain/entities/review_entity.dart';

class UserReviewsScreen extends ConsumerStatefulWidget {
  const UserReviewsScreen({super.key});

  @override
  ConsumerState<UserReviewsScreen> createState() => _UserReviewsScreenState();
}

class _UserReviewsScreenState extends ConsumerState<UserReviewsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(authProvider).user;
      if (user != null) {
        if (user.userType == 'artisan') {
          // Load reviews received as an artisan
          ref.read(reviewProvider.notifier).loadArtisanReviews(user.id);
        } else {
          // Load reviews given as a customer
          ref.read(reviewProvider.notifier).loadUserReviews(user.id);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final reviewState = ref.watch(reviewProvider);
    final user = ref.watch(authProvider).user;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Reviews')),
        body: const Center(child: Text('Please login to view reviews')),
      );
    }

    final isArtisan = user.userType == 'artisan';

    return Scaffold(
      appBar: AppBar(
        title: Text(isArtisan ? 'Reviews Received' : 'My Reviews'),
        centerTitle: true,
      ),
      body: Builder(
        builder: (context) {
          if (reviewState.isLoading && reviewState.reviews.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (reviewState.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${reviewState.error}'),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () {
                      if (isArtisan) {
                        ref.read(reviewProvider.notifier).loadArtisanReviews(user.id);
                      } else {
                        ref.read(reviewProvider.notifier).loadUserReviews(user.id);
                      }
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (reviewState.reviews.isEmpty) {
            return _buildEmptyState(context, isArtisan);
          }

          return RefreshIndicator(
            onRefresh: () async {
              if (isArtisan) {
                await ref.read(reviewProvider.notifier).loadArtisanReviews(user.id);
              } else {
                await ref.read(reviewProvider.notifier).loadUserReviews(user.id);
              }
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: reviewState.reviews.length,
              itemBuilder: (context, index) {
                final review = reviewState.reviews[index];
                return _buildReviewCard(context, review, isArtisan);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isArtisan) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 100),
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.star_border,
                size: 80,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              isArtisan ? 'No Reviews Yet' : 'No Reviews Given',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              isArtisan
                  ? 'Complete more jobs to receive reviews from your customers.'
                  : 'Book and complete services to leave reviews for artisans.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () => context.go('/home'),
              icon: const Icon(Icons.search),
              label: Text(isArtisan ? 'View Profile' : 'Browse Artisans'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildReviewCard(BuildContext context, ReviewEntity review, bool isArtisan) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with avatar and name
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: colorScheme.primaryContainer,
                  backgroundImage: (isArtisan 
                      ? review.reviewerPhotoUrl 
                      : review.artisanPhotoUrl) != null
                      ? NetworkImage(isArtisan 
                          ? review.reviewerPhotoUrl! 
                          : review.artisanPhotoUrl!)
                      : null,
                  child: (isArtisan 
                      ? review.reviewerPhotoUrl 
                      : review.artisanPhotoUrl) == null
                      ? Icon(Icons.person, color: colorScheme.primary)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isArtisan ? review.reviewerName : review.artisanName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _formatDate(review.createdAt),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                // Rating
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _getRatingColor(review.rating).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.star,
                        size: 16,
                        color: _getRatingColor(review.rating),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        review.rating.toStringAsFixed(1),
                        style: TextStyle(
                          color: _getRatingColor(review.rating),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            if (review.comment != null && review.comment!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                review.comment!,
                style: theme.textTheme.bodyMedium,
              ),
            ],

            // Actions for customer reviews
            if (!isArtisan) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => _editReview(review),
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('Edit'),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () => _deleteReview(review.id),
                    icon: const Icon(Icons.delete, size: 18),
                    label: const Text('Delete'),
                    style: TextButton.styleFrom(
                      foregroundColor: colorScheme.error,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getRatingColor(double rating) {
    if (rating >= 4.5) return Colors.green;
    if (rating >= 3.5) return Colors.amber;
    return Colors.orange;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return 'Just now';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else if (difference.inDays < 30) {
      return '${(difference.inDays / 7).floor()}w ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  void _editReview(ReviewEntity review) {
    // TODO: Navigate to edit review screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Edit review coming soon!')),
    );
  }

  void _deleteReview(String reviewId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Review'),
        content: const Text('Are you sure you want to delete this review?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final success = await ref.read(reviewProvider.notifier).deleteReview(reviewId);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Review deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        // Reload reviews
        final user = ref.read(authProvider).user;
        if (user != null) {
          ref.read(reviewProvider.notifier).loadUserReviews(user.id);
        }
      }
    }
  }
}