// TODO Implement this library.// lib/features/booking/presentation/widgets/booking_status_timeline.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/booking_entity.dart';

class BookingStatusTimeline extends StatelessWidget {
  final BookingEntity booking;

  const BookingStatusTimeline({
    super.key,
    required this.booking,
  });

  List<TimelineItem> _buildTimelineItems() {
    final items = <TimelineItem>[];

    // Created
    items.add(TimelineItem(
      title: 'Booking Created',
      timestamp: booking.createdAt,
      icon: Icons.add_circle,
      isCompleted: true,
    ));

    // Pending/Accepted/Rejected
    if (booking.status == BookingStatus.accepted ||
        booking.status == BookingStatus.inProgress ||
        booking.status == BookingStatus.completed) {
      items.add(TimelineItem(
        title: 'Accepted by Artisan',
        timestamp: booking.acceptedAt,
        icon: Icons.check_circle,
        isCompleted: true,
      ));
    } else if (booking.status == BookingStatus.rejected) {
      items.add(TimelineItem(
        title: 'Rejected by Artisan',
        timestamp: booking.rejectedAt,
        subtitle: booking.rejectionReason,
        icon: Icons.cancel,
        isCompleted: true,
        isFailed: true,
      ));
    } else if (booking.status == BookingStatus.cancelled) {
      items.add(TimelineItem(
        title: 'Booking Cancelled',
        timestamp: booking.cancelledAt,
        subtitle: booking.cancellationReason,
        icon: Icons.block,
        isCompleted: true,
        isFailed: true,
      ));
    } else {
      items.add(TimelineItem(
        title: 'Awaiting Confirmation',
        icon: Icons.hourglass_empty,
        isCompleted: false,
      ));
    }

    // In Progress
    if (booking.status == BookingStatus.inProgress ||
        booking.status == BookingStatus.completed) {
      items.add(TimelineItem(
        title: 'Job Started',
        timestamp: booking.startedAt,
        icon: Icons.work,
        isCompleted: true,
      ));
    } else if (booking.status == BookingStatus.accepted) {
      items.add(TimelineItem(
        title: 'Job Not Started',
        icon: Icons.work_outline,
        isCompleted: false,
      ));
    }

    // Completed
    if (booking.status == BookingStatus.completed) {
      items.add(TimelineItem(
        title: 'Job Completed',
        timestamp: booking.completedAt,
        icon: Icons.done_all,
        isCompleted: true,
      ));
    } else if (booking.status == BookingStatus.inProgress ||
        booking.status == BookingStatus.accepted) {
      items.add(TimelineItem(
        title: 'Completion Pending',
        icon: Icons.pending,
        isCompleted: false,
      ));
    }

    return items;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final items = _buildTimelineItems();

    return Column(
      children: List.generate(items.length, (index) {
        final item = items[index];
        final isLast = index == items.length - 1;

        return _TimelineItemWidget(
          item: item,
          isLast: isLast,
          theme: theme,
          colorScheme: colorScheme,
        );
      }),
    );
  }
}

class TimelineItem {
  final String title;
  final String? subtitle;
  final DateTime? timestamp;
  final IconData icon;
  final bool isCompleted;
  final bool isFailed;

  TimelineItem({
    required this.title,
    this.subtitle,
    this.timestamp,
    required this.icon,
    required this.isCompleted,
    this.isFailed = false,
  });
}

class _TimelineItemWidget extends StatelessWidget {
  final TimelineItem item;
  final bool isLast;
  final ThemeData theme;
  final ColorScheme colorScheme;

  const _TimelineItemWidget({
    required this.item,
    required this.isLast,
    required this.theme,
    required this.colorScheme,
  });

  Color _getColor() {
    if (item.isFailed) return Colors.red;
    if (item.isCompleted) return colorScheme.primary;
    return colorScheme.onSurfaceVariant.withOpacity(0.3);
  }

  @override
  Widget build(BuildContext context) {
    final color = _getColor();

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline indicator
          Column(
            children: [
              // Circle with icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: item.isCompleted
                      ? color.withOpacity(0.15)
                      : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: color,
                    width: 2,
                  ),
                ),
                child: Icon(
                  item.icon,
                  size: 20,
                  color: color,
                ),
              ),
              // Connecting line
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: color.withOpacity(0.3),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          // Content
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: item.isCompleted
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: item.isCompleted
                          ? colorScheme.onSurface
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (item.timestamp != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('MMM dd, yyyy • hh:mm a').format(item.timestamp!),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (item.subtitle != null) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        item.subtitle!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}