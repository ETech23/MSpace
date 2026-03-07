// lib/features/feed/presentation/screens/feed_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../jobs/data/models/job_model.dart';
import '../../../trust/presentation/providers/trust_provider.dart';
import '../providers/feed_provider.dart';
import '../../../../core/ads/ad_widgets.dart';

enum FeedTab { nearby, jobs, artisans, tips }
enum FeedItemType { jobRequest, featuredArtisan, completedJob, announcement, tip }

class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _activeTab = 0;

  static const _tabs = [
    (label: 'Nearby',   icon: Icons.near_me_rounded),
    (label: 'Jobs',     icon: Icons.work_rounded),
    (label: 'Artisans', icon: Icons.people_rounded),
    (label: 'Tips',     icon: Icons.lightbulb_rounded),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this)
      ..addListener(() {
        if (!_tabController.indexIsChanging) return;
        setState(() => _activeTab = _tabController.index);
        HapticFeedback.selectionClick();
      });

    // Rebuild feed with freshest location when user actually opens this screen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(feedStreamProvider);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(feedStreamProvider);
    await Future<void>.delayed(const Duration(milliseconds: 300));
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final feedAsync = ref.watch(feedStreamProvider);
    final user = ref.watch(authProvider).user;
    final blockedIds = user == null
        ? <String>{}
        : ref.watch(blockedUsersProvider(user.id)).maybeWhen(
              data: (items) => items.map((e) => e.blockedUserId).toSet(),
              orElse: () => <String>{},
            );

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverAppBar(
            pinned: true,
            backgroundColor: colorScheme.surface,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            titleSpacing: 12,
            title: Row(
              children: [
                Text(
                  'Feed',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.8,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            actions: [
              _AppBarAction(
                icon: Icons.tune_rounded,
                onTap: () {},
                colorScheme: colorScheme,
                isDark: isDark,
              ),
              _AppBarAction(
                icon: Icons.refresh_rounded,
                onTap: () {
                  HapticFeedback.lightImpact();
                  _refresh();
                },
                colorScheme: colorScheme,
                isDark: isDark,
              ),
              const SizedBox(width: 8),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(44),
              child: SizedBox(
                height: 44,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minWidth: constraints.maxWidth),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (var i = 0; i < _tabs.length; i++) ...[
                              if (i > 0) const SizedBox(width: 8),
                              _FeedTabChip(
                                label: _tabs[i].label,
                                icon: _tabs[i].icon,
                                selected: _activeTab == i,
                                colorScheme: colorScheme,
                                isDark: isDark,
                                onTap: () {
                                  _tabController.animateTo(i);
                                  setState(() => _activeTab = i);
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
        body: feedAsync.when(
          data: (items) {
            final filtered = _filterForUser(items, user?.userType, blockedIds);
            return TabBarView(
              controller: _tabController,
              children: FeedTab.values
                  .map((tab) => _FeedList(
                        items: filtered,
                        filter: tab,
                        onRefresh: _refresh,
                      ))
                  .toList(),
            );
          },
          loading: () => _FeedShimmer(colorScheme: colorScheme, isDark: isDark),
          error: (e, _) => _FeedErrorState(
            message: e.toString(),
            onRetry: _refresh,
            colorScheme: colorScheme,
          ),
        ),
      ),
    );
  }

  List<FeedItemModel> _filterForUser(
    List<FeedItemModel> items,
    String? userType,
    Set<String> blockedIds,
  ) {
    final now = DateTime.now();
    return items.where((item) {
      if (!item.isActive) return false;
      if (item.expiresAt != null && item.expiresAt!.isBefore(now)) return false;
      if (item.artisanId != null && blockedIds.contains(item.artisanId)) return false;
      if (item.job != null) {
        if (blockedIds.contains(item.job!.customerId)) return false;
        if (item.job!.acceptedBy != null && blockedIds.contains(item.job!.acceptedBy!)) return false;
      }
      if (item.targetUserType == null || item.targetUserType!.isEmpty) return true;
      final target = item.targetUserType!.toLowerCase();
      if (target == 'all' || target == 'both') return true;
      if (userType == null) return false;
      return target == userType.toLowerCase();
    }).toList(growable: false);
  }
}

// ── App bar action ────────────────────────────────────────────────────────────

class _AppBarAction extends StatelessWidget {
  const _AppBarAction({
    required this.icon,
    required this.onTap,
    required this.colorScheme,
    required this.isDark,
  });
  final IconData icon;
  final VoidCallback onTap;
  final ColorScheme colorScheme;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(0.08)
                : colorScheme.onSurface.withOpacity(0.06),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: colorScheme.onSurface),
        ),
      ),
    );
  }
}

