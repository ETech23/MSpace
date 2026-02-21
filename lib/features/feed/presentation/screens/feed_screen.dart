// lib/features/feed/presentation/screens/feed_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../jobs/data/models/job_model.dart';
import '../providers/feed_provider.dart';
import '../../../../core/ads/ad_widgets.dart';

enum FeedTab { nearby, jobs, artisans, tips }

enum FeedItemType { jobRequest, featuredArtisan, completedJob, announcement, tip }

class FeedScreen extends ConsumerWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final feedAsync = ref.watch(feedStreamProvider);

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: colorScheme.surfaceContainerLowest,
        appBar: AppBar(
          backgroundColor: colorScheme.surface,
          elevation: 0,
          scrolledUnderElevation: 1,
          surfaceTintColor: colorScheme.surfaceTint,
          title: Text(
            'Feed',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          actions: [
            IconButton(
              tooltip: 'Refresh',
              icon: const Icon(Icons.refresh),
              onPressed: () => ref.invalidate(feedStreamProvider),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: Container(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: colorScheme.primary,
                unselectedLabelColor: colorScheme.onSurfaceVariant,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
                indicator: UnderlineTabIndicator(
                  borderSide: BorderSide(
                    color: colorScheme.primary,
                    width: 2,
                  ),
                ),
                dividerColor: Colors.transparent,
                tabs: const [
                  Tab(text: 'Nearby'),
                  Tab(text: 'Jobs'),
                  Tab(text: 'Artisans'),
                  Tab(text: 'Tips'),
                ],
              ),
            ),
          ),
        ),
        body: feedAsync.when(
          data: (items) {
            final user = ref.watch(authProvider).user;
            final filtered = _filterForUser(items, user?.userType);

            return TabBarView(
              children: [
                _FeedList(
                  items: filtered,
                  filter: FeedTab.nearby,
                  onRefresh: () => _refreshFeed(ref),
                ),
                _FeedList(
                  items: filtered,
                  filter: FeedTab.jobs,
                  onRefresh: () => _refreshFeed(ref),
                ),
                _FeedList(
                  items: filtered,
                  filter: FeedTab.artisans,
                  onRefresh: () => _refreshFeed(ref),
                ),
                _FeedList(
                  items: filtered,
                  filter: FeedTab.tips,
                  onRefresh: () => _refreshFeed(ref),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _FeedErrorState(message: error.toString()),
        ),
      ),
    );
  }

  Future<void> _refreshFeed(WidgetRef ref) async {
    ref.invalidate(feedStreamProvider);
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }

  List<FeedItemModel> _filterForUser(List<FeedItemModel> items, String? userType) {
    final now = DateTime.now();

    return items.where((item) {
      if (!item.isActive) return false;
      if (item.expiresAt != null && item.expiresAt!.isBefore(now)) return false;
      if (item.targetUserType == null || item.targetUserType!.isEmpty) return true;

      final target = item.targetUserType!.toLowerCase();
      if (target == 'all' || target == 'both') return true;

      if (userType == null) return false;
      return target == userType.toLowerCase();
    }).toList(growable: false);
  }
}

class _FeedList extends StatelessWidget {
  final List<FeedItemModel> items;
  final FeedTab filter;
  final Future<void> Function() onRefresh;

  const _FeedList({
    required this.items,
    required this.filter,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final filtered = items.where((item) {
      final type = _parseFeedItemType(item.itemType);
      if (type == null) return false;

      switch (filter) {
        case FeedTab.nearby:
          return type == FeedItemType.jobRequest ||
              type == FeedItemType.featuredArtisan ||
              type == FeedItemType.completedJob;
        case FeedTab.jobs:
          return type == FeedItemType.jobRequest ||
              type == FeedItemType.completedJob;
        case FeedTab.artisans:
          return type == FeedItemType.featuredArtisan;
        case FeedTab.tips:
          return type == FeedItemType.tip ||
              type == FeedItemType.announcement;
      }
    }).toList();

    if (filtered.isEmpty) {
      return _FeedEmptyState(filter: filter);
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: filtered.isEmpty
            ? 0
            : filtered.length + (filtered.length / 3).floor(),
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          const adInterval = 3;
          final isAdIndex = (index + 1) % (adInterval + 1) == 0;
          if (isAdIndex) {
            return const NativeAdWidget();
          }

          final itemIndex = index - (index ~/ (adInterval + 1));
          return _FeedCard(item: filtered[itemIndex]);
        },
      ),
    );
  }
}

