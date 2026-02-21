// lib/features/booking/presentation/screens/booking_detail_screen.dart

import 'package:artisan_marketplace/features/reviews/presentation/providers/review_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../profile/presentation/screens/user_profile_screen.dart'; 
import '../../domain/entities/booking_entity.dart';
import '../providers/booking_provider.dart';
import '../widgets/booking_status_timeline.dart';
import '../../../trust/presentation/providers/trust_provider.dart';
import '../../../messaging/presentation/screens/chat_screen.dart';
import '../../../messaging/domain/usecases/get_or_create_conversation_usecase.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/ads/ad_widgets.dart';

class BookingDetailScreen extends ConsumerStatefulWidget {
  final String bookingId;
  final BookingEntity? booking;

  const BookingDetailScreen({
    super.key,
    required this.bookingId,
    this.booking,
  });

  @override
  ConsumerState<BookingDetailScreen> createState() => _BookingDetailScreenState();
}

class _BookingDetailScreenState extends ConsumerState<BookingDetailScreen> {
  final _rejectionReasonController = TextEditingController();
  final _cancellationReasonController = TextEditingController();
  String? _currentBookingId;

  @override
  void initState() {
    super.initState();
    _currentBookingId = widget.bookingId;
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadBooking();
    });
  }

  void _loadBooking() {
    if (widget.booking == null) {
      ref.read(bookingProvider.notifier).loadBookingById(widget.bookingId);
    }
  }

  @override
  void didUpdateWidget(BookingDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (oldWidget.bookingId != widget.bookingId) {
      _currentBookingId = widget.bookingId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadBooking();
      });
    }
  }

  @override
  void dispose() {
    _rejectionReasonController.dispose();
    _cancellationReasonController.dispose();
    super.dispose();
  }

  Future<void> _openMaps(double? lat, double? lng, String address) async {
    if (lat != null && lng != null) {
      final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Location: $address')),
        );
      }
    }
  }

  void _navigateToUserProfile({
    required String userId,
    required String userType,
    required String userName,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserProfileScreen(
          userId: userId,
          userType: userType,
          userName: userName,
        ),
      ),
    );
  }

  Future<void> _startConversation(String otherUserId, String otherUserName, String? otherUserPhotoUrl) async {
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
      bookingId: widget.bookingId,
    );

    if (!mounted) return;
    
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

  Future<void> _acceptBooking(String bookingId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Accept Booking'),
        content: const Text('Are you sure you want to accept this booking?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Accept'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(bookingProvider.notifier).acceptBooking(bookingId);
    }
  }

  Future<void> _rejectBooking(String bookingId) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Booking'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please provide a reason for rejection:'),
            const SizedBox(height: 16),
            TextField(
              controller: _rejectionReasonController,
              decoration: const InputDecoration(
                labelText: 'Reason',
                border: OutlineInputBorder(),
                hintText: 'e.g., Not available on this date',
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context, _rejectionReasonController.text);
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (reason != null && reason.isNotEmpty) {
      final success = await ref.read(bookingProvider.notifier).rejectBooking(
            bookingId: bookingId,
            reason: reason,
          );
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Booking rejected'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Future<void> _startBooking(String bookingId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Start Job'),
        content: const Text('Mark this booking as in progress?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Start'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await ref.read(bookingProvider.notifier).startBooking(bookingId);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Job started!'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    }
  }

  Future<void> _completeBooking(String bookingId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Complete Job'),
        content: const Text(
          'Mark this booking as completed? The customer will be able to leave a review.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Complete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await ref.read(bookingProvider.notifier).completeBooking(bookingId);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Booking completed successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _cancelBooking(String bookingId) async {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Booking'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Are you sure you want to cancel this booking?'),
            const SizedBox(height: 16),
            TextField(
              controller: _cancellationReasonController,
              decoration: const InputDecoration(
                labelText: 'Reason (Optional)',
                border: OutlineInputBorder(),
                hintText: 'Why are you cancelling?',
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Go Back'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context, _cancellationReasonController.text);
            },
            child: const Text('Cancel Booking'),
          ),
        ],
      ),
    );

    if (reason != null) {
      final success = await ref.read(bookingProvider.notifier).cancelBooking(
            bookingId: bookingId,
            cancelledBy: user.userType,
            reason: reason.isEmpty ? 'No reason provided' : reason,
          );
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Booking cancelled'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bookingState = ref.watch(bookingProvider);
    final user = ref.watch(authProvider).user;
    
    // Safety check for booking reload
    final currentBooking = bookingState.selectedBooking;
    if (currentBooking?.id != _currentBookingId && 
        widget.booking?.id != _currentBookingId &&
        !bookingState.isLoading &&
        widget.booking == null &&
        mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadBooking();
      });
    }
    
    // Determine user role in this booking
    final booking = widget.booking ?? currentBooking;
    final isArtisan = booking != null && user != null && booking.artisanId == user.id;
    final isCustomer = booking != null && user != null && booking.clientId == user.id;

    // Listen for state changes
    ref.listen<BookingState>(bookingProvider, (previous, next) {
      if (next.error != null && next.error != previous?.error && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: Colors.red,
          ),
        );
      }
      
      if (next.successMessage != null && 
          next.successMessage != previous?.successMessage && 
          mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.successMessage!),
            backgroundColor: Colors.green,
          ),
        );
      }
    });

    // Loading state
    if (booking == null && bookingState.isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Booking Details')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Error state
    if (booking == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Booking Details')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: colorScheme.error),
              const SizedBox(height: 16),
              Text(
                'Booking not found',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                bookingState.error ?? 'Unable to load booking details',
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => ref.read(bookingProvider.notifier).loadBookingById(widget.bookingId),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    // User information for display
    final displayName = isArtisan ? booking.customerName : booking.artisanName;
    final displayPhotoUrl = isArtisan ? booking.customerPhotoUrl : booking.artisanPhotoUrl;
    final userRole = isArtisan ? 'Service Provider' : 'Customer';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Booking Details'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadBooking(),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatusHeader(booking, theme, colorScheme),
                _buildRoleIndicator(userRole, theme, colorScheme),
                _buildUserInfoCard(
  booking: booking,
  theme: theme,
  colorScheme: colorScheme,
  displayName: displayName,
  displayPhotoUrl: displayPhotoUrl,
  isArtisan: isArtisan,
  onProfileTap: () {
    // Step 1: Determine which user we're viewing
    final viewingUserId = isArtisan ? booking.clientId : booking.artisanId;
    
    // Step 2: Check if that user IS the artisan in this booking
    // (They might be viewing from different contexts)
    final viewingUserType = (viewingUserId == booking.artisanId) ? 'artisan' : 'client';
    
    _navigateToUserProfile(
      userId: viewingUserId,
      userType: viewingUserType,
      userName: displayName ?? 'Unknown',
    );
  },
  onMessageTap: () {
  final otherUserId = isArtisan ? booking.clientId : booking.artisanId;
  final otherUserName = displayName ?? 'User';
  final otherUserPhotoUrl = displayPhotoUrl;
  
  _startConversation(otherUserId, otherUserName, otherUserPhotoUrl);
},
),
                _buildServiceDetails(booking, theme, colorScheme),
                _buildLocationDetails(booking, theme, colorScheme),
                if (booking.customerNotes != null)
                  _buildAdditionalNotes(booking, theme, colorScheme),
                _buildDisputeSection(booking, theme, colorScheme),
                _buildStatusTimeline(booking, theme, colorScheme),
                const Center(child: BannerAdWidget()),
                const SizedBox(height: 100),
              ],
            ),
          ),
          if (bookingState.isUpdating)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Updating booking...'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: _buildActionButtons(
        context: context,
        booking: booking,
        isArtisan: isArtisan,
        isCustomer: isCustomer,
        theme: theme,
        colorScheme: colorScheme,
      ),
    );
  }

  // MARK: - UI Components

  Widget _buildRoleIndicator(
    String role,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.primary.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            role == 'Service Provider' ? Icons.work : Icons.person,
            size: 16,
            color: colorScheme.onPrimaryContainer,
          ),
          const SizedBox(width: 8),
          Text(
            'Your role: $role',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusHeader(
    BookingEntity booking,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (booking.status) {
      case BookingStatus.pending:
        statusColor = Colors.orange;
        statusText = 'Pending Confirmation';
        statusIcon = Icons.hourglass_empty;
        break;
      case BookingStatus.accepted:
        statusColor = Colors.blue;
        statusText = 'Accepted';
        statusIcon = Icons.check_circle;
        break;
      case BookingStatus.inProgress:
        statusColor = Colors.purple;
        statusText = 'In Progress';
        statusIcon = Icons.work;
        break;
      case BookingStatus.completed:
        statusColor = Colors.green;
        statusText = 'Completed';
        statusIcon = Icons.done_all;
        break;
      case BookingStatus.cancelled:
        statusColor = Colors.red;
        statusText = 'Cancelled';
        statusIcon = Icons.block;
        break;
      case BookingStatus.rejected:
        statusColor = Colors.red;
        statusText = 'Rejected';
        statusIcon = Icons.cancel;
        break;
      case BookingStatus.disputed:
        statusColor = Colors.amber;
        statusText = 'Disputed';
        statusIcon = Icons.warning;
        break;
      default:
        statusColor = Colors.grey;
        statusText = 'Unknown';
        statusIcon = Icons.help;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        border: Border(
          bottom: BorderSide(color: statusColor.withOpacity(0.3)),
        ),
      ),
      child: Column(
        children: [
          Icon(statusIcon, size: 48, color: statusColor),
          const SizedBox(height: 12),
          Text(
            statusText,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: statusColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Booking ID: ${booking.id.substring(0, 8)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserInfoCard({
    required BookingEntity booking,
    required ThemeData theme,
    required ColorScheme colorScheme,
    required String? displayName,
    required String? displayPhotoUrl,
    required bool isArtisan,
    required VoidCallback onProfileTap,
    required VoidCallback onMessageTap,
  }) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outline.withOpacity(0.2)),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isArtisan ? 'Customer Information' : 'Artisan Information',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              InkWell(
                onTap: onProfileTap,
                borderRadius: BorderRadius.circular(8),
                child: Row(
                  children: [
                    Text(
                      'View Profile',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.primary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right,
                      color: colorScheme.primary,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              // Fixed Profile Image with proper error handling
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: colorScheme.primary.withOpacity(0.2),
                    width: 1.5,
                  ),
                ),
                child: ClipOval(
                  child: _buildProfileImage(displayPhotoUrl, colorScheme),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName ?? 'Unknown',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (!isArtisan && booking.artisanCategory != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        booking.artisanCategory!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.primary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    // Privacy note - No phone number displayed
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.lock,
                            size: 14,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Contact details are private for security',
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
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Action Buttons Row
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onProfileTap,
                  icon: const Icon(Icons.person_outline),
                  label: const Text('View Full Profile'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: onMessageTap,
                  icon: const Icon(Icons.message_outlined, size: 18),
                  label: const Text('Message'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
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

    // Fix common URL issues
    String fixedUrl = photoUrl;
    
    // If it's a relative path or just a filename
    if (!fixedUrl.startsWith('http')) {
      // Try to construct proper URL
      if (fixedUrl.startsWith('/')) {
        // Remove leading slash if present
        fixedUrl = fixedUrl.substring(1);
      }
      // You might need to adjust this based on your storage setup
      fixedUrl = 'https://your-supabase-project.supabase.co/storage/v1/object/public/avatars/$fixedUrl';
    }

    return Image.network(
      fixedUrl,
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
        print('❌ Image load error for URL: $fixedUrl');
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

  Widget _buildServiceDetails(
    BookingEntity booking,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outline.withOpacity(0.2)),
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
          Text(
            'Service Details',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildDetailRow(
            Icons.build,
            'Service Type',
            booking.serviceType,
            theme,
            colorScheme,
          ),
          const SizedBox(height: 12),
          _buildDetailRow(
            Icons.description,
            'Description',
            booking.description,
            theme,
            colorScheme,
          ),
          const SizedBox(height: 12),
          _buildDetailRow(
            Icons.calendar_today,
            'Scheduled Date',
            DateFormat('EEEE, MMMM dd, yyyy').format(booking.scheduledDate),
            theme,
            colorScheme,
          ),
          const SizedBox(height: 12),
          _buildDetailRow(
            Icons.access_time,
            'Scheduled Time',
            DateFormat('hh:mm a').format(booking.scheduledDate),
            theme,
            colorScheme,
          ),
          if (booking.estimatedPrice != null) ...[
            const SizedBox(height: 12),
            _buildDetailRow(
              Icons.attach_money,
              'Estimated Budget',
              '₦${booking.estimatedPrice!.toStringAsFixed(0)}',
              theme,
              colorScheme,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLocationDetails(
    BookingEntity booking,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outline.withOpacity(0.2)),
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
              Icon(Icons.location_on, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Location',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            booking.locationAddress,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => _openMaps(
              booking.locationLatitude,
              booking.locationLongitude,
              booking.locationAddress,
            ),
            icon: const Icon(Icons.map),
            label: const Text('Open in Maps'),
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.primaryContainer,
              foregroundColor: colorScheme.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdditionalNotes(
    BookingEntity booking,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outline.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.note, color: colorScheme.secondary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Additional Notes',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            booking.customerNotes!,
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusTimeline(
    BookingEntity booking,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outline.withOpacity(0.2)),
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
          Text(
            'Booking Timeline',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          BookingStatusTimeline(booking: booking),
        ],
      ),
    );
  }

  Widget _buildDisputeSection(
    BookingEntity booking,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    final disputesAsync = ref.watch(disputesByBookingProvider(booking.id));
    final canOpenDispute = booking.status == BookingStatus.accepted ||
        booking.status == BookingStatus.inProgress ||
        booking.status == BookingStatus.completed ||
        booking.status == BookingStatus.disputed;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outline.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: disputesAsync.when(
        data: (disputes) {
          final latest = disputes.isNotEmpty ? disputes.first : null;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Dispute',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              if (latest != null)
                Text(
                  'Status: ${latest.status.replaceAll('_', ' ')}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                )
              else
                Text(
                  'No disputes for this booking.',
                  style: theme.textTheme.bodyMedium,
                ),
              const SizedBox(height: 12),
              if (canOpenDispute && latest == null)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => context.push('/bookings/${booking.id}/dispute'),
                    icon: const Icon(Icons.report_gmailerrorred),
                    label: const Text('Open Dispute'),
                  ),
                ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Text('Error loading disputes: $err'),
      ),
    );
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
              const SizedBox(height: 4),
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

  Widget? _buildActionButtons({
    required BuildContext context,
    required BookingEntity booking,
    required bool isArtisan,
    required bool isCustomer,
    required ThemeData theme,
    required ColorScheme colorScheme,
  }) {
    List<Widget> buttons = [];

    if (isArtisan) {
      // Artisan actions based on booking status
      switch (booking.status) {
        case BookingStatus.pending:
          buttons = [
            Expanded(
              child: OutlinedButton(
                onPressed: () => _rejectBooking(booking.id),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Reject'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: FilledButton(
                onPressed: () => _acceptBooking(booking.id),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Accept Booking'),
              ),
            ),
          ];
          break;
        case BookingStatus.accepted:
          buttons = [
            Expanded(
              child: FilledButton(
                onPressed: () => _startBooking(booking.id),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Start Job'),
              ),
            ),
          ];
          break;
        case BookingStatus.inProgress:
          buttons = [
            Expanded(
              child: FilledButton(
                onPressed: () => _completeBooking(booking.id),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Mark as Complete'),
              ),
            ),
          ];
          break;
        default:
          return null;
      }
    } else if (isCustomer) {
      // Customer actions based on booking status
      if (booking.status == BookingStatus.pending ||
          booking.status == BookingStatus.accepted) {
        buttons = [
          Expanded(
            child: OutlinedButton(
              onPressed: () => _cancelBooking(booking.id),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Cancel Booking'),
            ),
          ),
        ];
      } else if (booking.status == BookingStatus.completed) {
        // ✅ FIX: Use _ReviewActionBar widget instead
        return _ReviewActionBar(booking: booking);
      } else {
        return null;
      }
    } else {
      // User is neither artisan nor customer in this booking
      return null;
    }

    if (buttons.isEmpty) return null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
        border: Border(
          top: BorderSide(
            color: colorScheme.outline.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(children: buttons),
      ),
    );
  }
}

class _ReviewActionBar extends ConsumerWidget {
  final BookingEntity booking;

  const _ReviewActionBar({
    required this.booking,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return FutureBuilder(
      future: ref.read(reviewProvider.notifier).loadReviewByBooking(booking.id),
      builder: (context, snapshot) {
        // Check if review exists
        final reviewState = ref.watch(reviewProvider);
        final hasReview = reviewState.currentReview != null;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
            border: Border(
              top: BorderSide(
                color: colorScheme.outline.withOpacity(0.1),
                width: 1,
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: hasReview
                ? OutlinedButton.icon(
                    onPressed: () => context.push('/reviews'),
                    icon: const Icon(Icons.visibility),
                    label: const Text('View Your Review'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  )
                : FilledButton.icon(
                    onPressed: () {
                      context.pushNamed('createReview', extra: {
                        'bookingId': booking.id,
                        'artisanId': booking.artisanId,
                        'artisanName': booking.artisanName ?? 'Artisan',
                        'artisanPhotoUrl': booking.artisanPhotoUrl,
                      });
                    },
                    icon: const Icon(Icons.star),
                    label: const Text('Write a Review'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.amber[700],
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
          ),
        );
      },
    );
  }
}