// ── Tab chip ──────────────────────────────────────────────────────────────────

class _FeedTabChip extends StatelessWidget {
  const _FeedTabChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.colorScheme,
    required this.isDark,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final ColorScheme colorScheme;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected
              ? colorScheme.onSurface
              : isDark
                  ? Colors.white.withOpacity(0.07)
                  : Colors.black.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          boxShadow: selected
              ? [BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 8, offset: const Offset(0, 3))]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 12,
              color: selected
                  ? colorScheme.surface
                  : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected
                    ? colorScheme.surface
                    : colorScheme.onSurfaceVariant,
                letterSpacing: selected ? 0.1 : 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Feed list ──────────────────────────────────────────────────────────────────

class _FeedList extends StatelessWidget {
  const _FeedList({required this.items, required this.filter, required this.onRefresh});
  final List<FeedItemModel> items;
  final FeedTab filter;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    const nearbyRadiusKm = 25.0;
    final filtered = items.where((item) {
      final type = _parseFeedItemType(item.itemType);
      if (type == null) return false;
      switch (filter) {
        case FeedTab.nearby:
          if (type == FeedItemType.jobRequest || type == FeedItemType.completedJob) {
            // Nearby tab should always include jobs; artisans are distance-scoped.
            return true;
          }
          if (type == FeedItemType.featuredArtisan) {
            final distance = item.distanceKm;
            return distance == null || distance <= nearbyRadiusKm;
          }
          return false;
        case FeedTab.jobs:
          return type == FeedItemType.jobRequest || type == FeedItemType.completedJob;
        case FeedTab.artisans:
          if (type != FeedItemType.featuredArtisan) return false;
          final distance = item.distanceKm;
          return distance == null || distance <= nearbyRadiusKm;
        case FeedTab.tips:
          return type == FeedItemType.tip || type == FeedItemType.announcement;
      }
    }).toList();

    if (filtered.isEmpty) return _FeedEmptyState(filter: filter);

    const adInterval = 4;
    final adSlots = (filtered.length / adInterval).floor();
    final total = filtered.length + adSlots;
    final totalWithTopBanner = total + 1;

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(6, 12, 8, 100),
        itemCount: totalWithTopBanner,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          if (index == 0) {
            return BannerAdWidget(
              padding: EdgeInsets.fromLTRB(0, 0, 0, 2),
            );
          }

          final entryIndex = index - 1;
          final isAd = (entryIndex + 1) % (adInterval + 1) == 0;
          if (isAd) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: NativeAdWidget(),
            );
          }
          final i = entryIndex - (entryIndex ~/ (adInterval + 1));
          if (i >= filtered.length) return const SizedBox.shrink();
          return _FeedCard(item: filtered[i]);
        },
      ),
    );
  }
}

// ── Feed card ──────────────────────────────────────────────────────────────────

class _FeedCard extends StatelessWidget {
  const _FeedCard({required this.item});
  final FeedItemModel item;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final type = _parseFeedItemType(item.itemType);
    final title = _resolveTitle(item);
    final description = _resolveDescription(item);
    final style = _typeStyle(type, colorScheme);

