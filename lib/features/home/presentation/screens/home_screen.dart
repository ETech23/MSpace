
import 'package:artisan_marketplace/features/home/presentation/widgets/modern_artisan_feed_card.dart';
import 'package:artisan_marketplace/features/home/presentation/widgets/modern_featured_artisan_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/artisan_provider.dart';
import '../widgets/category_chip.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/services/location_service.dart';
import '../../../notifications/presentation/providers/notification_provider.dart';
import '../../../notifications/presentation/providers/job_notification_provider.dart';
import '../../../messaging/presentation/providers/conversation_provider.dart';
import '../../../../core/ads/ad_widgets.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  final LocationService _locationService = LocationService();
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  double? userLatitude;
  double? userLongitude;
  String? locationStatus;
  bool isLoadingLocation = false;
  String? _selectedCategory;

  final List<Map<String, dynamic>> _categories = [
    {'name': 'All', 'icon': Icons.apps},
    {'name': 'Plumber', 'icon': Icons.plumbing},
    {'name': 'Electrician', 'icon': Icons.electric_bolt},
    {'name': 'Carpenter', 'icon': Icons.carpenter},
    {'name': 'Painter', 'icon': Icons.format_paint},
    {'name': 'Mason', 'icon': Icons.construction},
    {'name': 'Mechanic', 'icon': Icons.build},
    {'name': 'Cleaner', 'icon': Icons.cleaning_services},
  ];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeData();
      final user = ref.read(authProvider).user;
      if (user != null) {
        ref.read(systemNotificationProvider.notifier).watchNotifications(user.id);
        ref.read(bookingNotificationProvider.notifier).watchNotifications(user.id);
        ref.read(messageNotificationProvider.notifier).watchNotifications(user.id);
        ref.read(jobNotificationProvider.notifier).watchNotifications(user.id);
        ref.read(conversationProvider.notifier).loadConversations(user.id);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _openFeed() {
    context.push('/feed');
  }

  Future<void> _initializeData() async {
    setState(() => isLoadingLocation = true);
    ref.read(artisanProvider.notifier).loadFeaturedArtisans();
    await _loadLocation();
  }

  Future<void> _loadLocation() async {
    setState(() {
      isLoadingLocation = true;
      locationStatus = 'Getting your location...';
    });

    try {
      final serviceEnabled = await _locationService.isLocationServiceEnabled();
      
      if (!serviceEnabled) {
        if (mounted) {
          final enable = await _showLocationServiceDialog();
          if (enable == true) {
            await _locationService.openLocationSettings();
            await Future.delayed(const Duration(seconds: 2));
            await _loadLocation();
            return;
          }
        }
      }

      final position = await _locationService.getCurrentLocation();

      if (position != null && mounted) {
        setState(() {
          userLatitude = position.latitude;
          userLongitude = position.longitude;
          isLoadingLocation = false;
          locationStatus = null;
        });

        final address = await _locationService.getSavedAddress();
        if (address != null && mounted) {
          setState(() => locationStatus = address);
        }

        ref.read(artisanProvider.notifier).loadNearbyArtisans(
          latitude: userLatitude!,
          longitude: userLongitude!,
          category: _selectedCategory,
        );
      } else {
        setState(() {
          isLoadingLocation = false;
          locationStatus = 'Using default location';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoadingLocation = false;
          locationStatus = 'Location unavailable';
        });
        
        const defaultLat = 4.8156;
        const defaultLng = 7.0498;
        
        setState(() {
          userLatitude = defaultLat;
          userLongitude = defaultLng;
        });

        ref.read(artisanProvider.notifier).loadNearbyArtisans(
          latitude: defaultLat,
          longitude: defaultLng,
          category: _selectedCategory,
        );
      }
    }
  }

  Future<bool?> _showLocationServiceDialog() async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enable Location Services'),
        content: const Text(
          'To show artisans near you, please enable location services. '
          'You can also browse artisans without location services.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Use Default Location'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Enable Location'),
          ),
        ],
      ),
    );
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      if (userLatitude != null && userLongitude != null) {
        ref.read(artisanProvider.notifier).loadMoreArtisans(
          latitude: userLatitude!,
          longitude: userLongitude!,
          category: _selectedCategory,
        );
      }
    }
  }

  Future<void> _onRefresh() async {
    await _loadLocation();
    if (userLatitude != null && userLongitude != null) {
      await ref.read(artisanProvider.notifier).refresh(
        latitude: userLatitude!,
        longitude: userLongitude!,
        category: _selectedCategory,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Listen for user type changes
  ref.listen<AuthState>(authProvider, (previous, next) {
    if (previous?.user?.userType != next.user?.userType) {
      print('🔄 User type changed: ${previous?.user?.userType} → ${next.user?.userType}');
      // Widget will automatically rebuild because we're watching authProvider below
    }
  });

    final authState = ref.watch(authProvider);
    final currentUser = authState.user;
    final isAuthenticated = authState.isAuthenticated;
    final artisanState = ref.watch(artisanProvider);

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Compact App Bar
            SliverAppBar(
              floating: true,
              pinned: true,
              expandedHeight: 56,
              backgroundColor: colorScheme.surface,
              elevation: 0,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        colorScheme.primaryContainer.withOpacity(0.3),
                        colorScheme.surface,
                      ],
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          FadeTransition(
                            opacity: _fadeAnimation,
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        isAuthenticated
                                            ? 'Hello, ${currentUser?.name.split(' ').first ?? 'User'}'
                                            : 'Welcome to Mspace',
                                        style: theme.textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: colorScheme.onSurface,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      if (locationStatus != null)
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.location_on,
                                              size: 12,
                                              color: colorScheme.primary,
                                            ),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                locationStatus!,
                                                style: theme.textTheme.bodySmall?.copyWith(
                                                  color: colorScheme.onSurfaceVariant,
                                                  fontSize: 11,
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
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              actions: [
                // Search icon
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () => context.push('/search'),
                  tooltip: 'Search artisans',
                ),
                
                // Login button
                if (!isAuthenticated)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: TextButton(
                      onPressed: () => context.push('/login'),
                      style: TextButton.styleFrom(
                        backgroundColor: colorScheme.primaryContainer.withOpacity(0.2),
                        foregroundColor: colorScheme.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: const Text('Login', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  )
                else
                  const SizedBox(width: 8),
              ],
            ),

            // Search Bar
           /**  SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: SearchBarWidget(
                  onTap: () => context.push('/search'),
                ),
              ),
            ),**/

            // Category Chips
            SliverToBoxAdapter(
              child: SizedBox(
                height: 50,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  physics: const BouncingScrollPhysics(),
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    final category = _categories[index];
                    final isSelected = _selectedCategory == category['name'] ||
                        (_selectedCategory == null && category['name'] == 'All');
                    
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: CategoryChip(
                        label: category['name'],
                        icon: category['icon'],
                        isSelected: isSelected,
                        onTap: () {
                          setState(() {
                            _selectedCategory = category['name'] == 'All'
                                ? null
                                : category['name'];
                          });
                          if (userLatitude != null && userLongitude != null) {
                            ref.read(artisanProvider.notifier).loadNearbyArtisans(
                              latitude: userLatitude!,
                              longitude: userLongitude!,
                              category: _selectedCategory,
                            );
                          }
                        },
                      ),
                    );
                  },
                ),
              ),
            ),

            // Banner Ad (Home)
            const SliverToBoxAdapter(
              child: Center(
                child: BannerAdWidget(),
              ),
            ),

            // Guest Banner
            if (!isAuthenticated)
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.all(20),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        colorScheme.primaryContainer.withOpacity(0.3),
                        colorScheme.secondaryContainer.withOpacity(0.2),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Find Skilled Artisans',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          )),
                      const SizedBox(height: 8),
                      Text(
                        'Connect with trusted professionals in your area',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () => context.push('/register'),
                        icon: const Icon(Icons.arrow_forward),
                        label: const Text('Get Started'),
                      ),
                    ],
                  ),
                ),
              ),

            // Featured Artisans Section
            if (artisanState.featuredArtisans.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.star_rounded, color: colorScheme.primary, size: 10),
                              const SizedBox(width: 3),
                              Text(
                                'Featured Artisans',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Top-rated professionals',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 210,
                  child: artisanState.isLoadingFeatured
                      ? _buildShimmerList()
                      : ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          physics: const BouncingScrollPhysics(),
                          itemCount: artisanState.featuredArtisans.length,
                          itemBuilder: (context, index) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: FeaturedArtisanCard(
                                artisan: artisanState.featuredArtisans[index],
                              ),
                            );
                          },
                        ),
                ),
              ),
            ],

            // Nearby Artisans Section Header (without Stats Banner and Search Bar)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.location_on, color: colorScheme.primary, size: 20),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Artisans Near You',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ),
                        if (isLoadingLocation)
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (artisanState.searchMessage != null)
                      Row(
                        children: [
                          if (artisanState.isSearchingWider)
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: colorScheme.primary,
                                ),
                              ),
                            ),
                          Expanded(
                            child: Text(
                              artisanState.searchMessage!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: artisanState.isSearchingWider
                                    ? colorScheme.primary
                                    : colorScheme.onSurfaceVariant,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),

            // Nearby Artisans List
            if (artisanState.isLoadingNearby && artisanState.nearbyArtisans.isEmpty)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _buildShimmerCard(),
                    ),
                    childCount: 3,
                  ),
                ),
              )
            else if (artisanState.nearbyArtisans.isEmpty && !artisanState.isLoadingNearby)
              SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      children: [
                        Icon(
                          Icons.person_search,
                          size: 80,
                          color: colorScheme.onSurfaceVariant.withOpacity(0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No artisans found',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Try adjusting your search or location',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          onPressed: _onRefresh,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      const adInterval = 3;
                      final adSlots =
                          (artisanState.nearbyArtisans.length / adInterval).floor();
                      final totalCount =
                          artisanState.nearbyArtisans.length + adSlots;

                      if (index >= totalCount) {
                        return artisanState.isLoadingMore
                            ? const Padding(
                                padding: EdgeInsets.all(16),
                                child: Center(child: CircularProgressIndicator()),
                              )
                            : const SizedBox(height: 80);
                      }

                      final isAdIndex = (index + 1) % (adInterval + 1) == 0;
                      if (isAdIndex) {
                        return const NativeAdWidget();
                      }

                      final artisanIndex = index - (index ~/ (adInterval + 1));

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: ArtisanFeedCard(
                          artisan: artisanState.nearbyArtisans[artisanIndex],
                        ),
                      );
                    },
                    childCount: artisanState.nearbyArtisans.isEmpty
                        ? 0
                        : artisanState.nearbyArtisans.length +
                            (artisanState.nearbyArtisans.length / 3).floor() +
                            1,
                  ),
                ),
              ),
          ],
        ),
      ),
      
      // Compact Bottom Navigation Bar
      bottomNavigationBar: isAuthenticated
          ? _buildModernBottomNav(context, ref, colorScheme, currentUser)
          : null,
      
      // Floating Action Button
      
    floatingActionButton: isAuthenticated && currentUser?.userType == 'customer'
        ? FloatingActionButton.extended(
            onPressed: () {
              showModalBottomSheet(
                context: context,
                builder: (context) => Container(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        leading: Icon(Icons.add_circle, color: colorScheme.primary),
                        title: const Text('Post New Job'),
                        onTap: () {
                          Navigator.pop(context);
                          context.push('/post-job');
                        },
                      ),
                      ListTile(
                        leading: Icon(Icons.list_alt, color: colorScheme.secondary),
                        title: const Text('My Posted Jobs'),
                        onTap: () {
                          Navigator.pop(context);
                          context.push('/my-jobs');
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
            icon: const Icon(Icons.work),
            label: const Text('Jobs'),
            backgroundColor: colorScheme.primary,
          )
        : null,
  );
  }

  Widget _buildModernBottomNav(
    BuildContext context,
    WidgetRef ref,
    ColorScheme colorScheme,
    dynamic currentUser,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // Feed Button
                _buildNavItem(
                  icon: Icons.add_circle_outline,
                  label: 'Feed',
                  onTap: _openFeed,
                  colorScheme: colorScheme,
                ),

              // Messages Button with Badge
              Consumer(
                builder: (context, ref, child) {
                  final conversationUnread = ref.watch(munreadCountProvider);
                  
                  return _buildNavItemWithBadge(
                    icon: Icons.chat_bubble_outline,
                    label: 'Messages',
                    badgeCount: conversationUnread,
                    onTap: () => context.push('/messages'),
                    colorScheme: colorScheme,
                  );
                },
              ),

              // Bookings/Jobs Button (Center with different style)
              _buildCenterNavItem(
                icon: Icons.list_alt_rounded,
                label: currentUser?.userType == 'artisan' ? 'Jobs' : 'Bookings',
                onTap: () => context.push('/bookings'),
                colorScheme: colorScheme,
              ),

              // Notifications Button with Badge
              Consumer(
                builder: (context, ref, child) {
                  final systemUnread = ref.watch(systemUnreadCountProvider);
                  final bookingUnread = ref.watch(bookingUnreadCountProvider);
                  final jobUnread = ref.watch(jobUnreadCountProvider);
                  final totalNotificationUnread = systemUnread + bookingUnread + jobUnread;
                  
                  return _buildNavItemWithBadge(
                    icon: Icons.notifications_outlined,
                    label: 'Alerts',
                    badgeCount: totalNotificationUnread,
                    onTap: () => context.push('/notifications'),
                    colorScheme: colorScheme,
                  );
                },
              ),

              // Menu Button
              _buildNavItem(
                icon: Icons.menu_rounded,
                label: 'Menu',
                onTap: () => context.push('/profile'),
                colorScheme: colorScheme,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required ColorScheme colorScheme,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 22,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItemWithBadge({
    required IconData icon,
    required String label,
    required int badgeCount,
    required VoidCallback onTap,
    required ColorScheme colorScheme,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 22,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            if (badgeCount > 0)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: colorScheme.surface,
                      width: 1.5,
                    ),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Center(
                    child: Text(
                      badgeCount > 9 ? '9+' : '$badgeCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCenterNavItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required ColorScheme colorScheme,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              colorScheme.primary,
              colorScheme.primary.withOpacity(0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: colorScheme.primary.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 24,
              color: colorScheme.onPrimary,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: colorScheme.onPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerList() {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: 3,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(right: 12),
        child: _buildShimmerFeaturedCard(),
      ),
    );
  }

  Widget _buildShimmerFeaturedCard() {
  return Container(
    width: 150,
    decoration: BoxDecoration(
      color: Colors.grey[200],
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 100,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(14),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 12,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                height: 10,
                width: 80,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

  Widget _buildShimmerCard() {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}
