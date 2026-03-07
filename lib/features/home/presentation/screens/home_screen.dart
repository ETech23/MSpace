import 'dart:async';
import 'dart:convert';

import 'package:artisan_marketplace/features/home/presentation/widgets/modern_artisan_feed_card.dart';
import 'package:artisan_marketplace/features/home/presentation/widgets/modern_featured_artisan_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../providers/artisan_provider.dart';
import '../widgets/category_chip.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/services/update_user_location.dart';
import '../../../notifications/presentation/providers/notification_provider.dart';
import '../../../notifications/presentation/providers/job_notification_provider.dart';
import '../../../messaging/presentation/providers/conversation_provider.dart';
import '../../../../core/ads/ad_widgets.dart';
import '../../../../core/widgets/location_permission_nudge.dart';
import '../../../trust/presentation/providers/trust_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final ScrollController _scrollController = ScrollController();
  final LocationService _locationService = LocationService();
  Timer? _nearbyAutoRefreshTimer;
  Timer? _ipFallbackRetryTimer;
  static const Duration _nearbyAutoRefreshInterval = Duration(seconds: 30);

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  double? userLatitude;
  double? userLongitude;
  String? locationStatus;
  bool isLoadingLocation = false;
  String? _selectedCategory;
  String? _liveWatchUserId;
  bool _isApproximateLocation = false;
  String? _locationSessionKey;
  bool _isInitializingData = false;
  bool _retryLocationOnResume = false;

  final List<Map<String, dynamic>> _categories = [
    {'name': 'All', 'icon': Icons.apps_rounded},
    {'name': 'Plumber', 'icon': Icons.plumbing_rounded},
    {'name': 'Electrician', 'icon': Icons.electric_bolt_rounded},
    {'name': 'Carpenter', 'icon': Icons.carpenter_rounded},
    {'name': 'Painter', 'icon': Icons.format_paint_rounded},
    {'name': 'Mason', 'icon': Icons.construction_rounded},
    {'name': 'Mechanic', 'icon': Icons.build_circle_rounded},
    {'name': 'Cleaner', 'icon': Icons.cleaning_services_rounded},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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

  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    _nearbyAutoRefreshTimer?.cancel();
    _ipFallbackRetryTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  void _openFeed() {
    context.push('/feed');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed && _retryLocationOnResume) {
      _retryLocationOnResume = false;
      _initializeData();
    }
  }

  Future<void> _initializeData() async {
    if (_isInitializingData) return;
    _isInitializingData = true;

    if (mounted) {
      setState(() => isLoadingLocation = true);
    }

    try {
      await ref.read(authProvider.notifier).refreshUser();
      await _loadLocation();
      await _loadFeaturedForCurrentContext(forceRefresh: true);
    } finally {
      _isInitializingData = false;
    }
  }

  Future<void> _loadLocation() async {
    setState(() {
      isLoadingLocation = true;
      locationStatus = 'Loading saved location...';
    });

    try {
      final currentUser = ref.read(authProvider).user;
      final hasSavedDbLocation = currentUser?.latitude != null &&
          currentUser?.longitude != null;

      // 1) Prefer saved backend location immediately (no prompts on app open).
      if (hasSavedDbLocation && mounted) {
        setState(() {
          userLatitude = currentUser!.latitude;
          userLongitude = currentUser.longitude;
          isLoadingLocation = false;
          _isApproximateLocation = false;
          locationStatus = (currentUser.address?.isNotEmpty ?? false)
              ? currentUser.address
              : 'Using saved location';
        });
        _loadArtisansForCurrentLocation();
        _startNearbyAutoRefresh();
      }

      // 2) If no backend location, try local cache (still no prompts).
      if (!hasSavedDbLocation && (userLatitude == null || userLongitude == null)) {
        final cached = await _locationService.getCachedLocation();
        if (cached != null && mounted) {
          setState(() {
            userLatitude = cached.latitude;
            userLongitude = cached.longitude;
            isLoadingLocation = false;
            _isApproximateLocation = false;
            locationStatus = cached.address ?? 'Using saved location';
          });
          _loadArtisansForCurrentLocation();
          _startNearbyAutoRefresh();
        }
      }

      // 3) Try live location when services are on + permission granted.
      var serviceEnabled = await _locationService.isLocationServiceEnabled();
      var permission = await _locationService.checkPermissionStatus();
      var permissionGranted = permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;

      // 4) One-time startup prompt on first app open/login.
      if ((!serviceEnabled || !permissionGranted) && mounted) {
        final hasRequested = await _locationService.hasRequestedLocationPermission();
        if (!hasRequested) {
          final shouldRequest = await _showLocationPermissionRationaleDialog();
          if (shouldRequest == true) {
            // If device location is off, route user to system location settings.
            if (!serviceEnabled) {
              await _showEnableLocationServicesDialog();
              serviceEnabled = await _locationService.isLocationServiceEnabled();
            }

            // Only request runtime app permission after device location
            // services are actually enabled.
            if (serviceEnabled && !permissionGranted) {
              permission = await _locationService.requestPermissionOnce();
              permissionGranted = permission == LocationPermission.always ||
                  permission == LocationPermission.whileInUse;
            }
          } else {
            await _locationService.markLocationPromptHandled();
          }
        }
      }

      if (!serviceEnabled || !permissionGranted) {
        if (userLatitude == null || userLongitude == null) {
          final ipApplied = await _tryUseIpFallbackLocation();
          if (!ipApplied) {
            _applyDefaultLocationAndLoad();
          }
        } else if (mounted) {
          setState(() => isLoadingLocation = false);
        }
        return;
      }

      final liveResult = await _locationService.getLocation();
      if (liveResult != null && mounted) {
        setState(() {
          userLatitude = liveResult.latitude;
          userLongitude = liveResult.longitude;
          isLoadingLocation = false;
          _isApproximateLocation = false;
          locationStatus = liveResult.address ?? locationStatus;
        });

        _loadArtisansForCurrentLocation();
        _startNearbyAutoRefresh();

        // Internal sync only when we have a fresh live fix and location is ON.
        if (currentUser != null && liveResult.isLive) {
          await UpdateUserLocationService().updateUserLocation(
            UserLocationPayload(
              userId: currentUser.id,
              locationResult: liveResult,
              isArtisan: currentUser.userType == 'artisan',
            ),
          );
        }
      } else if (userLatitude == null || userLongitude == null) {
        final ipApplied = await _tryUseIpFallbackLocation();
        if (!ipApplied) {
          _applyDefaultLocationAndLoad();
        }
      } else if (mounted) {
        setState(() => isLoadingLocation = false);
      }
    } catch (e) {
      if (mounted) {
        if (userLatitude == null || userLongitude == null) {
          final ipApplied = await _tryUseIpFallbackLocation();
          if (!ipApplied) {
            _applyDefaultLocationAndLoad();
          }
        } else {
          setState(() => isLoadingLocation = false);
        }
      }
    }
  }

  Future<bool> _tryUseIpFallbackLocation() async {
    final ipLocation = await _fetchIpBasedLocation();
    if (ipLocation == null || !mounted) return false;

    final city = ipLocation.city?.trim();
    final region = ipLocation.region?.trim();
    final placeText = [
      if (city != null && city.isNotEmpty) city,
      if (region != null && region.isNotEmpty) region,
    ].join(', ');

    setState(() {
      isLoadingLocation = false;
      userLatitude = ipLocation.latitude;
      userLongitude = ipLocation.longitude;
      _isApproximateLocation = true;
      locationStatus =
          placeText.isEmpty ? 'Using approximate location' : 'Using approximate location: $placeText';
    });

    await _loadArtisansForCurrentLocation();
    _startNearbyAutoRefresh();
    return true;
  }

  Future<_IpLocationResult?> _fetchIpBasedLocation() async {
    final endpoints = <Uri>[
      Uri.parse('https://ipapi.co/json/'),
      Uri.parse('https://ipwho.is/'),
      Uri.parse('https://ipinfo.io/json'),
    ];

    for (var round = 0; round < 2; round++) {
      for (final uri in endpoints) {
        final result = await _fetchFromIpEndpoint(uri);
        if (result != null) return result;
      }
      if (round == 0) {
        await Future<void>.delayed(const Duration(milliseconds: 700));
      }
    }
    return null;
  }

  Future<_IpLocationResult?> _fetchFromIpEndpoint(Uri uri) async {
    try {
      final response = await http.get(
        uri,
        headers: const {
          'Accept': 'application/json',
          'User-Agent': 'MSpace/1.0',
        },
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode < 200 || response.statusCode >= 300) return null;
      final body = jsonDecode(response.body);
      if (body is! Map<String, dynamic>) return null;

      final parsed = _parseIpLocationBody(body);
      if (parsed == null) return null;
      if (!_isValidCoordinate(parsed.latitude, parsed.longitude)) return null;
      return parsed;
    } catch (_) {
      return null;
    }
  }

  _IpLocationResult? _parseIpLocationBody(Map<String, dynamic> body) {
    final directLat = (body['latitude'] as num?)?.toDouble() ??
        (body['lat'] as num?)?.toDouble();
    final directLng = (body['longitude'] as num?)?.toDouble() ??
        (body['lon'] as num?)?.toDouble() ??
        (body['lng'] as num?)?.toDouble();

    if (directLat != null && directLng != null) {
      return _IpLocationResult(
        latitude: directLat,
        longitude: directLng,
        city: body['city'] as String?,
        region: (body['region'] ?? body['region_name']) as String?,
      );
    }

    final loc = body['loc'];
    if (loc is String && loc.contains(',')) {
      final parts = loc.split(',');
      if (parts.length == 2) {
        final lat = double.tryParse(parts[0].trim());
        final lng = double.tryParse(parts[1].trim());
        if (lat != null && lng != null) {
          return _IpLocationResult(
            latitude: lat,
            longitude: lng,
            city: body['city'] as String?,
            region: (body['region'] ?? body['region_name']) as String?,
          );
        }
      }
    }
    return null;
  }

  bool _isValidCoordinate(double lat, double lng) {
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return false;
    if (lat == 0.0 && lng == 0.0) return false;
    return true;
  }

  void _scheduleIpFallbackRetry() {
    _ipFallbackRetryTimer?.cancel();
    _ipFallbackRetryTimer = Timer(const Duration(seconds: 8), () async {
      if (!mounted) return;
      final isDefault = locationStatus == 'Using default location' &&
          userLatitude == LocationService.defaultLatitude &&
          userLongitude == LocationService.defaultLongitude;
      if (!isDefault) return;
      await _tryUseIpFallbackLocation();
    });
  }

  void _applyDefaultLocationAndLoad() {
    if (!mounted) return;
    const defaultLat = 4.8156;
    const defaultLng = 7.0498;
    setState(() {
      isLoadingLocation = false;
      locationStatus = 'Using default location';
      userLatitude = defaultLat;
      userLongitude = defaultLng;
      _isApproximateLocation = false;
    });
    _loadArtisansForCurrentLocation();
    _startNearbyAutoRefresh();
    _scheduleIpFallbackRetry();
  }

  void _startNearbyAutoRefresh() {
    _nearbyAutoRefreshTimer?.cancel();
    _nearbyAutoRefreshTimer = Timer.periodic(
      _nearbyAutoRefreshInterval,
      (_) => _refreshNearbyArtisansSilently(),
    );
  }

  Future<void> _refreshNearbyArtisansSilently() async {
    if (!mounted || userLatitude == null || userLongitude == null) return;
    await _loadArtisansForCurrentLocation();
  }

  Future<void> _onRefresh() async {
  await _initializeData();
  }

  Future<bool?> _showLocationPermissionRationaleDialog() {
    return LocationPermissionNudge.showRationaleDialog(
      context,
      title: 'Use your location?',
      message:
          'We use your location to find artisans near you. You can continue without it.',
      primaryLabel: 'Use current location',
      secondaryLabel: 'Not now',
    );
  }

  Future<void> _showEnableLocationServicesDialog() async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Turn on location services'),
        content: const Text(
          'Device location is off. Turn it on to use your current location.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _openLocationSettingsFromHome();
            },
            child: const Text('Open settings'),
          ),
        ],
      ),
    );
  }

  Future<void> _openLocationSettingsFromHome() async {
    _retryLocationOnResume = true;

    // Let the dialog fully close before launching settings intent.
    await Future.delayed(const Duration(milliseconds: 180));

    var opened = await Geolocator.openLocationSettings();
    if (!opened) {
      // Retry once for devices that occasionally drop the first intent.
      await Future.delayed(const Duration(milliseconds: 220));
      opened = await Geolocator.openLocationSettings();
    }

    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not open device Location settings automatically. Please open it manually.',
          ),
        ),
      );
    }
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

  void _startLiveWatchers(String userId) {
    if (_liveWatchUserId == userId) return;
    _liveWatchUserId = userId;
    ref.read(systemNotificationProvider.notifier).watchNotifications(userId);
    ref.read(bookingNotificationProvider.notifier).watchNotifications(userId);
    ref.read(messageNotificationProvider.notifier).watchNotifications(userId);
    ref.read(jobNotificationProvider.notifier).watchNotifications(userId);
    ref.read(conversationProvider.notifier).loadConversations(userId);
  }

  Future<void> _loadArtisansForCurrentLocation() async {
    if (userLatitude == null || userLongitude == null) return;
    ref.read(homeResolvedLocationProvider.notifier).state = HomeResolvedLocation(
          latitude: userLatitude!,
          longitude: userLongitude!,
          isApproximate: _isApproximateLocation,
        );
    final notifier = ref.read(artisanProvider.notifier);
    if (_isApproximateLocation) {
      await notifier.loadNationwideArtisans(
        latitude: userLatitude!,
        longitude: userLongitude!,
        category: _selectedCategory,
      );
      return;
    }
    await notifier.loadNearbyArtisans(
      latitude: userLatitude!,
      longitude: userLongitude!,
      category: _selectedCategory,
    );
  }

  Future<void> _loadFeaturedForCurrentContext({bool forceRefresh = false}) async {
    final notifier = ref.read(artisanProvider.notifier);
    await notifier.loadFeaturedArtisans(
      latitude: userLatitude,
      longitude: userLongitude,
      nationwide: _isApproximateLocation,
      forceRefresh: forceRefresh,
    );
  }

  void _ensureLocationResolvedForSession(AuthState authState) {
    final nextSessionKey = authState.user?.id ?? '__guest__';
    if (_locationSessionKey == nextSessionKey) return;
    _locationSessionKey = nextSessionKey;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _initializeData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    // Subtle card color that lifts off the surface background
    final cardColor = isDark
        ? Color.alphaBlend(Colors.white.withOpacity(0.05), colorScheme.surface)
        : Color.alphaBlend(colorScheme.primary.withOpacity(0.03), colorScheme.surface);

    final authState = ref.watch(authProvider);
    final currentUser = authState.user;
    final isAuthenticated = authState.isAuthenticated;
    final artisanState = ref.watch(artisanProvider);
    _ensureLocationResolvedForSession(authState);

    if (isAuthenticated && currentUser != null) {
      _startLiveWatchers(currentUser.id);
    } else {
      _liveWatchUserId = null;
    }

    final blockedUserIds = currentUser == null
        ? <String>{}
        : ref.watch(blockedUsersProvider(currentUser.id)).maybeWhen(
              data: (items) => items.map((e) => e.blockedUserId).toSet(),
              orElse: () => <String>{},
            );

    final filteredFeaturedArtisans = artisanState.featuredArtisans
        .where((artisan) => !blockedUserIds.contains(artisan.userId))
        .toList(growable: false);
    final filteredNearbyArtisans = artisanState.nearbyArtisans
        .where((artisan) => !blockedUserIds.contains(artisan.userId))
        .toList(growable: false);

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: CustomScrollView(
          controller: _scrollController,
          physics: const ClampingScrollPhysics(),
          slivers: [
            // ── App Bar — always pinned so greeting + location stay visible ──
            SliverAppBar(
              floating: false,
              pinned: true,
              snap: false,
              toolbarHeight: 58,
              backgroundColor: colorScheme.surface,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0.5,
              shadowColor: colorScheme.shadow.withOpacity(0.08),
              title: FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isAuthenticated
                          ? 'Hello, ${currentUser?.name.split(' ').first ?? 'User'}'
                          : 'Welcome to Mspace',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    if (locationStatus != null) ...[
                      const SizedBox(height: 1),
                      Row(
                        children: [
                          Icon(Icons.location_on_rounded,
                              size: 11, color: colorScheme.primary),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              locationStatus!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                fontSize: 9,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              titleSpacing: 6,
              actions: [
                // Search — bare icon, no background
                IconButton(
                  icon: Icon(Icons.search_rounded,
                      color: colorScheme.onSurfaceVariant, size: 22),
                  onPressed: () => context.push('/search'),
                  tooltip: 'Search artisans',
                ),
                if (!isAuthenticated)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: FilledButton(
                      onPressed: () => context.push('/login'),
                      style: FilledButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        minimumSize: const Size(0, 36),
                        textStyle: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      child: const Text('Login'),
                    ),
                  )
                else
                  const SizedBox(width: 8),
              ],
            ),

            // ── Category Chips ────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: SizedBox(
                height: 40,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                  physics: const BouncingScrollPhysics(),
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    final category = _categories[index];
                    final isSelected =
                        _selectedCategory == category['name'] ||
                            (_selectedCategory == null &&
                                category['name'] == 'All');

                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: CategoryChip(
                        label: category['name'],
                        icon: category['icon'],
                        isSelected: isSelected,
                        onTap: () {
                          final isAllCategory = category['name'] == 'All';
                          setState(() {
                            _selectedCategory = isAllCategory
                                ? null
                                : category['name'];
                          });
                          if (userLatitude != null && userLongitude != null) {
                            if (isAllCategory) {
                              ref.read(artisanProvider.notifier).resetNearbySearch(
                                    latitude: userLatitude!,
                                    longitude: userLongitude!,
                                    category: null,
                                  );
                            } else {
                              _loadArtisansForCurrentLocation();
                            }
                          }
                        },
                        onLongPress: category['name'] == 'All' &&
                                userLatitude != null &&
                                userLongitude != null
                            ? () {
                                ref.read(artisanProvider.notifier).expandNearbySearch(
                                      latitude: userLatitude!,
                                      longitude: userLongitude!,
                                      category: null,
                                    );
                              }
                            : null,
                      ),
                    );
                  },
                ),
              ),
            ),

            // ── Banner Ad ─────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Center(child: BannerAdWidget()),
            ),

            // ── Guest Banner ──────────────────────────────────────────────────
            if (!isAuthenticated)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          colorScheme.primary.withOpacity(0.12),
                          colorScheme.secondary.withOpacity(0.08),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: colorScheme.primary.withOpacity(0.15),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Find Skilled Artisans',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: colorScheme.onSurface,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Connect with trusted professionals in your area',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 18),
                        FilledButton(
                          onPressed: () => context.push('/register'),
                          child: const Text('Get Started'),
                          style: FilledButton.styleFrom(
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
                            textStyle: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // ── Featured Artisans Header ──────────────────────────────────────
            if (filteredFeaturedArtisans.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(6, 24, 6, 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.star_rounded,
                            color: Colors.amber, size: 16),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Featured Artisans',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3,
                              color: colorScheme.onSurface,
                            ),
                          ),
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

              // Featured Artisans List
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 210,
                  child: artisanState.isLoadingFeatured
                      ? _buildShimmerList(cardColor)
                      : ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          physics: const BouncingScrollPhysics(),
                          itemCount: filteredFeaturedArtisans.length,
                          itemBuilder: (context, index) => Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: FeaturedArtisanCard(
                              artisan: filteredFeaturedArtisans[index],
                            ),
                          ),
                        ),
                ),
              ),
            ],

            // ── Nearby Artisans Header ────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(6, 28, 6, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.location_on_rounded,
                              color: colorScheme.primary, size: 16),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Artisans Near You',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3,
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ),
                        if (isLoadingLocation)
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colorScheme.primary,
                            ),
                          ),
                      ],
                    ),
                    if (artisanState.searchMessage != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          if (artisanState.isSearchingWider)
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: SizedBox(
                                width: 11,
                                height: 11,
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
                  ],
                ),
              ),
            ),

            // ── Nearby Artisans List ──────────────────────────────────────────
            if (artisanState.isLoadingNearby && filteredNearbyArtisans.isEmpty)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildShimmerCard(cardColor),
                    ),
                    childCount: 3,
                  ),
                ),
              )
            else if (filteredNearbyArtisans.isEmpty &&
                !artisanState.isLoadingNearby)
              SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceVariant.withOpacity(0.5),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.person_search_rounded,
                            size: 48,
                            color: colorScheme.onSurfaceVariant.withOpacity(0.6),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'No artisans found',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
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
                          icon: const Icon(Icons.refresh_rounded, size: 16),
                          label: const Text('Retry'),
                          style: FilledButton.styleFrom(
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(6, 0, 6, 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      const adInterval = 3;
                      final adSlots =
                          (filteredNearbyArtisans.length / adInterval).floor();
                      final totalCount = filteredNearbyArtisans.length + adSlots;

                      if (index >= totalCount) {
                        return artisanState.isLoadingMore
                            ? const Padding(
                                padding: EdgeInsets.all(16),
                                child: Center(
                                    child: CircularProgressIndicator()),
                              )
                            : const SizedBox(height: 80);
                      }

                      final isAdIndex =
                          (index + 1) % (adInterval + 1) == 0;
                      if (isAdIndex) {
                        return const NativeAdWidget();
                      }

                      final artisanIndex =
                          index - (index ~/ (adInterval + 1));

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _ArtisanCardWrapper(
                          cardColor: cardColor,
                          colorScheme: colorScheme,
                          child: ArtisanFeedCard(
                            artisan: filteredNearbyArtisans[artisanIndex],
                          ),
                        ),
                      );
                    },
                    childCount: filteredNearbyArtisans.isEmpty
                        ? 0
                        : filteredNearbyArtisans.length +
                            (filteredNearbyArtisans.length / 3).floor() +
                            1,
                  ),
                ),
              ),
          ],
        ),

      // ── Bottom Navigation ─────────────────────────────────────────────────
      bottomNavigationBar: isAuthenticated
          ? _buildModernBottomNav(
              context, ref, colorScheme, currentUser, isDark)
          : null,

      // ── FAB ──────────────────────────────────────────────────────────────
          floatingActionButton:
      isAuthenticated && currentUser?.userType == 'customer'
          ? SizedBox(
              height: 44,
              child: FloatingActionButton.extended(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  shape: const RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  builder: (context) => Container(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(





                          
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color:
                                colorScheme.onSurfaceVariant.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(height: 20),
                        _BottomSheetTile(
                          icon: Icons.add_circle_rounded,
                          label: 'Post New Job',
                          color: colorScheme.primary,
                          onTap: () {
                            Navigator.pop(context);
                            context.push('/post-job');
                          },
                        ),
                        const SizedBox(height: 8),
                        _BottomSheetTile(
                          icon: Icons.list_alt_rounded,
                          label: 'My Posted Jobs',
                          color: colorScheme.secondary,
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
              icon: const Icon(Icons.work_rounded, size: 14),
              label: const Text(
                'Jobs',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
              ),
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              elevation: 3,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              extendedPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
              extendedIconLabelSpacing: 4,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          )
          : null,
    );
  }

  Widget _buildModernBottomNav(
    BuildContext context,
    WidgetRef ref,
    ColorScheme colorScheme,
    dynamic currentUser,
    bool isDark,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? Color.alphaBlend(Colors.white.withOpacity(0.05), colorScheme.surface)
            : colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: colorScheme.outlineVariant.withOpacity(0.5),
            width: 0.5,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.06),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                icon: Icons.dynamic_feed_rounded,
                label: 'Feed',
                onTap: _openFeed,
                colorScheme: colorScheme,
              ),
              Consumer(
                builder: (context, ref, child) {
                  final conversationUnread = ref.watch(munreadCountProvider);
                  return _buildNavItemWithBadge(
                    icon: Icons.chat_bubble_rounded,
                    label: 'Messages',
                    badgeCount: conversationUnread,
                    onTap: () => context.push('/messages'),
                    colorScheme: colorScheme,
                  );
                },
              ),
              _buildCenterNavItem(
                icon: Icons.calendar_month_rounded,
                label: currentUser?.userType == 'artisan' ? 'Jobs' : 'Bookings',
                onTap: () => context.push('/bookings'),
                colorScheme: colorScheme,
              ),
              Consumer(
                builder: (context, ref, child) {
                  final systemUnread = ref.watch(systemUnreadCountProvider);
                  final bookingUnread = ref.watch(bookingUnreadCountProvider);
                  final jobUnread = ref.watch(jobUnreadCountProvider);
                  final total = systemUnread + bookingUnread + jobUnread;
                  return _buildNavItemWithBadge(
                    icon: Icons.notifications_rounded,
                    label: 'Alerts',
                    badgeCount: total,
                    onTap: () => context.push('/notifications'),
                    colorScheme: colorScheme,
                  );
                },
              ),
              _buildNavItem(
                icon: Icons.person_rounded,
                label: 'Profile',
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: colorScheme.onSurfaceVariant),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.1,
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 20, color: colorScheme.onSurfaceVariant),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 9,
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.1,
                  ),
                ),
              ],
            ),
            if (badgeCount > 0)
              Positioned(
                right: -4,
                top: -3,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: colorScheme.error,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: colorScheme.surface,
                      width: 1.5,
                    ),
                  ),
                  constraints:
                      const BoxConstraints(minWidth: 15, minHeight: 15),
                  child: Text(
                    badgeCount > 9 ? '9+' : '$badgeCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 7,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: colorScheme.primary,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: colorScheme.primary.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: colorScheme.onPrimary),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                color: colorScheme.onPrimary,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerList(Color cardColor) {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      itemCount: 3,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(right: 12),
        child: _buildShimmerFeaturedCard(cardColor),
      ),
    );
  }

  Widget _buildShimmerFeaturedCard(Color cardColor) {
    return Container(
      width: 150,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 100,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 11,
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceVariant
                        .withOpacity(0.6),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  height: 10,
                  width: 70,
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceVariant
                        .withOpacity(0.4),
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

  Widget _buildShimmerCard(Color cardColor) {
    return Container(
      height: 116,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}

class _IpLocationResult {
  final double latitude;
  final double longitude;
  final String? city;
  final String? region;

  const _IpLocationResult({
    required this.latitude,
    required this.longitude,
    this.city,
    this.region,
  });
}

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Premium card wrapper — no borders, layered ambient + key shadows,
/// subtle tinted surface. Clips the child so internal card borders are hidden.
class _ArtisanCardWrapper extends StatelessWidget {
  const _ArtisanCardWrapper({
    required this.child,
    required this.cardColor,
    required this.colorScheme,
  });

  final Widget child;
  final Color cardColor;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        // Layered shadows: ambient glow + directional key shadow
        boxShadow: isDark
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.35),
                  blurRadius: 20,
                  spreadRadius: 0,
                  offset: const Offset(0, 6),
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 6,
                  spreadRadius: 0,
                  offset: const Offset(0, 1),
                ),
              ]
            : [
                // Soft ambient shadow
                BoxShadow(
                  color: colorScheme.primary.withOpacity(0.06),
                  blurRadius: 24,
                  spreadRadius: 0,
                  offset: const Offset(0, 8),
                ),
                // Crisp key shadow
                BoxShadow(
                  color: Colors.black.withOpacity(0.055),
                  blurRadius: 8,
                  spreadRadius: 0,
                  offset: const Offset(0, 2),
                ),
                // Subtle top highlight (light mode only)
                BoxShadow(
                  color: Colors.white.withOpacity(0.9),
                  blurRadius: 0,
                  spreadRadius: 0,
                  offset: const Offset(0, -1),
                ),
              ],
      ),
      child: Material(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        // elevation: 0 ensures no Material border/tint bleeds through
        elevation: 0,
        child: child,
      ),
    );
  }
}

/// Polished bottom-sheet action tile.
class _BottomSheetTile extends StatelessWidget {
  const _BottomSheetTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 14),
          decoration: BoxDecoration(
            color: color.withOpacity(0.07),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.15), width: 1),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 14),
              Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
              ),
              const Spacer(),
              Icon(Icons.arrow_forward_ios_rounded,
                  size: 14, color: colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}



