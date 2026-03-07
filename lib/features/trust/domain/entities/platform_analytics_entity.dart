class PlatformAnalyticsEntity {
  final int totalUsers;
  final int totalArtisans;
  final int verifiedUsers;
  final int openDisputes;
  final int pendingReports;
  final int bookingsToday;

  const PlatformAnalyticsEntity({
    required this.totalUsers,
    required this.totalArtisans,
    required this.verifiedUsers,
    required this.openDisputes,
    required this.pendingReports,
    required this.bookingsToday,
  });
}
