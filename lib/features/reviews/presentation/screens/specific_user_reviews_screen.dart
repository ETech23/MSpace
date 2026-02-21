// lib/features/reviews/presentation/screens/specific_user_reviews_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/review_provider.dart';
import '../../domain/entities/review_entity.dart';

class SpecificUserReviewsScreen extends ConsumerStatefulWidget {
  final String userId;
  final String userName;
  final String userType; // 'artisan' or 'client'

  const SpecificUserReviewsScreen({
    super.key,
    required this.userId,
    required this.userName,
    required this.userType,
  });

  @override
  ConsumerState<SpecificUserReviewsScreen> createState() =>
      _SpecificUserReviewsScreenState();
}

class _SpecificUserReviewsScreenState
    extends ConsumerState<SpecificUserReviewsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadReviews();
    });
  }

  void _loadReviews() {
    if (widget.userType == 'artisan') {
      // Load reviews received by this artisan
      ref.read(reviewProvider.notifier).loadArtisanReviews(widget.userId);
    } else {
      // Load reviews given by this customer
      ref.read(reviewProvider.notifier).loadUserReviews(widget.userId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final reviewState = ref.watch(reviewProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.userType == 'artisan'
            ? 'Reviews for ${widget.userName}'
            : 'Reviews by ${widget.userName}',
        ),
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
                    onPressed: _loadReviews,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (reviewState.reviews.isEmpty) {
            return _buildEmptyState(context);
          }

          return RefreshIndicator(
            onRefresh: () async => _loadReviews(),
            child: Column(
              children: [
                // Rating Summary Card
                _buildRatingSummary(reviewState.reviews, theme, colorScheme),
                
                // Reviews List
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: reviewState.reviews.length,
                    itemBuilder: (context, index) {
                      final review = reviewState.reviews[index];
                      return _buildReviewCard(context, review);
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildRatingSummary(
    List<ReviewEntity> reviews,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    final avgRating = reviews.fold<double>(0, (sum, r) => sum + r.rating) / reviews.length;
    
    // Count ratings by star
    final ratingCounts = <int, int>{};
    for (var i = 1; i <= 5; i++) {
      ratingCounts[i] = reviews.where((r) => r.rating.round() == i).length;
    }

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Average Rating
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    Text(
                      avgRating.toStringAsFixed(1),
                      style: theme.textTheme.displayMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.amber[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        return Icon(
                          index < avgRating.round()
                              ? Icons.star
                              : Icons.star_border,
                          color: Colors.amber[700],
                          size: 20,
                        );
                      }),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${reviews.length} ${reviews.length == 1 ? 'review' : 'reviews'}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Rating Distribution
              Expanded(
                flex: 3,
                child: Column(
                  children: List.generate(5, (i) {
                    final star = 5 - i;
                    final count = ratingCounts[star] ?? 0;
                    final percentage = reviews.isEmpty ? 0.0 : count / reviews.length;
                    
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Text(
                            '$star',
                            style: theme.textTheme.bodySmall,
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.star, size: 12, color: Colors.amber[700]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: LinearProgressIndicator(
                              value: percentage,
                              backgroundColor: colorScheme.surfaceContainerHighest,
                              valueColor: AlwaysStoppedAnimation(Colors.amber[700]),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 30,
                            child: Text(
                              count.toString(),
                              style: theme.textTheme.bodySmall,
                              textAlign: TextAlign.end,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
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
              'No Reviews Yet',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              widget.userType == 'artisan'
                  ? '${widget.userName} hasn\'t received any reviews yet.'
                  : '${widget.userName} hasn\'t written any reviews yet.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildReviewCard(BuildContext context, ReviewEntity review) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    // Show reviewer for artisan's reviews, show artisan for customer's reviews
    final displayName = widget.userType == 'artisan' 
        ? review.reviewerName 
        : review.artisanName;
    final displayPhoto = widget.userType == 'artisan'
        ? review.reviewerPhotoUrl
        : review.artisanPhotoUrl;

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
                  backgroundImage: displayPhoto != null
                      ? NetworkImage(displayPhoto)
                      : null,
                  child: displayPhoto == null
                      ? Icon(Icons.person, color: colorScheme.primary)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
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
}