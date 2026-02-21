import '../../domain/entities/booking_entity.dart';

class BookingModel extends BookingEntity {
   BookingModel({
    required super.id,
    required super.clientId,
    required super.artisanId,
    required super.artisanProfileId,
    required super.serviceType,
    required super.description,
    required super.scheduledDate,
    required super.locationAddress,
    super.locationLatitude,
    required super.preferredTime,
    super.locationLongitude,
    super.estimatedPrice,
    super.finalPrice,
    required super.status,
    required super.paymentStatus,
    super.customerNotes,
    super.artisanNotes,
    super.cancellationReason,
    super.cancelledBy,
    super.cancelledAt,
    required super.createdAt,
    required super.updatedAt,
    super.acceptedAt,
    super.startedAt,
    super.completedAt,
    super.customerName,
    super.customerEmail,
    super.customerPhone,
    super.customerPhotoUrl,
    super.artisanName,
    super.artisanEmail,
    super.artisanPhone,
    super.artisanPhotoUrl,
    super.artisanCategory,
    super.artisanRating,
  });

  factory BookingModel.fromJson(Map<String, dynamic> json) {
    return BookingModel(
      id: json['id'] as String,
      clientId: json['client_id'] as String,
      artisanId: json['artisan_id'] as String,
      artisanProfileId: json['artisan_profile_id'] as String,
      serviceType: json['service_type'] as String,
      description: json['description'] as String,
      scheduledDate: DateTime.parse(json['scheduled_date'] as String),
      locationAddress: json['location_address'] as String,
      locationLatitude: (json['location_latitude'] as num?)?.toDouble(),
      preferredTime: json['preferred_time'] as String? ?? '',
      locationLongitude: (json['location_longitude'] as num?)?.toDouble(),
      estimatedPrice: (json['estimated_price'] as num?)?.toDouble(),
      finalPrice: (json['final_price'] as num?)?.toDouble(),
      status: _parseStatus(json['status'] as String),
      paymentStatus: _parsePaymentStatus(json['payment_status'] as String),
      customerNotes: json['customer_notes'] as String?,
      artisanNotes: json['artisan_notes'] as String?,
      cancellationReason: json['cancellation_reason'] as String?,
      cancelledBy: json['cancelled_by'] as String?,
      cancelledAt: json['cancelled_at'] != null
          ? DateTime.parse(json['cancelled_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      acceptedAt: json['accepted_at'] != null
          ? DateTime.parse(json['accepted_at'] as String)
          : null,
      startedAt: json['started_at'] != null
          ? DateTime.parse(json['started_at'] as String)
          : null,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      customerName: json['customer_name'] as String?,
      customerEmail: json['customer_email'] as String?,
      customerPhone: json['customer_phone'] as String?,
      customerPhotoUrl: json['customer_photo_url'] as String?,
      artisanName: json['artisan_name'] as String?,
      artisanEmail: json['artisan_email'] as String?,
      artisanPhone: json['artisan_phone'] as String?,
      artisanPhotoUrl: json['artisan_photo_url'] as String?,
      artisanCategory: json['artisan_category'] as String?,
      artisanRating: (json['artisan_rating'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'client_id': clientId,
      'artisan_id': artisanId,
      'artisan_profile_id': artisanProfileId,
      'service_type': serviceType,
      'scheduled_date': scheduledDate.toIso8601String(),
      'location_address': locationAddress,
      'location_latitude': locationLatitude,
      'preferred_time': preferredTime,
      'location_longitude': locationLongitude,
      'estimated_price': estimatedPrice,
      'final_price': finalPrice,
      'status': _statusToString(status),
      'payment_status': _paymentStatusToString(paymentStatus),
      'customer_notes': customerNotes,
      'artisan_notes': artisanNotes,
      'cancellation_reason': cancellationReason,
      'cancelled_by': cancelledBy,
      'cancelled_at': cancelledAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'accepted_at': acceptedAt?.toIso8601String(),
      'started_at': startedAt?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
    };
  }

  static BookingStatus _parseStatus(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return BookingStatus.pending;
      case 'accepted':
        return BookingStatus.accepted;
      case 'rejected':
        return BookingStatus.rejected;
      case 'in_progress':
        return BookingStatus.inProgress;
      case 'completed':
        return BookingStatus.completed;
      case 'cancelled':
        return BookingStatus.cancelled;
      case 'disputed':
        return BookingStatus.disputed;
      default:
        return BookingStatus.pending;
    }
  }

  static String _statusToString(BookingStatus status) {
    switch (status) {
      case BookingStatus.pending:
        return 'pending';
      case BookingStatus.accepted:
        return 'accepted';
      case BookingStatus.rejected:
        return 'rejected';
      case BookingStatus.inProgress:
        return 'in_progress';
      case BookingStatus.completed:
        return 'completed';
      case BookingStatus.cancelled:
        return 'cancelled';
      case BookingStatus.disputed:
        return 'disputed';
    }
  }

  static PaymentStatus _parsePaymentStatus(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
        return PaymentStatus.paid;
      case 'refunded':
        return PaymentStatus.refunded;
      default:
        return PaymentStatus.unpaid;
    }
  }

  static String _paymentStatusToString(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.unpaid:
        return 'unpaid';
      case PaymentStatus.paid:
        return 'paid';
      case PaymentStatus.refunded:
        return 'refunded';
    }
  }

  BookingEntity toEntity() => BookingEntity(
        id: id,
        clientId: clientId,
        artisanId: artisanId,
        artisanProfileId: artisanProfileId,
        serviceType: serviceType,
        description: description,
        preferredTime: preferredTime,
        scheduledDate: scheduledDate,
        locationAddress: locationAddress,
        locationLatitude: locationLatitude,
        locationLongitude: locationLongitude,
        estimatedPrice: estimatedPrice,
        finalPrice: finalPrice,
        status: status,
        paymentStatus: paymentStatus,
        customerNotes: customerNotes,
        artisanNotes: artisanNotes,
        cancellationReason: cancellationReason,
        cancelledBy: cancelledBy,
        cancelledAt: cancelledAt,
        createdAt: createdAt,
        updatedAt: updatedAt,
        acceptedAt: acceptedAt,
        startedAt: startedAt,
        completedAt: completedAt,
        customerName: customerName,
        customerEmail: customerEmail,
        customerPhone: customerPhone,
        customerPhotoUrl: customerPhotoUrl,
        artisanName: artisanName,
        artisanEmail: artisanEmail,
        artisanPhone: artisanPhone,
        artisanPhotoUrl: artisanPhotoUrl,
        artisanCategory: artisanCategory,
        artisanRating: artisanRating,
      );
}