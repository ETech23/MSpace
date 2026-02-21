import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

class RealtimeService {
  final SupabaseClient _client = SupabaseConfig.client;
  final Map<String, RealtimeChannel> _channels = {};

  /// Subscribe to booking updates
  RealtimeChannel subscribeToBookings({
    required String userId,
    required Function(Map<String, dynamic>) onInsert,
    required Function(Map<String, dynamic>) onUpdate,
  }) {
    final channelName = 'bookings:$userId';
    
    // Remove existing channel if present
    _channels[channelName]?.unsubscribe();

    final channel = _client
        .channel(channelName)
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'bookings',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.or,
            filters: [
              PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'client_id',
                value: userId,
              ),
              PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'artisan_id',
                value: userId,
              ),
            ],
          ),
          callback: (payload) => onInsert(payload.newRecord),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'bookings',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.or,
            filters: [
              PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'client_id',
                value: userId,
              ),
              PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'artisan_id',
                value: userId,
              ),
            ],
          ),
          callback: (payload) => onUpdate(payload.newRecord),
        )
        .subscribe();

    _channels[channelName] = channel;
    return channel;
  }

  /// Subscribe to notifications
  RealtimeChannel subscribeToNotifications({
    required String userId,
    required Function(Map<String, dynamic>) onNewNotification,
  }) {
    final channelName = 'notifications:$userId';
    
    _channels[channelName]?.unsubscribe();

    final channel = _client
        .channel(channelName)
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) => onNewNotification(payload.newRecord),
        )
        .subscribe();

    _channels[channelName] = channel;
    return channel;
  }

  /// Subscribe to messages for a booking
  RealtimeChannel subscribeToMessages({
    required String bookingId,
    required Function(Map<String, dynamic>) onNewMessage,
  }) {
    final channelName = 'messages:$bookingId';
    
    _channels[channelName]?.unsubscribe();

    final channel = _client
        .channel(channelName)
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'booking_id',
            value: bookingId,
          ),
          callback: (payload) => onNewMessage(payload.newRecord),
        )
        .subscribe();

    _channels[channelName] = channel;
    return channel;
  }

  /// Unsubscribe from a specific channel
  void unsubscribe(String channelName) {
    _channels[channelName]?.unsubscribe();
    _channels.remove(channelName);
  }

  /// Unsubscribe from all channels
  void unsubscribeAll() {
    for (final channel in _channels.values) {
      channel.unsubscribe();
    }
    _channels.clear();
  }

  /// Check channel status
  RealtimeChannelStatus? getChannelStatus(String channelName) {
    return _channels[channelName]?.status;
  }
}