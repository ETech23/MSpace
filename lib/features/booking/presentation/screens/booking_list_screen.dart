// lib/features/booking/presentation/screens/booking_list_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/booking_provider.dart';
import '../widgets/booking_card.dart';
import '../../../../core/ads/ad_widgets.dart';

class BookingListScreen extends ConsumerStatefulWidget {
  const BookingListScreen({super.key});

  @override
  ConsumerState<BookingListScreen> createState() => _BookingListScreenState();
}

class _BookingListScreenState extends ConsumerState<BookingListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _selectedStatus;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(_onTabChanged);
    
    // Load bookings on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadBookings();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    setState(() {
      switch (_tabController.index) {
        case 0:
          _selectedStatus = null; // All
          break;
        case 1:
          _selectedStatus = 'pending';
          break;
        case 2:
          _selectedStatus = 'accepted';
          break;
        case 3:
          _selectedStatus = 'in_progress';
          break;
        case 4:
          _selectedStatus = 'completed';
          break;
      }
    });
    _loadBookings();
  }

  void _loadBookings() {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    ref.read(bookingProvider.notifier).loadUserBookings(
          userId: user.id,
          userType: user.userType,
          status: _selectedStatus,
        );

    // Load stats
    ref.read(bookingProvider.notifier).loadBookingStats(
          userId: user.id,
          userType: user.userType,
        );
  }

  Future<void> _onRefresh() async {
    _loadBookings();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bookingState = ref.watch(bookingProvider);
    final user = ref.watch(authProvider).user;
    final isArtisan = user?.userType == 'artisan';

    return Scaffold(
      appBar: AppBar(
        title: Text(isArtisan ? 'My Jobs' : 'My Bookings'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              // TODO: Show filter dialog
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Filters coming soon!')),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: [
            Tab(
              text: 'All ${bookingState.stats?['total'] ?? ''}',
            ),
            Tab(
              text: 'Pending ${bookingState.stats?['pending'] ?? ''}',
            ),
            Tab(
              text: 'Accepted ${bookingState.stats?['accepted'] ?? ''}',
            ),
            const Tab(
              text: 'In Progress',
            ),
            Tab(
              text: 'Completed ${bookingState.stats?['completed'] ?? ''}',
            ),
          ],
        ),
      ),
      body: bookingState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : bookingState.error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.red[300],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Error loading bookings',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        bookingState.error!,
                        style: theme.textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _loadBookings,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                      const SizedBox(height: 16),
                      const BannerAdWidget(),
                    ],
                  ),
                )
              : bookingState.bookings.isEmpty
                  ? _buildEmptyState(context, theme, colorScheme)
                  : RefreshIndicator(
                      onRefresh: _onRefresh,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: bookingState.bookings.length +
                          (bookingState.bookings.length / 3).floor() +
                          1,
                      itemBuilder: (context, index) {
                        const adInterval = 3;
                        final adSlots =
                            (bookingState.bookings.length / adInterval).floor();
                        final totalCount = bookingState.bookings.length + adSlots;

                        if (index == totalCount) {
                          return const Center(child: BannerAdWidget());
                        }
                        final isAdIndex = (index + 1) % (adInterval + 1) == 0;
                        if (isAdIndex) {
                          return const NativeAdWidget();
                        }

                        final bookingIndex = index - (index ~/ (adInterval + 1));
                        final booking = bookingState.bookings[bookingIndex];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: BookingCard(
                              booking: booking,
                              isArtisan: isArtisan,
                              onTap: () => context.push(
                                '/bookings/${booking.id}',
                                extra: booking,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    final user = ref.read(authProvider).user;
    final isArtisan = user?.userType == 'artisan';

    String title;
    String message;
    IconData icon;

    switch (_selectedStatus) {
      case 'pending':
        title = 'No Pending Bookings';
        message = isArtisan
            ? 'No new booking requests at the moment'
            : 'You have no pending booking requests';
        icon = Icons.hourglass_empty;
        break;
      case 'accepted':
        title = 'No Accepted Bookings';
        message = 'No bookings have been accepted yet';
        icon = Icons.check_circle_outline;
        break;
      case 'in_progress':
        title = 'No Active Jobs';
        message = 'No jobs are currently in progress';
        icon = Icons.work_outline;
        break;
      case 'completed':
        title = 'No Completed Bookings';
        message = 'No bookings have been completed yet';
        icon = Icons.done_all;
        break;
      default:
        title = isArtisan ? 'No Jobs Yet' : 'No Bookings Yet';
        message = isArtisan
            ? 'When customers book your services, they will appear here'
            : 'Start booking artisans to see your bookings here';
        icon = Icons.calendar_today;
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            if (!isArtisan)
              FilledButton.icon(
                onPressed: () => context.go('/'),
                icon: const Icon(Icons.search),
                label: const Text('Find Artisans'),
              ),
            const SizedBox(height: 16),
            const BannerAdWidget(),
          ],
        ),
      ),
    );
  }
}
