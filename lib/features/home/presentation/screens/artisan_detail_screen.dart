// lib/features/home/presentation/screens/artisan_detail_screen.dart

import 'package:artisan_marketplace/features/profile/presentation/widgets/save_artisan_button.dart';
import 'package:artisan_marketplace/features/trust/presentation/providers/verification_status_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../domain/entities/artisan_entity.dart';
import '../../data/datasources/artisan_remote_datasource.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/di/injection_container.dart';
import '../../../messaging/presentation/screens/chat_screen.dart';
import '../../../messaging/domain/usecases/get_or_create_conversation_usecase.dart';
import '../../../../core/ads/ad_widgets.dart';
import '../../../profile/presentation/providers/business_profile_provider.dart';
import '../../../../core/services/referral_service.dart';
import '../../../../core/services/analytics_service.dart';

// Provider to fetch live rating for artisan detail
final artisanDetailLiveRatingProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, artisanId) async {
  final supabase = Supabase.instance.client;

  final response = await supabase
      .from('reviews')
      .select('rating')
      .eq('artisan_id', artisanId);

  final count = response.length;

  double avgRating = 0;
  if (count > 0) {
    avgRating = response
            .map((r) => (r['rating'] as num).toDouble())
            .reduce((a, b) => a + b) /
        count;
  }

  return {
    'rating': avgRating,
    'reviewCount': count,
  };
});


// Provider to fetch artisan by ID
final artisanDetailProvider = FutureProvider.family<ArtisanEntity?, String>((ref, id) async {
  final dataSource = getIt<ArtisanRemoteDataSource>();
  try {
    final artisan = await dataSource.getArtisanById(id);
    return artisan.toEntity();
  } catch (e) {
    print('Error fetching artisan: $e');
    return null;
  }
});

final _profileViewLoggedProvider =
    StateProvider.family<bool, String>((ref, id) => false);

class ArtisanDetailScreen extends ConsumerWidget {
  final String artisanId;
  final ArtisanEntity? initialArtisan;

  const ArtisanDetailScreen({
    super.key,
    required this.artisanId,
    this.initialArtisan,
  });

  // Add this method for starting conversation
  Future<void> _startConversation(
    BuildContext context,
    WidgetRef ref,
    String otherUserId,
    String otherUserName,
    String? otherUserPhotoUrl,
  ) async {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      // Get or create conversation
      final getOrCreateConversation = getIt<GetOrCreateConversationUseCase>();
      final result = await getOrCreateConversation(
        userId1: user.id,
        userId2: otherUserId,
        bookingId: null, // No booking context from artisan detail screen
      );

      if (!context.mounted) return;

      // Close loading dialog
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
          // Navigate to chat screen
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatScreen(
                conversationId: conversationId,
                otherUserId: otherUserId,
                otherUserName: otherUserName,
                otherUserPhotoUrl: otherUserPhotoUrl,
              ),
            ),
          );
        },
      );
    } catch (e) {
      if (!context.mounted) return;
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
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final artisanAsync = ref.watch(artisanDetailProvider(artisanId));
    final user = ref.watch(authProvider).user;
    final isAuthenticated = ref.watch(authProvider).isAuthenticated;

    ref.listen<AsyncValue<ArtisanEntity?>>(
      artisanDetailProvider(artisanId),
      (previous, next) {
        final logged = ref.read(_profileViewLoggedProvider(artisanId));
        if (logged) return;
        next.whenData((artisan) {
          if (artisan == null) return;
          ref.read(_profileViewLoggedProvider(artisanId).notifier).state = true;
          AnalyticsService.instance.logProfileView(
            profileUserId: artisan.userId,
            profileType: artisan.userType == 'business' ? 'business' : 'artisan',
            category: artisan.category,
            viewerName: user?.name,
            viewerPhotoUrl: user?.photoUrl,
            viewerUserType: user?.userType,
          );
        });
      },
    );

    return Scaffold(
      body: artisanAsync.when(
        loading: () {
          if (initialArtisan != null) {
            return _buildLoadingSplash(context, initialArtisan!);
          }
          return const Center(child: CircularProgressIndicator());
        },
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  'Error loading artisan',
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  error.toString(),
                  style: theme.textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => context.pop(),
                  child: const Text('Go Back'),
                ),
              ],
            ),
          ),
        ),
        data: (artisan) {
          if (artisan == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.person_off, size: 64),
                  const SizedBox(height: 16),
                  const Text('Artisan not found'),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => context.pop(),
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            );
          }

          final isBusiness = artisan.userType == 'business';
          final businessState = isBusiness
              ? ref.watch(businessProfileProvider(artisanId))
              : null;
          final businessProfile = businessState?.profile ?? const <String, dynamic>{};
          final businessItems = businessState?.items ?? const <Map<String, dynamic>>[];
          final businessName = businessProfile['business_name']?.toString();
          final businessDescription = businessProfile['description']?.toString();
          final businessContactPhone = businessProfile['contact_phone']?.toString();
          final showBusinessPhone = (businessProfile['show_phone'] as bool?) ?? false;
          final coverageArea = businessProfile['coverage_area']?.toString();
          final teamSize = businessProfile['team_size']?.toString();
          final categories = businessProfile['service_categories'];
          final serviceCategories = categories is List
              ? categories.map((e) => e.toString()).where((e) => e.isNotEmpty).toList()
              : const <String>[];

          final headerName = (isBusiness && businessName != null && businessName.isNotEmpty)
              ? businessName
              : artisan.name;
          final headerCategory = isBusiness
              ? (serviceCategories.isNotEmpty
                  ? serviceCategories.first
                  : (artisan.category.isNotEmpty && artisan.category != 'General'
                      ? artisan.category
                      : ''))
              : artisan.category;

          final isOwnProfile = user != null && user.id == artisanId;
          return CustomScrollView(
            slivers: [
              // App Bar with Image
              SliverAppBar(
                expandedHeight: 300,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Background Image
                      artisan.photoUrl != null
                          ? Image.network(
                              artisan.photoUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _buildImagePlaceholder(colorScheme),
                            )
                          : _buildImagePlaceholder(colorScheme),
                      // Gradient Overlay
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.7),
                            ],
                          ),
                        ),
                      ),
                      // Badges