    final cardBg = isDark
        ? Color.alphaBlend(Colors.white.withOpacity(0.05), colorScheme.surface)
        : colorScheme.surface;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        boxShadow: isDark
            ? [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 14, offset: const Offset(0, 4))]
            : [
                BoxShadow(color: style.color.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 6)),
                BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 1)),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _handleCta(context, item, type),
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    _TypePill(style: style),
                    if (item.isSponsored || item.isBoosted) ...[
                      const SizedBox(width: 6),
                      _SponsoredPill(label: item.isSponsored ? 'Sponsored' : 'Boosted'),
                    ],
                    const Spacer(),
                    Text(
                      timeago.format(item.publishedAt.toLocal()),
                      style: TextStyle(
                        fontSize: 10,
                        color: colorScheme.onSurfaceVariant.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildBody(context, type, title, description, colorScheme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, FeedItemType? type, String title,
      String? description, ColorScheme cs) {
    switch (type) {
      case FeedItemType.jobRequest:
        return _JobBody(item: item, title: title, description: description);
      case FeedItemType.featuredArtisan:
        return _ArtisanBody(item: item);
      case FeedItemType.completedJob:
        return _CompletedBody(item: item, title: title, description: description);
      case FeedItemType.announcement:
        return _MediaBody(item: item, title: title, description: description, accent: const Color(0xFF1565C0));
      case FeedItemType.tip:
        return _MediaBody(item: item, title: title, description: description, accent: const Color(0xFF5B21B6));
      default:
        return _GenericBody(title: title, description: description);
    }
  }

  void _handleCta(BuildContext context, FeedItemModel item, FeedItemType? type) {
    if (item.ctaAction?.startsWith('/') == true) {
      context.push(item.ctaAction!);
      return;
    }
    if (type == FeedItemType.featuredArtisan && item.artisanId != null) {
      context.push('/artisan/${item.artisanId}');
      return;
    }
    if ((type == FeedItemType.jobRequest || type == FeedItemType.completedJob) && item.jobId != null) {
      context.push('/jobs/${item.jobId}');
    }
  }

  String _resolveTitle(FeedItemModel item) {
    if (item.title?.isNotEmpty == true) return item.title!;
    if (item.itemType == 'featured_artisan' && item.artisanName != null) return item.artisanName!;
    if (item.job?.title.isNotEmpty == true) return item.job!.title;
    const fallbacks = {
      'job_request': 'New job request', 'featured_artisan': 'Featured artisan',
      'completed_job': 'Completed job', 'announcement': 'Announcement', 'tip': 'Tip',
    };
    return fallbacks[item.itemType] ?? 'Feed update';
  }

  String? _resolveDescription(FeedItemModel item) {
    if (item.description?.isNotEmpty == true) return item.description;
    if (item.job?.description.isNotEmpty == true) return item.job!.description;
    return null;
  }
}

// ── Card bodies ───────────────────────────────────────────────────────────────

class _GenericBody extends StatelessWidget {
  const _GenericBody({required this.title, required this.description});
  final String title;
  final String? description;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, letterSpacing: -0.2)),
      if (description?.isNotEmpty == true) ...[
        const SizedBox(height: 5),
        Text(description!, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant, height: 1.5), maxLines: 2, overflow: TextOverflow.ellipsis),
      ],
    ]);
  }
}

class _JobBody extends StatelessWidget {
  const _JobBody({required this.item, required this.title, required this.description});
  final FeedItemModel item;
  final String title;
  final String? description;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final budgetLabel = _formatBudgetForJob(item.job);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, letterSpacing: -0.2)),
      if (description?.isNotEmpty == true) ...[
        const SizedBox(height: 5),
        Text(description!, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant, height: 1.5), maxLines: 2, overflow: TextOverflow.ellipsis),
      ],
      const SizedBox(height: 10),
      Wrap(spacing: 6, runSpacing: 6, children: [
        _InfoChip(icon: Icons.category_rounded, label: item.category ?? item.job?.category ?? 'General'),
        if (item.job?.distance != null)
          _InfoChip(icon: Icons.location_on_rounded, label: '${item.job!.distance!.toStringAsFixed(1)} km'),
        if (budgetLabel != null)
          _InfoChip(icon: Icons.payments_rounded, label: budgetLabel, highlight: true),
      ]),
    ]);
  }
}

