// lib/features/booking/domain/entities/booking_entity.dart

enum BookingStatus {
  pending,
  accepted,
  rejected,
  inProgress,
  completed,
  cancelled,
  disputed,
}

enum PaymentStatus {
  unpaid,
  paid,
  refunded,
}

class BookingEntity {
  final String id;
  final String clientId; // Match your existing code
  final String artisanId;
  final String artisanProfileId;
  final String serviceType;
  final String description;
  final DateTime scheduledDate;
  final String preferredTime;
  final String locationAddress;
  final double? locationLatitude;
  final double? locationLongitude;
  final BookingStatus status;
  final PaymentStatus paymentStatus;
  final double? estimatedPrice;
  final double? finalPrice;
  final String? customerNotes;
  final String? artisanNotes;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Additional user info (joined from database)
  final String? customerName;
  final String? customerEmail;
  final String? customerPhone;
  final String? customerPhotoUrl;
  final String? artisanName;
  final String? artisanEmail;
  final String? artisanPhone;
  final String? artisanPhotoUrl;
  final String? artisanCategory;
  final double? artisanRating;

  // Status timestamps
  final DateTime? acceptedAt;
  final DateTime? rejectedAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;

  // Rejection/Cancellation reasons
  final String? rejectionReason;
  final String? cancellationReason;
  final String? cancelledBy;

  BookingEntity({
    required this.id,
    required this.clientId,
    required this.artisanId,
    required this.artisanProfileId,
    required this.serviceType,
    required this.description,
    required this.scheduledDate,
    required this.preferredTime,
    required this.locationAddress,
    this.locationLatitude,
    this.locationLongitude,
    required this.status,
    required this.paymentStatus,
    this.estimatedPrice,
    this.finalPrice,
    this.customerNotes,
    this.artisanNotes,
    required this.createdAt,
    required this.updatedAt,
    this.customerName,
    this.customerEmail,
    this.customerPhone,
    this.customerPhotoUrl,
    this.artisanName,
    this.artisanEmail,
    this.artisanPhone,
    this.artisanPhotoUrl,
    this.artisanCategory,
    this.artisanRating,
    this.acceptedAt,
    this.rejectedAt,
    this.startedAt,
    this.completedAt,
    this.cancelledAt,
    this.rejectionReason,
    this.cancellationReason,
    this.cancelledBy,
  });

  BookingEntity copyWith({
    String? id,
    String? clientId,
    String? artisanId,
    String? artisanProfileId,
    String? serviceType,
    String? description,
    DateTime? scheduledDate,
    String? preferredTime,
    String? locationAddress,
    double? locationLatitude,
    double? locationLongitude,
    BookingStatus? status,
    PaymentStatus? paymentStatus,
    double? estimatedPrice,
    double? finalPrice,
    String? customerNotes,
    String? artisanNotes,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? customerName,
    String? customerEmail,
    String? customerPhone,
    String? customerPhotoUrl,
    String? artisanName,
    String? artisanEmail,
    String? artisanPhone,
    String? artisanPhotoUrl,
    String? artisanCategory,
    double? artisanRating,
    DateTime? acceptedAt,
    DateTime? rejectedAt,
    DateTime? startedAt,
    DateTime? completedAt,
    DateTime? cancelledAt,
    String? rejectionReason,
    String? cancellationReason,
    String? cancelledBy,
  }) {
    return BookingEntity(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      artisanId: artisanId ?? this.artisanId,
      artisanProfileId: artisanProfileId ?? this.artisanProfileId,
      serviceType: serviceType ?? this.serviceType,
      description: description ?? this.description,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      preferredTime: preferredTime ?? this.preferredTime,
      locationAddress: locationAddress ?? this.locationAddress,
      locationLatitude: locationLatitude ?? this.locationLatitude,
      locationLongitude: locationLongitude ?? this.locationLongitude,
      status: status ?? this.status,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      estimatedPrice: estimatedPrice ?? this.estimatedPrice,
      finalPrice: finalPrice ?? this.finalPrice,
      customerNotes: customerNotes ?? this.customerNotes,
      artisanNotes: artisanNotes ?? this.artisanNotes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      customerName: customerName ?? this.customerName,
      customerEmail: customerEmail ?? this.customerEmail,
      customerPhone: customerPhone ?? this.customerPhone,
      customerPhotoUrl: customerPhotoUrl ?? this.customerPhotoUrl,
      artisanName: artisanName ?? this.artisanName,
      artisanEmail: artisanEmail ?? this.artisanEmail,
      artisanPhone: artisanPhone ?? this.artisanPhone,
      artisanPhotoUrl: artisanPhotoUrl ?? this.artisanPhotoUrl,
      artisanCategory: artisanCategory ?? this.artisanCategory,
      artisanRating: artisanRating ?? this.artisanRating,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      rejectedAt: rejectedAt ?? this.rejectedAt,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      cancelledBy: cancelledBy ?? this.cancelledBy,
    );
  }
}