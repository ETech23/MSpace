// ================================================================
// UPDATED JOB MODEL - With booking_id field
// lib/features/jobs/data/models/job_model.dart
// ================================================================

class JobModel {
  final String id;
  final String customerId;
  final String title;
  final String description;
  final String category;
  final double? budgetMin;
  final double? budgetMax;
  final String? currency;
  final double latitude;
  final double longitude;
  final String? address;
  final DateTime? preferredDate;
  final String? preferredTimeStart;
  final String? preferredTimeEnd;
  final bool isUrgent;
  final String status;
  final String? acceptedBy;
  final DateTime? acceptedAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  final bool isBoosted;
  final DateTime? boostExpiresAt;
  final int priorityLevel;
  final List<String> images;
  final int notifiedArtisanCount;
  final int viewCount;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? bookingId; // 🆕 NEW FIELD
  
  // Computed/joined fields
  final double? distance;
  final String? customerName;
  final String? customerPhotoUrl;
  final String? artisanName;
  final String? artisanPhotoUrl;

  JobModel({
    required this.id,
    required this.customerId,
    required this.title,
    required this.description,
    required this.category,
    this.budgetMin,
    this.budgetMax,
    this.currency = 'NGN',
    required this.latitude,
    required this.longitude,
    this.address,
    this.preferredDate,
    this.preferredTimeStart,
    this.preferredTimeEnd,
    this.isUrgent = false,
    this.status = 'pending',
    this.acceptedBy,
    this.acceptedAt,
    this.startedAt,
    this.completedAt,
    this.cancelledAt,
    this.isBoosted = false,
    this.boostExpiresAt,
    this.priorityLevel = 0,
    this.images = const [],
    this.notifiedArtisanCount = 0,
    this.viewCount = 0,
    required this.createdAt,
    this.updatedAt,
    this.bookingId, // 🆕 NEW FIELD
    this.distance,
    this.customerName,
    this.customerPhotoUrl,
    this.artisanName,
    this.artisanPhotoUrl,
  });