Positioned(
  top: 60,
  right: 16,
  child: Column(
    children: [
      Consumer(
        builder: (context, ref, child) {
          final verifiedAsync = ref.watch(
            userVerificationStatusProvider(artisanId)
          );
          
          return verifiedAsync.when(
            data: (isVerified) {
              if (!isVerified) return SizedBox.shrink();
              
              return Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.verified,
                  color: Colors.white,
                  size: 20,
                ),
              );
            },
            loading: () => SizedBox.shrink(),
            error: (_, __) => SizedBox.shrink(),
          );
        },
      ),
      if (artisan.premium) ...[
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: const BoxDecoration(
            color: Colors.amber,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.star,
            color: Colors.white,
            size: 20,
          ),
        ),
      ],
    ],
  ),
),
                    ],
                  ),
                ),
                leading: IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  onPressed: () => context.pop(),
                ),
                  actions: [
                    IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.share, color: Colors.white),
                      ),
                      onPressed: () async {
                        const packageName = 'com.mspace.app';
                        final baseLink =
                            'https://play.google.com/store/apps/details?id=$packageName';
                        final profileLink =
                            'https://naco-d2738.web.app/p/$artisanId';
                        String link = baseLink;
                        if (user != null) {
                          final referralService =
                              ReferralService(Supabase.instance.client);
                          final code =
                              await referralService.ensureReferralCode(user.id);
                          link = referralService.buildPlayStoreShareLink(
                            packageName: packageName,
                            code: code,
                          );
                        }
                        final shareText = isBusiness
                            ? 'Check out $headerName on MSpace.\n$profileLink\nGet the app: $link'
                            : 'Check out ${artisan.name} on MSpace.'
                                '${artisan.category.isNotEmpty ? ' ${artisan.category} artisan.' : ''}\n$profileLink\nGet the app: $link';
                        Share.share(shareText);
                      },
                    ),
                    if (!isOwnProfile)
                      IconButton(
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.flag, color: Colors.white),
                        ),
                        onPressed: () {
                          context.push('/report', extra: {
                            'targetType': 'user',
                            'targetId': artisanId,
                            'targetLabel': artisan.name,
                          });
                        },
                      ),
  
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: SaveArtisanButton(
                      artisanId: artisanId,
                      isIconOnly: true,
                      iconSize: 24,
                      backgroundColor: Colors.black.withOpacity(0.5),
                      iconColor: Colors.white,
                    ),
                  ),
                ],
              ),



              // Content
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    Center(child: BannerAdWidget()),
                    const SizedBox(height: 16),
                    // Header Info
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      headerName,
                                      style: theme.textTheme.headlineSmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    if (headerCategory.isNotEmpty)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: colorScheme.primaryContainer,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          headerCategory,
                                          style: TextStyle(
                                            color: colorScheme.primary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    if (isBusiness) ...[
                                      const SizedBox(height: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.green.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(999),
                                        ),
                                        child: Text(
                                          'Business',
                                          style: TextStyle(
                                            color: Colors.green[700],
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              // Availability Badge
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: artisan.isAvailable
                                      ? Colors.green.withOpacity(0.2)
                                      : Colors.red.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: artisan.isAvailable
                                            ? Colors.green
                                            : Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      artisan.isAvailable ? 'Available' : 'Busy',
                                      style: TextStyle(
                                        color: artisan.isAvailable
                                            ? Colors.green[700]
                                            : Colors.red[700],
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final uri =
                                    Uri.parse('https://naco-d2738.web.app/p/$artisanId');
                                if (!await launchUrl(
                                  uri,
                                  mode: LaunchMode.externalApplication,
                                )) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Could not open public profile.',
                                        ),
                                      ),
                                    );
                                  }
                                }
                              },
                              icon: const Icon(Icons.public_rounded),
                              label: const Text('Open Public Profile'),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Stats Cards
                          Row(
                            children: [
                              // ✅ Live Rating Stat Card (Clickable)
                              Expanded(
                                child: ref.watch(artisanDetailLiveRatingProvider(artisanId)).when(
                                  data: (ratingData) {
                                    final rating = ratingData['rating'] as double;
                                    final reviewCount = ratingData['reviewCount'] as int;
                                    
                                    return GestureDetector(
                                      onTap: () {
                                        // Navigate to reviews screen
                                        context.push(
                                          '/reviews/user/$artisanId',
                                          extra: {
                                            'userId': artisanId,
                                            'userName': artisan.name,
                                            'userType': 'artisan',
                                          },
                                        );
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: Colors.amber.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: Colors.amber.withOpacity(0.3),
                                            width: 1.5,
                                          ),
                                        ),
                                        child: Column(
                                          children: [
                                            Icon(Icons.star, color: Colors.amber, size: 28),
                                            const SizedBox(height: 8),
                                            Text(
                                              rating.toStringAsFixed(1),
                                              style: theme.textTheme.titleLarge?.copyWith(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.amber,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '$reviewCount reviews',
                                              style: theme.textTheme.bodySmall?.copyWith(
                                                color: theme.colorScheme.onSurfaceVariant,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                            const SizedBox(height: 4),
                                            Icon(
                                              Icons.touch_app,
                                              size: 14,
                                              color: Colors.amber.withOpacity(0.7),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                  loading: () => Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Column(
                                      children: [
                                        Icon(Icons.star, color: Colors.amber, size: 28),
                                        const SizedBox(height: 8),
                                        const SizedBox(
                                          width: 40,
                                          height: 20,
                                          child: LinearProgressIndicator(),
                                        ),
                                      ],
                                    ),
                                  ),
                                  error: (_, __) => _buildStatCard(
                                    context,
                                    Icons.star,
                                    artisan.rating.toStringAsFixed(1),
                                    '${artisan.reviewCount} reviews',
                                    Colors.amber,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildStatCard(
                                  context,
                                  isBusiness ? Icons.groups_outlined : Icons.work_outline,
                                  isBusiness
                                      ? (teamSize ?? '—')
                                      : (artisan.experienceYears ?? '5+'),
                                  isBusiness ? 'Team size' : 'Years exp.',
                                  colorScheme.primary,
                                ),
                              
                              ),
                              if (artisan.distance != null) ...[
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildStatCard(
                                    context,
                                    Icons.location_on,
                                    '${artisan.distance!.toStringAsFixed(1)}km',
                                    'Away',
                                    colorScheme.secondary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                                                  ],
                      ),
                    ),

                    

                    const Divider(height: 1),

                    // About Section
                    if (isBusiness
                        ? (businessDescription != null && businessDescription.isNotEmpty)
                        : (artisan.bio != null && artisan.bio!.isNotEmpty))
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isBusiness ? 'About Business' : 'About',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              isBusiness ? businessDescription! : artisan.bio!,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Skills / Service Categories
                    if (isBusiness
                        ? serviceCategories.isNotEmpty
                        : (artisan.skills != null && artisan.skills!.isNotEmpty))
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isBusiness ? 'Service Categories' : 'Skills',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: (isBusiness ? serviceCategories : artisan.skills!)
                                  .map((skill) => Chip(
                                        label: Text(skill),
                                        backgroundColor: colorScheme.secondaryContainer,
                                        labelStyle: TextStyle(
                                          color: colorScheme.onSecondaryContainer,
                                        ),
                                      ))
                                  .toList(),
                            ),
                          ],
                        ),
                      ),

                    // Items & Services
                    if (isBusiness && businessItems.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Items & Services',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ...businessItems.map((item) {
                              final name = item['name']?.toString() ?? 'Item';
                              final desc = item['description']?.toString();
                              final price = item['price']?.toString();
                              final isActive = item['is_active'] as bool? ?? true;
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: colorScheme.outline.withOpacity(0.1),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            name,
                                            style: theme.textTheme.titleSmall?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        if (!isActive)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: colorScheme.onSurfaceVariant
                                                  .withOpacity(0.12),
                                              borderRadius: BorderRadius.circular(999),
                                            ),
                                            child: Text(
                                              'Inactive',
                                              style: theme.textTheme.labelSmall?.copyWith(
                                                color: colorScheme.onSurfaceVariant,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    if (desc != null && desc.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        desc,
                                        style: theme.textTheme.bodySmall,
                                      ),
                                    ],
                                    if (price != null && price.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        'Price: $price',
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: colorScheme.primary,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),

                    // Contact Section
// Contact Section - with conditional message button
Padding(
  padding: const EdgeInsets.all(20),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Contact Information',
        style: theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
      const SizedBox(height: 16),
      
      if (artisan.address != null)
        _buildContactItem(
          context,
          Icons.location_on,
          'Address',
          artisan.address!,
        ),

      if (isBusiness && coverageArea != null && coverageArea.isNotEmpty) ...[
        const SizedBox(height: 12),
        _buildContactItem(
          context,
          Icons.map_outlined,
          'Coverage Area',
          coverageArea,
        ),
      ],
      
      if (isBusiness ? (showBusinessPhone && businessContactPhone != null) : artisan.phoneNumber != null) ...[
        const SizedBox(height: 12),
        _buildContactItem(
          context,
          Icons.phone,
          'Phone',
          (isBusiness ? businessContactPhone : artisan.phoneNumber)!,
        ),
      ],
      
      // Privacy note
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: colorScheme.outline.withOpacity(0.2),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.lock_outline,
              size: 20,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Email and other contact details are private. Use the message button to communicate.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
      
      // ✅ Only show message button if NOT own profile
      if (!isOwnProfile) ...[
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () {
              if (!isAuthenticated) {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Login Required'),
                    content: const Text(
                      'You need to login to message this artisan.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () {
                          Navigator.pop(context);
                          context.push('/login');
                        },
                        child: const Text('Login'),
                      ),
                    ],
                  ),
                );
                return;
              }

              _startConversation(
                context,
                ref,
                artisanId,
                artisan.name,
                artisan.photoUrl,
              );
            },
            icon: const Icon(Icons.message_outlined),
            label: const Text('Send Message'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: colorScheme.secondaryContainer,
              foregroundColor: colorScheme.onSecondaryContainer,
            ),
          ),
        ),
      ],
    ],
  ),
),

                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: artisanAsync.maybeWhen(
        data: (artisan) {
          if (artisan == null) return null;
          final isBusiness = artisan.userType == 'business';

          // Check if user is viewing their own profile
        final isOwnProfile = user != null && user.id == artisanId;
        
        // ✅ Don't show action buttons if viewing own profile
        if (isOwnProfile) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: colorScheme.outline.withOpacity(0.2),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 20,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'This is your profile',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
          
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  if (artisan.hourlyRate != null)
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Starting from',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            '₦${artisan.hourlyRate!.toStringAsFixed(0)}/hr',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: () {
                        if (!isAuthenticated) {
                          final actionLabel =
                              isBusiness ? 'request a quote' : 'book an artisan';
                          // Show login dialog
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Login Required'),
                              content: Text(
                                'You need to login to $actionLabel.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Cancel'),
                                ),
                                FilledButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    context.push('/login');
                                  },
                                  child: const Text('Login'),
                                ),
                              ],
                            ),
                          );
                          return;
                        }

      

                        // Navigate to create booking screen with artisan data
                        context.push('/bookings/create', extra: artisan);
                      },
                      icon: Icon(
                        isBusiness ? Icons.request_quote : Icons.calendar_today,
                      ),
                      label: Text(isBusiness ? 'Request Quote' : 'Book Now'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        orElse: () => null,
      ),
    );
  }

  Widget _buildImagePlaceholder(ColorScheme colorScheme) {
    return Container(
      color: colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.person,
          size: 100,
          color: colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildLoadingSplash(BuildContext context, ArtisanEntity artisan) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 280,
          pinned: true,
          flexibleSpace: FlexibleSpaceBar(
            background: Stack(
              fit: StackFit.expand,
              children: [
                artisan.photoUrl != null
                    ? Image.network(
                        artisan.photoUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildImagePlaceholder(colorScheme),
                      )
                    : _buildImagePlaceholder(colorScheme),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.55),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          leading: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back, color: Colors.white),
            ),
            onPressed: () => context.pop(),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  artisan.name,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  artisan.category,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Loading artisan details...',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    IconData icon,
    String value,
    String label,
    Color color,
  ) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
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
      ),
    );
  }

  Widget _buildContactItem(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer.withOpacity(0.5),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: colorScheme.primary, size: 20),
        ),
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

