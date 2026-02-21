// lib/features/profile/presentation/screens/user_profile_screen.dart

import 'package:artisan_marketplace/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/user_profile_entity.dart';
import '../providers/user_profile_provider.dart';
import '../../../messaging/presentation/screens/chat_screen.dart';
import '../../../messaging/domain/usecases/get_or_create_conversation_usecase.dart';
import '../../../../core/di/injection_container.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../trust/presentation/providers/verification_status_provider.dart';
import '../../../../core/ads/ad_widgets.dart';

class UserProfileScreen extends ConsumerStatefulWidget {
  final String userId;
  final String userType; // 'artisan' or 'client'
  final String? userName;

  const UserProfileScreen({
    super.key,
    required this.userId,
    required this.userType,
    this.userName,
  });

  @override
  ConsumerState<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends ConsumerState<UserProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(userProfileProvider.notifier).loadUserProfile(
            userId: widget.userId,
            userType: widget.userType,
          );
    });
  }

  
// ✅ Provider to fetch live rating for user profile
final userLiveRatingProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, userId) async {
  try {
    final supabase = Supabase.instance.client;
    
    // Fetch the user's current rating from database
    final response = await supabase
        .from('artisan_profiles')
        .select('rating, reviews_count')
        .eq('user_id', userId)
        .single();
    
    return {
      'rating': (response['rating'] as num?)?.toDouble() ?? 0.0,
      'reviewCount': response['reviews_count'] as int? ?? 0,
    };
  } catch (e) {
    print('Error fetching user live rating: $e');
    return {'rating': 0.0, 'reviewCount': 0};
  }
});

  Future<void> _startConversation() async {
  final user = ref.read(authProvider).user;
  if (user == null) return;

  final profileState = ref.read(userProfileProvider);
  final userProfile = profileState.userProfile;
  if (userProfile == null) return;

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => const Center(
      child: CircularProgressIndicator(),
    ),
  );

  try {
    final getOrCreateConversation = getIt<GetOrCreateConversationUseCase>();
    final result = await getOrCreateConversation(
      userId1: user.id,
      userId2: widget.userId,
    );

    if (!mounted) return;
    Navigator.pop(context);

    result.fold(
      (failure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start conversation: ${failure.message}'),
            backgroundColor: Colors.red,
          ),
        );
      },
      (conversationId) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              conversationId: conversationId,
              otherUserId: widget.userId,
              otherUserName: userProfile.displayName,
              otherUserPhotoUrl: userProfile.profilePhotoUrl,
            ),
          ),
        );
      },
    );
  } catch (e) {
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error: $e'),
        backgroundColor: Colors.red,
      ),
    );
  }
}

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final profileState = ref.watch(userProfileProvider);
    
    final userProfile = profileState.userProfile;
    final stats = profileState.stats;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.userName ?? 'User Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(userProfileProvider.notifier).loadUserProfile(
                    userId: widget.userId,
                    userType: widget.userType,
                  );
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _buildBody(
        theme: theme,
        colorScheme: colorScheme,
        profileState: profileState,
        userProfile: userProfile,
        stats: stats,
      ),
    );
  }

  Widget _buildBody({
    required ThemeData theme,
    required ColorScheme colorScheme,
    required UserProfileState profileState,
    required UserProfileEntity? userProfile,
    required Map<String, dynamic>? stats,
  }) {
    if (profileState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (profileState.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: colorScheme.error),
            const SizedBox(height: 16),
            Text(
              'Error loading profile',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              profileState.error!,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () {
                ref.read(userProfileProvider.notifier).loadUserProfile(
                      userId: widget.userId,
                      userType: widget.userType,
                    );
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (userProfile == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_off, size: 64, color: colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              'Profile not available',
              style: theme.textTheme.titleLarge,
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile Header with Chat Button
          _buildProfileHeader(userProfile, theme, colorScheme),
          const SizedBox(height: 24),
          
          // Contact Information
          _buildContactInfo(userProfile, theme, colorScheme),
          const SizedBox(height: 24),

          _buildRatingSection(userProfile, theme, colorScheme, ref),

          const BannerAdWidget(),
          const SizedBox(height: 24),
          
          
          // User Statistics
          if (stats != null) ...[
            _buildStatistics(stats, theme, colorScheme),
            const SizedBox(height: 24),
          ],
          
          // User Details based on type
          if (widget.userType == 'artisan') 
            _buildArtisanDetails(userProfile, theme, colorScheme)
          else 
            _buildClientDetails(userProfile, theme, colorScheme),
          
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildProfileImage(String? photoUrl, ColorScheme colorScheme) {
    // If no photo URL, show placeholder
    if (photoUrl == null || photoUrl.isEmpty) {
      return Container(
        color: colorScheme.surfaceContainerHighest,
        child: Icon(
          Icons.person,
          size: 32,
          color: colorScheme.onSurfaceVariant,
        ),
      );
    }

    // Use the photoUrl as-is (it should already be properly formatted from backend)
    return Image.network(
      photoUrl,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Center(
          child: CircularProgressIndicator(
            value: loadingProgress.expectedTotalBytes != null
                ? loadingProgress.cumulativeBytesLoaded /
                    loadingProgress.expectedTotalBytes!
                : null,
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        print('❌ Image load error for URL: $photoUrl');
        print('Error: $error');
        return Container(
          color: colorScheme.surfaceContainerHighest,
          child: Icon(
            Icons.person,
            size: 32,
            color: colorScheme.onSurfaceVariant,
          ),
        );
      },
    );
  }

  Widget _buildProfileHeader(
    UserProfileEntity userProfile,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outline.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Profile Image
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: colorScheme.primary.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: ClipOval(
                  child: _buildProfileImage(userProfile.profilePhotoUrl, colorScheme),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name with Verification Badge
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            userProfile.displayName,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        
                        Consumer(
      builder: (context, ref, child) {
        final verificationAsync = ref.watch(
          userVerificationStatusProvider(widget.userId)
        );
        
        return verificationAsync.when(
          data: (isVerified) {
            if (!isVerified) return SizedBox.shrink();
            
            return Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Tooltip(
                message: 'Verified Identity',
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.verified,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ),
            );
          },
          loading: () => SizedBox.shrink(),
          error: (_, __) => SizedBox.shrink(),
        );
      },
    ),
  ],
),

                    const SizedBox(height: 4),
                    // User Type Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: widget.userType == 'artisan'
                            ? Colors.blue.withOpacity(0.2)
                            : Colors.green.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        widget.userType == 'artisan' ? 'Service Provider' : 'Customer',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: widget.userType == 'artisan'
                              ? Colors.blue.shade700
                              : Colors.green.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    // Rating (if available)
                    if (userProfile.rating != null && userProfile.rating! > 0) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            userProfile.rating!.toStringAsFixed(1),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (userProfile.totalReviews != null && userProfile.totalReviews! > 0) ...[
                            Text(
                              ' (${userProfile.totalReviews} reviews)',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Chat Button Row
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
  onPressed: _startConversation,  // Changed from _showMessageDialog
  icon: const Icon(Icons.message, size: 20),
  label: const Text('Send Message'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContactInfo(
    UserProfileEntity userProfile,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outline.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Profile Information',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (userProfile.location != null) ...[
            _buildInfoRow(
              Icons.location_on,
              'Location',
              userProfile.location!,
              theme,
              colorScheme,
            ),
            const SizedBox(height: 12),
          ],
          if (userProfile.bio != null && userProfile.bio!.isNotEmpty) ...[
            _buildInfoRow(
              Icons.description,
              'About',
              userProfile.bio!,
              theme,
              colorScheme,
            ),
            const SizedBox(height: 12),
          ],
          // Privacy Note
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.lock,
                  size: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Contact details are private for security. Use the message button to communicate.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingSection(
  UserProfileEntity userProfile,
  ThemeData theme,
  ColorScheme colorScheme,
  WidgetRef ref, // ✅ Add ref parameter
) {
  // Only show for artisans
  if (widget.userType != 'artisan') {
    return const SizedBox.shrink();
  }

  // ✅ Watch live rating data
  final liveRatingAsync = ref.watch(userLiveRatingProvider(widget.userId));

  return liveRatingAsync.when(
    data: (ratingData) {
      final rating = ratingData['rating'] as double;
      final reviewCount = ratingData['reviewCount'] as int;
      
      // Don't show if no reviews
      if (rating == 0 && reviewCount == 0) {
        return const SizedBox.shrink();
      }

      return GestureDetector(
        onTap: () {
          // Navigate to specific user reviews screen
          context.push(
            '/reviews/user/${widget.userId}',
            extra: {
              'userId': widget.userId,
              'userName': userProfile.displayName,
              'userType': widget.userType,
            },
          );
        },
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.amber.withOpacity(0.1),
                Colors.orange.withOpacity(0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.amber.withOpacity(0.3),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              // Star Icon
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.star,
                  color: Colors.amber[700],
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              // Rating Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          rating.toStringAsFixed(1),
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.amber[700],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: List.generate(5, (index) {
                                return Icon(
                                  index < rating.round()
                                      ? Icons.star
                                      : Icons.star_border,
                                  color: Colors.amber[700],
                                  size: 16,
                                );
                              }),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$reviewCount ${reviewCount == 1 ? 'review' : 'reviews'}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Arrow Icon
              Icon(
                Icons.chevron_right,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      );
    },
    loading: () => Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(
        child: SizedBox(
          height: 40,
          child: LinearProgressIndicator(),
        ),
      ),
    ),
    error: (_, __) => const SizedBox.shrink(),
  );
}

  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatistics(
    Map<String, dynamic> stats,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outline.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.insights, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Booking Statistics',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatCard(
                icon: Icons.bookmark_added,
                value: stats['totalBookings']?.toString() ?? '0',
                label: 'Total Bookings',
                color: Colors.blue,
                theme: theme,
              ),
              _buildStatCard(
                icon: Icons.done_all,
                value: stats['completedBookings']?.toString() ?? '0',
                label: 'Completed',
                color: Colors.green,
                theme: theme,
              ),
              _buildStatCard(
                icon: Icons.pending,
                value: stats['pendingBookings']?.toString() ?? '0',
                label: 'Pending',
                color: Colors.orange,
                theme: theme,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
    required ThemeData theme,
  }) {
    return Column(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: color.withOpacity(0.1),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildArtisanDetails(
    UserProfileEntity userProfile,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outline.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.work, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Service Details',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (userProfile.category != null) ...[
            _buildDetailRow(
              Icons.category,
              'Service Category',
              userProfile.category!,
              theme,
              colorScheme,
            ),
            const SizedBox(height: 12),
          ],
          if (userProfile.yearsOfExperience != null) ...[
            _buildDetailRow(
              Icons.timeline,
              'Years of Experience',
              '${userProfile.yearsOfExperience!} years',
              theme,
              colorScheme,
            ),
            const SizedBox(height: 12),
          ],
          if (userProfile.skills?.isNotEmpty == true) ...[
            Text(
              'Skills & Expertise',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: userProfile.skills!
                  .map((skill) => Chip(
                        label: Text(skill),
                        backgroundColor: colorScheme.primaryContainer,
                        labelStyle: TextStyle(color: colorScheme.onPrimaryContainer),
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildClientDetails(
    UserProfileEntity userProfile,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outline.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person_pin, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Customer Information',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (userProfile.memberSince != null) ...[
            _buildDetailRow(
              Icons.calendar_today,
              'Member Since',
              _formatDate(userProfile.memberSince!),
              theme,
              colorScheme,
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Widget _buildDetailRow(
    IconData icon,
    String label,
    String value,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