  factory JobModel.fromJson(Map<String, dynamic> json) {
    return JobModel(
      id: json['id'] as String,
      customerId: json['customer_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      category: json['category'] as String,
      budgetMin: json['budget_min'] != null ? (json['budget_min'] as num).toDouble() : null,
      budgetMax: json['budget_max'] != null ? (json['budget_max'] as num).toDouble() : null,
      currency: json['currency'] as String? ?? 'NGN',
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      address: json['address'] as String?,
      preferredDate: json['preferred_date'] != null 
          ? DateTime.parse(json['preferred_date'] as String)
          : null,
      preferredTimeStart: json['preferred_time_start'] as String?,
      preferredTimeEnd: json['preferred_time_end'] as String?,
      isUrgent: json['is_urgent'] as bool? ?? false,
      status: json['status'] as String? ?? 'pending',
      acceptedBy: json['accepted_by'] as String?,
      acceptedAt: json['accepted_at'] != null
          ? DateTime.parse(json['accepted_at'] as String)
          : null,
      startedAt: json['started_at'] != null
          ? DateTime.parse(json['started_at'] as String)
          : null,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      cancelledAt: json['cancelled_at'] != null
          ? DateTime.parse(json['cancelled_at'] as String)
          : null,
      isBoosted: json['is_boosted'] as bool? ?? false,
      boostExpiresAt: json['boost_expires_at'] != null
          ? DateTime.parse(json['boost_expires_at'] as String)
          : null,
      priorityLevel: json['priority_level'] as int? ?? 0,
      images: json['images'] != null 
          ? List<String>.from(json['images'] as List)
          : [],
      notifiedArtisanCount: json['notified_artisan_count'] as int? ?? 0,
      viewCount: json['view_count'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      bookingId: json['booking_id'] as String?, // 🆕 NEW FIELD
      distance: json['distance'] != null ? (json['distance'] as num).toDouble() : null,
      customerName: json['customer_name'] as String?,
      customerPhotoUrl: json['customer_photo_url'] as String?,
      artisanName: json['artisan_name'] as String?,
      artisanPhotoUrl: json['artisan_photo_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'customer_id': customerId,
      'title': title,
      'description': description,
      'category': category,
      'budget_min': budgetMin,
      'budget_max': budgetMax,
      'currency': currency,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'preferred_date': preferredDate?.toIso8601String(),
      'preferred_time_start': preferredTimeStart,
      'preferred_time_end': preferredTimeEnd,
      'is_urgent': isUrgent,
      'status': status,
      'accepted_by': acceptedBy,
      'accepted_at': acceptedAt?.toIso8601String(),
      'started_at': startedAt?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'cancelled_at': cancelledAt?.toIso8601String(),
      'is_boosted': isBoosted,
      'boost_expires_at': boostExpiresAt?.toIso8601String(),
      'priority_level': priorityLevel,
      'images': images,
      'notified_artisan_count': notifiedArtisanCount,
      'view_count': viewCount,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'booking_id': bookingId, // 🆕 NEW FIELD
    };
  }

  JobModel copyWith({
    String? id,
    String? customerId,
    String? title,
    String? description,
    String? category,
    double? budgetMin,
    double? budgetMax,
    String? currency,
    double? latitude,
    double? longitude,
    String? address,
    DateTime? preferredDate,
    String? preferredTimeStart,
    String? preferredTimeEnd,
    bool? isUrgent,
    String? status,
    String? acceptedBy,
    DateTime? acceptedAt,
    DateTime? startedAt,
    DateTime? completedAt,
    DateTime? cancelledAt,
    bool? isBoosted,
    DateTime? boostExpiresAt,
    int? priorityLevel,
    List<String>? images,
    int? notifiedArtisanCount,
    int? viewCount,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? bookingId, // 🆕 NEW FIELD
    double? distance,
    String? customerName,
    String? customerPhotoUrl,
    String? artisanName,
    String? artisanPhotoUrl,
  }) {
    return JobModel(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      budgetMin: budgetMin ?? this.budgetMin,
      budgetMax: budgetMax ?? this.budgetMax,
      currency: currency ?? this.currency,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      address: address ?? this.address,
      preferredDate: preferredDate ?? this.preferredDate,
      preferredTimeStart: preferredTimeStart ?? this.preferredTimeStart,
      preferredTimeEnd: preferredTimeEnd ?? this.preferredTimeEnd,
      isUrgent: isUrgent ?? this.isUrgent,
      status: status ?? this.status,
      acceptedBy: acceptedBy ?? this.acceptedBy,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      isBoosted: isBoosted ?? this.isBoosted,
      boostExpiresAt: boostExpiresAt ?? this.boostExpiresAt,
      priorityLevel: priorityLevel ?? this.priorityLevel,
      images: images ?? this.images,
      notifiedArtisanCount: notifiedArtisanCount ?? this.notifiedArtisanCount,
      viewCount: viewCount ?? this.viewCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      bookingId: bookingId ?? this.bookingId, // 🆕 NEW FIELD
      distance: distance ?? this.distance,
      customerName: customerName ?? this.customerName,
      customerPhotoUrl: customerPhotoUrl ?? this.customerPhotoUrl,
      artisanName: artisanName ?? this.artisanName,
      artisanPhotoUrl: artisanPhotoUrl ?? this.artisanPhotoUrl,
    );
  }

  // Helper getters
  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';
  bool get isInProgress => status == 'in_progress';
  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';
  bool get hasBooking => bookingId != null; // 🆕 NEW GETTER
  
  String get budgetDisplay {
    if (budgetMin != null && budgetMax != null) {
      return '₦${budgetMin!.toStringAsFixed(0)} - ₦${budgetMax!.toStringAsFixed(0)}';
    } else if (budgetMin != null) {
      return 'From ₦${budgetMin!.toStringAsFixed(0)}';
    } else if (budgetMax != null) {
      return 'Up to ₦${budgetMax!.toStringAsFixed(0)}';
    }
    return 'Budget not specified';
  }
}


// ================================================================
// 2. JOB MATCH MODEL (unchanged)
// ================================================================

class JobMatchModel {
  final String id;
  final String jobId;
  final String artisanId;
  final double distanceKm;
  final double matchScore;
  final bool isPremiumArtisan;
  final int priorityTier;
  final int notificationDelaySeconds;
  final DateTime notifiedAt;
  final DateTime? viewedAt;
  final DateTime? respondedAt;
  final String? response;
  final String? declineReason;
  
  // Populated fields
  final JobModel? job;
  final String? artisanName;
  final String? artisanPhotoUrl;
  final double? artisanRating;

  JobMatchModel({
    required this.id,
    required this.jobId,
    required this.artisanId,
    required this.distanceKm,
    this.matchScore = 0,
    this.isPremiumArtisan = false,
    this.priorityTier = 0,
    this.notificationDelaySeconds = 0,
    required this.notifiedAt,
    this.viewedAt,
    this.respondedAt,
    this.response,
    this.declineReason,
    this.job,
    this.artisanName,
    this.artisanPhotoUrl,
    this.artisanRating,
  });

  factory JobMatchModel.fromJson(Map<String, dynamic> json) {
    return JobMatchModel(
      id: json['id'] as String,
      jobId: json['job_id'] as String,
      artisanId: json['artisan_id'] as String,
      distanceKm: (json['distance_km'] as num).toDouble(),
      matchScore: json['match_score'] != null ? (json['match_score'] as num).toDouble() : 0,
      isPremiumArtisan: json['is_premium_artisan'] as bool? ?? false,
      priorityTier: json['priority_tier'] as int? ?? 0,
      notificationDelaySeconds: json['notification_delay_seconds'] as int? ?? 0,
      notifiedAt: DateTime.parse(json['notified_at'] as String),
      viewedAt: json['viewed_at'] != null 
          ? DateTime.parse(json['viewed_at'] as String)
          : null,
      respondedAt: json['responded_at'] != null
          ? DateTime.parse(json['responded_at'] as String)
          : null,
      response: json['response'] as String?,
      declineReason: json['decline_reason'] as String?,
      job: json['job'] != null 
          ? (json['job'] is JobModel 
              ? json['job'] as JobModel
              : JobModel.fromJson(json['job'] as Map<String, dynamic>))
          : null,
      artisanName: json['artisan_name'] as String?,
      artisanPhotoUrl: json['artisan_photo_url'] as String?,
      artisanRating: json['artisan_rating'] != null 
          ? (json['artisan_rating'] as num).toDouble()
          : null,
    );
  }
}


// ================================================================
// 3. JOB FORM MODEL (UI State) - unchanged
// ================================================================

class JobFormModel {
  final String? title;
  final String? description;
  final String? category;
  final double? budgetMin;
  final double? budgetMax;
  final double? latitude;
  final double? longitude;
  final String? address;
  final DateTime? preferredDate;
  final String? preferredTimeStart;
  final String? preferredTimeEnd;
  final bool isUrgent;
  final List<String> images;

  JobFormModel({
    this.title,
    this.description,
    this.category,
    this.budgetMin,
    this.budgetMax,
    this.latitude,
    this.longitude,
    this.address,
    this.preferredDate,
    this.preferredTimeStart,
    this.preferredTimeEnd,
    this.isUrgent = false,
    this.images = const [],
  });
}


// ================================================================
// 4. FEED ITEM MODEL - unchanged
// ================================================================

class FeedItemModel {
  final String id;
  final String itemType;
  final String? jobId;
  final String? artisanId;
  final String? title;
  final String? description;
  final String? imageUrl;
  final String? ctaText;
  final String? ctaAction;
  final String? category;
  final String? targetUserType;
  final bool isSponsored;
  final bool isBoosted;
  final String? sponsorId;
  final int viewCount;
  final int clickCount;
  final DateTime publishedAt;
  final DateTime? expiresAt;
  final int priority;
  final bool isActive;
  
  // Populated fields
  final JobModel? job;
  final String? artisanName;
  final String? artisanPhotoUrl;
  final double? artisanRating;
  final String? artisanCategory;

  FeedItemModel({
    required this.id,
    required this.itemType,
    this.jobId,
    this.artisanId,
    this.title,
    this.description,
    this.imageUrl,
    this.ctaText,
    this.ctaAction,
    this.category,
    this.targetUserType,
    this.isSponsored = false,
    this.isBoosted = false,
    this.sponsorId,
    this.viewCount = 0,
    this.clickCount = 0,
    required this.publishedAt,
    this.expiresAt,
    this.priority = 0,
    this.isActive = true,
    this.job,
    this.artisanName,
    this.artisanPhotoUrl,
    this.artisanRating,
    this.artisanCategory,
  });

  factory FeedItemModel.fromJson(Map<String, dynamic> json) {
    return FeedItemModel(
      id: json['id'] as String,
      itemType: json['item_type'] as String,
      jobId: json['job_id'] as String?,
      artisanId: json['artisan_id'] as String?,
      title: json['title'] as String?,
      description: json['description'] as String?,
      imageUrl: json['image_url'] as String?,
      ctaText: json['cta_text'] as String?,
      ctaAction: json['cta_action'] as String?,
      category: json['category'] as String?,
      targetUserType: json['target_user_type'] as String?,
      isSponsored: json['is_sponsored'] as bool? ?? false,
      isBoosted: json['is_boosted'] as bool? ?? false,
      sponsorId: json['sponsor_id'] as String?,
      viewCount: json['view_count'] as int? ?? 0,
      clickCount: json['click_count'] as int? ?? 0,
      publishedAt: DateTime.parse(json['published_at'] as String),
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'] as String)
          : null,
      priority: json['priority'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      job: json['job'] != null
          ? JobModel.fromJson(json['job'] as Map<String, dynamic>)
          : null,
      artisanName: json['artisan_name'] as String?,
      artisanPhotoUrl: json['artisan_photo_url'] as String?,
      artisanRating: json['artisan_rating'] != null
          ? (json['artisan_rating'] as num).toDouble()
          : null,
      artisanCategory: json['artisan_category'] as String?,
    );
  }
}