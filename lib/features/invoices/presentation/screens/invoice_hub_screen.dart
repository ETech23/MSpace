import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../booking/domain/entities/booking_entity.dart';
import '../../../booking/presentation/providers/booking_provider.dart';

class InvoiceHubScreen extends ConsumerStatefulWidget {
  const InvoiceHubScreen({super.key});

  @override
  ConsumerState<InvoiceHubScreen> createState() => _InvoiceHubScreenState();
}

class _InvoiceHubScreenState extends ConsumerState<InvoiceHubScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadBookings());
  }

  void _loadBookings() {
    final user = ref.read(authProvider).user;
    if (user == null) {
      return;
    }
    ref.read(bookingProvider.notifier).loadUserBookings(
          userId: user.id,
          userType: user.userType,
        );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final user = ref.watch(authProvider).user;
    final bookingState = ref.watch(bookingProvider);

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please sign in to view invoices.')),
      );
    }

    final eligibleBookings = bookingState.bookings.where((booking) {
      return booking.status == BookingStatus.accepted ||
          booking.status == BookingStatus.inProgress ||
          booking.status == BookingStatus.completed;
    }).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Invoices'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => _loadBookings(),
        child: bookingState.isLoading
            ? const Center(child: CircularProgressIndicator())
            : eligibleBookings.isEmpty
                ? ListView(
                    padding: const EdgeInsets.all(32),
                    children: [
                      FilledButton.icon(
                        onPressed: () => context.push('/profile/invoices/new'),
                        icon: const Icon(Icons.add),
                        label: const Text('Create New Invoice'),
                      ),
                      const SizedBox(height: 80),
                      Icon(
                        Icons.receipt_long_rounded,
                        size: 72,
                        color: colorScheme.outline,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No invoices yet',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'You can start a manual invoice right away or use eligible bookings below when they exist.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: eligibleBookings.length + 1,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF263238), Color(0xFF455A64)],
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Need an invoice without a booking?',
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Create a standalone invoice and enter the exact service details, client info, and pricing manually.',
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        color: Colors.white.withOpacity(0.9),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              FilledButton.icon(
                                onPressed: () => context.push('/profile/invoices/new'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: const Color(0xFF263238),
                                ),
                                icon: const Icon(Icons.add),
                                label: const Text('New'),
                              ),
                            ],
                          ),
                        );
                      }
                      final booking = eligibleBookings[index - 1];
                      final counterparty = user.isArtisan
                          ? (booking.customerName ?? 'Client')
                          : (booking.artisanName ?? 'Service Provider');
                      final ctaLabel =
                          user.isArtisan ? 'Create Invoice' : 'Open Invoice';

                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: colorScheme.surface,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: colorScheme.primaryContainer,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Icon(
                                    Icons.receipt_long_rounded,
                                    color: colorScheme.onPrimaryContainer,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        booking.serviceType,
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        counterparty,
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Text(
                              booking.description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: FilledButton.icon(
                                    onPressed: () => context.push(
                                      '/bookings/${booking.id}/invoice',
                                      extra: booking,
                                    ),
                                    icon: const Icon(Icons.picture_as_pdf),
                                    label: Text(ctaLabel),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                OutlinedButton(
                                  onPressed: () => context.push(
                                    '/bookings/${booking.id}',
                                    extra: booking,
                                  ),
                                  child: const Text('Open Booking'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