class _FeedCard extends StatelessWidget {
  final FeedItemModel item;

  const _FeedCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final type = _parseFeedItemType(item.itemType);
    final title = _resolveTitle(item);
    final description = _resolveDescription(item);

    return Card(
      elevation: 0,
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: colorScheme.outlineVariant.withOpacity(0.5),
        ),
      ),
      child: InkWell(
        onTap: () => _handleCta(context, item, type),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  if (type != null) _TypeLabel(type: type),
                  const SizedBox(width: 8),
                  if (item.isSponsored || item.isBoosted) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        item.isSponsored ? 'Sponsored' : 'Boosted',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: colorScheme.onSecondaryContainer,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  const Spacer(),
                  Text(
                    timeago.format(item.publishedAt),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Body
              _buildTypeBody(context, type, title, description),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeBody(
    BuildContext context,
    FeedItemType? type,
    String title,
    String? description,
  ) {
    if (type == null) {
      return _GenericBody(title: title, description: description);
    }
    switch (type) {
      case FeedItemType.jobRequest:
        return _JobBody(item: item, title: title, description: description);
      case FeedItemType.featuredArtisan:
        return _ArtisanBody(item: item);
      case FeedItemType.completedJob:
        return _CompletedBody(item: item, title: title, description: description);
      case FeedItemType.announcement:
        return _AnnouncementBody(item: item, title: title, description: description);
      case FeedItemType.tip:
        return _TipBody(item: item, title: title, description: description);
    }
  }

  String _resolveTitle(FeedItemModel item) {
    if (item.title != null && item.title!.isNotEmpty) return item.title!;
    if (item.itemType == 'featured_artisan' && item.artisanName != null) {
      return item.artisanName!;
    }
    if (item.job != null && item.job!.title.isNotEmpty) {
      return item.job!.title;
    }
    switch (item.itemType) {
      case 'job_request':
        return 'New job request';
      case 'featured_artisan':
        return 'Featured artisan';
      case 'completed_job':
        return 'Completed job';
      case 'announcement':
        return 'Announcement';
      case 'tip':
        return 'Tip';
      default:
        return 'Feed update';
    }
  }

  String? _resolveDescription(FeedItemModel item) {
    if (item.description != null && item.description!.isNotEmpty) {
      return item.description!;
    }
    if (item.job != null && item.job!.description.isNotEmpty) {
      return item.job!.description;
    }
    return null;
  }

  void _handleCta(BuildContext context, FeedItemModel item, FeedItemType? type) {
    if (item.ctaAction != null && item.ctaAction!.startsWith('/')) {
      context.push(item.ctaAction!);
      return;
    }

    if (type == FeedItemType.featuredArtisan && item.artisanId != null) {
      context.push('/artisan/${item.artisanId}');
      return;
    }

    if ((type == FeedItemType.jobRequest || type == FeedItemType.completedJob) &&
        item.jobId != null) {
      context.push('/jobs/${item.jobId}');
      return;
    }
  }
}

class _GenericBody extends StatelessWidget {
  final String title;
  final String? description;

  const _GenericBody({
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        if (description?.isNotEmpty == true) ...[
          const SizedBox(height: 6),
          Text(
            description!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }
}

class _JobBody extends StatelessWidget {
  final FeedItemModel item;
  final String title;
  final String? description;

  const _JobBody({
    required this.item,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final job = item.job;
    final budgetLabel = _formatBudgetForJob(job);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        if (description?.isNotEmpty == true) ...[
          const SizedBox(height: 6),
          Text(
            description!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            _InfoChip(
              icon: Icons.category_outlined,
              label: item.category ?? job?.category ?? 'General',
            ),
            if (job?.distance != null)
              _InfoChip(
                icon: Icons.location_on_outlined,
                label: '${job!.distance!.toStringAsFixed(1)} km',
              ),
            if (budgetLabel != null)
              _InfoChip(
                icon: Icons.payments_outlined,
                label: budgetLabel,
              ),
          ],
        ),
      ],
    );
  }
}

class _ArtisanBody extends StatelessWidget {
  final FeedItemModel item;

  const _ArtisanBody({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final name = item.artisanName ?? item.title ?? 'Featured Artisan';
    final category = item.artisanCategory ?? item.category ?? 'General';

    return Row(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: colorScheme.primaryContainer,
          backgroundImage: item.artisanPhotoUrl != null
              ? NetworkImage(item.artisanPhotoUrl!)
              : null,
          child: item.artisanPhotoUrl == null
              ? Icon(Icons.person, color: colorScheme.onPrimaryContainer)
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    category,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (item.artisanRating != null) ...[
                    const SizedBox(width: 8),
                    Icon(Icons.star, size: 14, color: Colors.amber[700]),
                    const SizedBox(width: 2),
                    Text(
                      item.artisanRating!.toStringAsFixed(1),
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CompletedBody extends StatelessWidget {
  final FeedItemModel item;
  final String title;
  final String? description;

  const _CompletedBody({
    required this.item,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.check_circle,
              size: 16,
              color: colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        if (description?.isNotEmpty == true) ...[
          const SizedBox(height: 6),
          Text(
            description!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }
}

class _AnnouncementBody extends StatelessWidget {
  final FeedItemModel item;
  final String title;
  final String? description;

  const _AnnouncementBody({
    required this.item,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (item.imageUrl != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              item.imageUrl!,
              height: 160,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                height: 160,
                color: colorScheme.surfaceContainerHighest,
                child: const Center(child: Icon(Icons.image_not_supported)),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        if (description?.isNotEmpty == true) ...[
          const SizedBox(height: 6),
          Text(
            description!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

class _TipBody extends StatelessWidget {
  final FeedItemModel item;
  final String title;
  final String? description;

  const _TipBody({
    required this.item,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (item.imageUrl != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              item.imageUrl!,
              height: 160,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                height: 160,
                color: colorScheme.surfaceContainerHighest,
                child: const Center(child: Icon(Icons.image_not_supported)),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        if (description?.isNotEmpty == true) ...[
          const SizedBox(height: 6),
          Text(
            description!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

class _TypeLabel extends StatelessWidget {
  final FeedItemType type;

  const _TypeLabel({required this.type});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final label = _typeLabel(type);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: colorScheme.onPrimaryContainer,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  String _typeLabel(FeedItemType type) {
    switch (type) {
      case FeedItemType.jobRequest:
        return 'Job';
      case FeedItemType.featuredArtisan:
        return 'Artisan';
      case FeedItemType.completedJob:
        return 'Completed';
      case FeedItemType.announcement:
        return 'News';
      case FeedItemType.tip:
        return 'Tip';
    }
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedEmptyState extends StatelessWidget {
  final FeedTab filter;

  const _FeedEmptyState({required this.filter});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _getEmptyIcon(filter),
              size: 64,
              color: colorScheme.onSurfaceVariant.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              _getEmptyTitle(filter),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _getEmptySubtitle(filter),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  IconData _getEmptyIcon(FeedTab tab) {
    switch (tab) {
      case FeedTab.nearby:
        return Icons.near_me_outlined;
      case FeedTab.jobs:
        return Icons.work_outline;
      case FeedTab.artisans:
        return Icons.person_outline;
      case FeedTab.tips:
        return Icons.lightbulb_outline;
    }
  }

  String _getEmptyTitle(FeedTab tab) {
    switch (tab) {
      case FeedTab.nearby:
        return 'Nothing nearby yet';
      case FeedTab.jobs:
        return 'No jobs available';
      case FeedTab.artisans:
        return 'No artisans featured';
      case FeedTab.tips:
        return 'No tips yet';
    }
  }

  String _getEmptySubtitle(FeedTab tab) {
    switch (tab) {
      case FeedTab.nearby:
        return 'Check back soon for updates';
      case FeedTab.jobs:
        return 'New job requests will appear here';
      case FeedTab.artisans:
        return 'Featured artisans will appear here';
      case FeedTab.tips:
        return 'Tips and updates will appear here';
    }
  }
}

class _FeedErrorState extends StatelessWidget {
  final String message;

  const _FeedErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Could not load feed',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

String? _formatBudgetForJob(JobModel? job) {
  if (job == null) return null;
  if (job.budgetMin == null || job.budgetMax == null) return null;
  return '₦${job.budgetMin}-${job.budgetMax}';
}

FeedItemType? _parseFeedItemType(String value) {
  switch (value) {
    case 'job_request':
      return FeedItemType.jobRequest;
    case 'featured_artisan':
      return FeedItemType.featuredArtisan;
    case 'completed_job':
      return FeedItemType.completedJob;
    case 'announcement':
      return FeedItemType.announcement;
    case 'tip':
      return FeedItemType.tip;
  }
  return null;
}
