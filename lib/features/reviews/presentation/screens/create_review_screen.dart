// lib/features/reviews/presentation/screens/create_review_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../auth/presentation/providers/auth_provider.dart'; // ✅ Add this
import '../providers/review_provider.dart';

class CreateReviewScreen extends ConsumerStatefulWidget {
  final String bookingId;
  final String artisanId;
  final String artisanName;
  final String? artisanPhotoUrl;

  const CreateReviewScreen({
    super.key,
    required this.bookingId,
    required this.artisanId,
    required this.artisanName,
    this.artisanPhotoUrl,
  });

  @override
  ConsumerState<CreateReviewScreen> createState() => _CreateReviewScreenState();
}

class _CreateReviewScreenState extends ConsumerState<CreateReviewScreen> {
  final _commentController = TextEditingController();
  double _rating = 0;
  bool _isSubmitting = false; // ✅ Add local loading state

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Write a Review'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Artisan Info Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: colorScheme.primaryContainer,
                  backgroundImage: widget.artisanPhotoUrl != null
                      ? NetworkImage(widget.artisanPhotoUrl!)
                      : null,
                  child: widget.artisanPhotoUrl == null
                      ? Icon(Icons.person, color: colorScheme.primary)
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.artisanName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'How was your experience?',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Rating Section
          Center(
            child: Column(
              children: [
                Text(
                  'Rate this service',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    return GestureDetector(
                      onTap: () => setState(() => _rating = index + 1.0),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(
                          index < _rating ? Icons.star : Icons.star_border,
                          size: 48,
                          color: index < _rating
                              ? Colors.amber[700]
                              : colorScheme.onSurfaceVariant,
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 8),
                if (_rating > 0)
                  Text(
                    _getRatingText(_rating),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Comment Section
          Text(
            'Tell us more (optional)',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _commentController,
            maxLines: 5,
            maxLength: 500,
            decoration: InputDecoration(
              hintText: 'Share details of your experience...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: colorScheme.surface,
            ),
          ),

          const SizedBox(height: 32),

          // Submit Button
          FilledButton(
            onPressed: _rating > 0 && !_isSubmitting // ✅ Use local state
                ? _submitReview
                : null,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isSubmitting // ✅ Use local state
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Submit Review'),
          ),
        ],
      ),
    );
  }

  String _getRatingText(double rating) {
    if (rating >= 5) return 'Excellent! ⭐';
    if (rating >= 4) return 'Great! 😊';
    if (rating >= 3) return 'Good 👍';
    if (rating >= 2) return 'Fair 😐';
    return 'Poor 😞';
  }

  Future<void> _submitReview() async {
    if (_isSubmitting) return; // ✅ Prevent double submission
    
    final user = ref.read(authProvider).user;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please log in to submit a review'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() => _isSubmitting = true); // ✅ Start loading

    try {
      final success = await ref.read(reviewProvider.notifier).createReview(
            bookingId: widget.bookingId,
            artisanId: widget.artisanId,
            clientId: user.id,
            rating: _rating,
            comment: _commentController.text.trim().isEmpty
                ? null
                : _commentController.text.trim(),
          );

      if (!mounted) return;

      setState(() => _isSubmitting = false); // ✅ Stop loading

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Review submitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        context.pop(true); // Return true to indicate success
      } else {
        final error = ref.read(reviewProvider).error;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error ?? 'Failed to submit review'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      
      setState(() => _isSubmitting = false); // ✅ Stop loading on error
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}