class _ArtisanBody extends StatelessWidget {
  const _ArtisanBody({required this.item});
  final FeedItemModel item;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final name = item.artisanName ?? item.title ?? 'Featured Artisan';
    final category = item.artisanCategory ?? item.category ?? 'General';

    return Row(children: [
      // Avatar
      Container(
        width: 52, height: 52,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: cs.primaryContainer,
          boxShadow: [BoxShadow(color: cs.primary.withOpacity(0.12), blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: item.artisanPhotoUrl != null
              ? Image.network(item.artisanPhotoUrl!, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Icon(Icons.person_rounded, color: cs.onPrimaryContainer))
              : Icon(Icons.person_rounded, color: cs.onPrimaryContainer),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(name,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, letterSpacing: -0.2),
            maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 4),
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(color: cs.primary.withOpacity(0.09), borderRadius: BorderRadius.circular(5)),
            child: Text(category, style: TextStyle(fontSize: 10, color: cs.primary, fontWeight: FontWeight.w600)),
          ),
          if (item.artisanRating != null) ...[
            const SizedBox(width: 8),
            const Icon(Icons.star_rounded, size: 13, color: Color(0xFFFFA000)),
            const SizedBox(width: 2),
            Text(item.artisanRating!.toStringAsFixed(1),
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
          ],
        ]),
      ])),
      Icon(Icons.chevron_right_rounded, size: 18, color: cs.onSurfaceVariant.withOpacity(0.4)),
    ]);
  }
}

class _CompletedBody extends StatelessWidget {
  const _CompletedBody({required this.item, required this.title, required this.description});
  final FeedItemModel item;
  final String title;
  final String? description;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(color: const Color(0xFF2E7D32).withOpacity(0.1), borderRadius: BorderRadius.circular(7)),
          child: const Icon(Icons.check_circle_rounded, size: 13, color: Color(0xFF2E7D32)),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, letterSpacing: -0.2))),
      ]),
      if (description?.isNotEmpty == true) ...[
        const SizedBox(height: 5),
        Text(description!, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant, height: 1.5),
            maxLines: 2, overflow: TextOverflow.ellipsis),
      ],
    ]);
  }
}

class _MediaBody extends StatelessWidget {
  const _MediaBody({required this.item, required this.title, required this.description, required this.accent});
  final FeedItemModel item;
  final String title;
  final String? description;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (item.imageUrl != null) ...[
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(item.imageUrl!, height: 160, width: double.infinity, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(height: 160,
                  decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
                  child: Center(child: Icon(Icons.image_not_supported_rounded,
                      color: cs.onSurfaceVariant.withOpacity(0.3), size: 36)))),
        ),
        const SizedBox(height: 12),
      ],
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 3, height: 38, margin: const EdgeInsets.only(right: 10, top: 1),
            decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(2))),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, letterSpacing: -0.2)),
          if (description?.isNotEmpty == true) ...[
            const SizedBox(height: 4),
            Text(description!, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant, height: 1.5)),
          ],
        ])),
      ]),
    ]);
  }
}

// ── Pills & chips ─────────────────────────────────────────────────────────────

class _TypeStyle {
  final String label;
  final IconData icon;
  final Color color;
  const _TypeStyle(this.label, this.icon, this.color);
}

_TypeStyle _typeStyle(FeedItemType? type, ColorScheme cs) {
  switch (type) {
    case FeedItemType.jobRequest:    return _TypeStyle('Job',      Icons.work_rounded,           const Color(0xFFE65100));
    case FeedItemType.featuredArtisan: return _TypeStyle('Artisan', Icons.star_rounded,          cs.primary);
    case FeedItemType.completedJob:  return _TypeStyle('Done',     Icons.check_circle_rounded,  const Color(0xFF2E7D32));
    case FeedItemType.announcement:  return _TypeStyle('News',     Icons.campaign_rounded,       const Color(0xFF1565C0));
    case FeedItemType.tip:           return _TypeStyle('Tip',      Icons.lightbulb_rounded,      const Color(0xFF5B21B6));
    default:                         return _TypeStyle('Update',   Icons.circle_rounded,         cs.outline);
  }
}

