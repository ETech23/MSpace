// lib/features/profile/presentation/widgets/save_artisan_button.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/profile_provider.dart';

class SaveArtisanButton extends ConsumerStatefulWidget {
  final String artisanId;
  final bool isIconOnly;
  final double? iconSize;
  final Color? backgroundColor;
  final Color? iconColor;

  const SaveArtisanButton({
    super.key,
    required this.artisanId,
    this.isIconOnly = false,
    this.iconSize,
    this.backgroundColor,
    this.iconColor,
  });

  @override
  ConsumerState<SaveArtisanButton> createState() => _SaveArtisanButtonState();
}

class _SaveArtisanButtonState extends ConsumerState<SaveArtisanButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    // Load saved artisans on init
    Future.microtask(() {
      final user = ref.read(authProvider).user;
      if (user != null) {
        ref.read(savedArtisansProvider.notifier).loadSavedArtisans(user.id);
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _toggleSave() async {
    if (_isProcessing) return;

    final user = ref.read(authProvider).user;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please login to save artisans'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    setState(() => _isProcessing = true);

    // Play animation
    await _animationController.forward();
    await _animationController.reverse();

    final success = await ref
        .read(savedArtisansProvider.notifier)
        .toggleSaveArtisan(user.id, widget.artisanId);

    setState(() => _isProcessing = false);

    if (mounted && success) {
      final isSaved = ref
          .read(savedArtisansProvider.notifier)
          .isArtisanSaved(widget.artisanId);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isSaved
                ? '❤️ Artisan saved to your favorites!'
                : '💔 Artisan removed from favorites',
          ),
          duration: const Duration(seconds: 2),
          backgroundColor: isSaved ? Colors.green : Colors.grey[700],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final savedState = ref.watch(savedArtisansProvider);
    final isSaved = savedState.savedArtisanIds.contains(widget.artisanId);

    if (widget.isIconOnly) {
      return ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          decoration: widget.backgroundColor != null
              ? BoxDecoration(
                  color: widget.backgroundColor,
                  shape: BoxShape.circle,
                )
              : null,
          child: IconButton(
            onPressed: _isProcessing ? null : _toggleSave,
            icon: Icon(
              isSaved ? Icons.favorite : Icons.favorite_border,
              color: isSaved
                  ? Colors.red
                  : (widget.iconColor ?? colorScheme.onSurfaceVariant),
              size: widget.iconSize ?? 24,
            ),
            tooltip: isSaved ? 'Remove from favorites' : 'Save to favorites',
          ),
        ),
      );
    }

    return ScaleTransition(
      scale: _scaleAnimation,
      child: FilledButton.tonalIcon(
        onPressed: _isProcessing ? null : _toggleSave,
        icon: _isProcessing
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colorScheme.onSecondaryContainer,
                ),
              )
            : Icon(
                isSaved ? Icons.favorite : Icons.favorite_border,
                color: isSaved ? Colors.red : colorScheme.onSecondaryContainer,
              ),
        label: Text(isSaved ? 'Saved' : 'Save'),
        style: FilledButton.styleFrom(
          backgroundColor: isSaved
              ? Colors.red.withOpacity(0.1)
              : colorScheme.secondaryContainer,
          foregroundColor: isSaved
              ? Colors.red
              : colorScheme.onSecondaryContainer,
        ),
      ),
    );
  }
}

// ============================================
// USAGE EXAMPLES
// ============================================

// Example 1: Icon button in AppBar
class ArtisanDetailAppBar extends ConsumerWidget {
  final String artisanId;

  const ArtisanDetailAppBar({super.key, required this.artisanId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppBar(
      title: const Text('Artisan Details'),
      actions: [
        SaveArtisanButton(
          artisanId: artisanId,
          isIconOnly: true,
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}

// Example 2: Full button in artisan card
class ArtisanCard extends ConsumerWidget {
  final String artisanId;

  const ArtisanCard({super.key, required this.artisanId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ... other artisan info
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: () {},
                    child: const Text('Book Now'),
                  ),
                ),
                const SizedBox(width: 12),
                SaveArtisanButton(
                  artisanId: artisanId,
                  isIconOnly: false,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Example 3: Add to your existing ArtisanDetailScreen
// In your artisan detail screen, add this to the AppBar actions:
/*
AppBar(
  title: Text(artisan.name),
  actions: [
    SaveArtisanButton(
      artisanId: artisan.id,
      isIconOnly: true,
      iconSize: 28,
    ),
    IconButton(
      icon: const Icon(Icons.share),
      onPressed: () => _shareArtisan(artisan),
    ),
  ],
),
*/