// lib/features/profile/presentation/screens/saved_artisans_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/profile_provider.dart';

class SavedArtisansScreen extends ConsumerStatefulWidget {
  const SavedArtisansScreen({super.key});

  @override
  ConsumerState<SavedArtisansScreen> createState() =>
      _SavedArtisansScreenState();
}

class _SavedArtisansScreenState extends ConsumerState<SavedArtisansScreen> {
  @override
  void initState() {
    super.initState();
    // Load saved artisans when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(authProvider).user;
      if (user != null) {
        print('🔄 Loading saved artisans for user: ${user.id}');
        ref.read(savedArtisansProvider.notifier).loadSavedArtisans(user.id);
      }
    });
  }

  Future<void> _refreshArtisans() async {
    final user = ref.read(authProvider).user;
    if (user != null) {
      await ref.read(savedArtisansProvider.notifier).loadSavedArtisans(user.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final savedState = ref.watch(savedArtisansProvider);
    final user = ref.watch(authProvider).user;

    // Debug print
    print('📊 Saved artisans state:');
    print('   - Loading: ${savedState.isLoading}');
    print('   - Count: ${savedState.artisans.length}');
    print('   - Error: ${savedState.error}');

    // If not logged in
    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Saved Artisans'),
          centerTitle: true,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.login, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text('Please login to view saved artisans',
                  style: theme.textTheme.titleMedium),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.go('/login'),
                child: const Text('Login'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Artisans'),
        centerTitle: true,
        actions: [
          if (savedState.artisans.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Saved Artisans'),
                    content: const Text(
                      'Your favorite artisans are saved here for quick access. Tap on any artisan to view their full profile.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Got it'),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshArtisans,
        child: Builder(
          builder: (context) {
            // Show error if exists
            if (savedState.error != null) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    Text('Error: ${savedState.error}'),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _refreshArtisans,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }

            // Show loading
            if (savedState.isLoading && savedState.artisans.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            // Show empty state
            if (savedState.artisans.isEmpty) {
              return _buildEmptyState(context);
            }

            // Show list
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: savedState.artisans.length,
              itemBuilder: (context, index) {
                final artisan = savedState.artisans[index];
                return _buildArtisanCard(context, artisan);
              },
            );
          },
        ),
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
                Icons.favorite_border,
                size: 80,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Saved Artisans Yet',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Save your favorite artisans to easily find and book them later. Tap the heart icon on any artisan\'s profile to save them here.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () => context.go('/home'),
              icon: const Icon(Icons.search),
              label: const Text('Browse Artisans'),
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

  Widget _buildArtisanCard(BuildContext context, dynamic artisan) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outlineVariant.withOpacity(0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          context.push('/artisan/${artisan.artisanId}');
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start, // ✅ Fixed overflow
            children: [
              // Profile Picture
              Hero(
                tag: 'artisan-${artisan.artisanId}',
                child: Container(
                  width: 60, // ✅ Reduced size
                  height: 60,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                    image: artisan.artisanPhoto != null
                        ? DecorationImage(
                            image: NetworkImage(artisan.artisanPhoto!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: artisan.artisanPhoto == null
                      ? Icon(
                          Icons.person,
                          size: 30,
                          color: colorScheme.primary,
                        )
                      : null,
                ),
              ),

              const SizedBox(width: 12),

              // Artisan Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min, // ✅ Fixed overflow
                  children: [
                    Text(
                      artisan.artisanName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        artisan.category,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSecondaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.star,
                          size: 14,
                          color: Colors.amber[700],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          artisan.rating.toStringAsFixed(1),
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          Icons.access_time,
                          size: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            _formatSavedDate(artisan.savedAt),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Actions - Reduced to single column
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.favorite),
                    color: Colors.red,
                    iconSize: 20, // ✅ Smaller icon
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 40,
                      minHeight: 40,
                    ),
                    onPressed: () => _unsaveArtisan(artisan.artisanId),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _unsaveArtisan(String artisanId) async {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    final shouldUnsave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove from Saved'),
        content: const Text(
          'Are you sure you want to remove this artisan from your saved list?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (shouldUnsave == true && mounted) {
      final success = await ref
          .read(savedArtisansProvider.notifier)
          .toggleSaveArtisan(user.id, artisanId);

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Artisan removed from saved list'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  String _formatSavedDate(DateTime date) {
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
      return '${(difference.inDays / 30).floor()}mo ago';
    }
  }
}