class _TypePill extends StatelessWidget {
  const _TypePill({required this.style});
  final _TypeStyle style;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(color: style.color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(style.icon, size: 11, color: style.color),
        const SizedBox(width: 4),
        Text(style.label, style: TextStyle(color: style.color, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.2)),
      ]),
    );
  }
}

class _SponsoredPill extends StatelessWidget {
  const _SponsoredPill({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(color: cs.secondaryContainer.withOpacity(0.7), borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: TextStyle(color: cs.onSecondaryContainer, fontSize: 9, fontWeight: FontWeight.w600)),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label, this.highlight = false});
  final IconData icon;
  final String label;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = highlight ? cs.primary.withOpacity(0.1) : (isDark ? Colors.white.withOpacity(0.07) : Colors.black.withOpacity(0.05));
    final fg = highlight ? cs.primary : cs.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: fg),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, color: fg, fontWeight: FontWeight.w500)),
      ]),
    );
  }
}

// ── States ────────────────────────────────────────────────────────────────────

class _FeedShimmer extends StatelessWidget {
  const _FeedShimmer({required this.colorScheme, required this.isDark});
  final ColorScheme colorScheme;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final shimmer = isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.04);
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(6, 12, 16, 8),
      itemCount: 5,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => Container(
        height: i.isEven ? 120 : 80,
        decoration: BoxDecoration(color: shimmer, borderRadius: BorderRadius.circular(18)),
      ),
    );
  }
}

class _FeedEmptyState extends StatelessWidget {
  const _FeedEmptyState({required this.filter});
  final FeedTab filter;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final (icon, title, subtitle) = switch (filter) {
      FeedTab.nearby   => (Icons.near_me_rounded,      'Nothing nearby',         'Check back soon for updates'),
      FeedTab.jobs     => (Icons.work_outline_rounded,  'No jobs yet',            'New job requests will appear here'),
      FeedTab.artisans => (Icons.people_outline_rounded,'No artisans featured',   'Featured artisans will appear here'),
      FeedTab.tips     => (Icons.lightbulb_outline_rounded,'No tips yet',         'Tips and updates will appear here'),
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(width: 76, height: 76,
              decoration: BoxDecoration(color: cs.primary.withOpacity(0.07), shape: BoxShape.circle),
              child: Icon(icon, size: 36, color: cs.primary.withOpacity(0.45))),
          const SizedBox(height: 18),
          Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.3),
              textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant, height: 1.5),
              textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}

class _FeedErrorState extends StatelessWidget {
  const _FeedErrorState({required this.message, required this.onRetry, required this.colorScheme});
  final String message;
  final VoidCallback onRetry;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: colorScheme.error.withOpacity(0.08), shape: BoxShape.circle),
              child: Icon(Icons.wifi_off_rounded, size: 38, color: colorScheme.error)),
          const SizedBox(height: 18),
          Text('Could not load feed', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(message, style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Try again'),
            style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12)),
          ),
        ]),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

String? _formatBudgetForJob(JobModel? job) {
  if (job?.budgetMin == null || job?.budgetMax == null) return null;
  return '₦${job!.budgetMin}-${job.budgetMax}';
}

FeedItemType? _parseFeedItemType(String value) {
  switch (value) {
    case 'job_request':      return FeedItemType.jobRequest;
    case 'featured_artisan': return FeedItemType.featuredArtisan;
    case 'completed_job':    return FeedItemType.completedJob;
    case 'announcement':     return FeedItemType.announcement;
    case 'tip':              return FeedItemType.tip;
  }
  return null;
}



