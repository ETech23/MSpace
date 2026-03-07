// lib/features/trust/presentation/screens/admin_disputes_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/trust_provider.dart';
import '../../domain/entities/dispute_entity.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────
const _bg = Color(0xFF0D0E11);
const _surface = Color(0xFF161820);
const _surfaceHigh = Color(0xFF1C1E27);
const _border = Color(0xFF252830);
const _accent = Color(0xFFE2FF5D);
const _accentSub = Color(0xFF5D7EFF);
const _textPrimary = Color(0xFFF0F1F5);
const _textSecondary = Color(0xFF6B7080);
const _danger = Color(0xFFFF5D7E);
const _mono = 'monospace';

// ── Status helpers ────────────────────────────────────────────────────────────
Color _statusColor(String status) {
  switch (status) {
    case 'open': return const Color(0xFFE2FF5D);
    case 'in_review': return const Color(0xFF5D7EFF);
    case 'resolved_refund': return const Color(0xFFFF5D7E);
    case 'resolved_release': return const Color(0xFF5DFFB8);
    default: return const Color(0xFF6B7080);
  }
}

String _statusLabel(String status) =>
    status.replaceAll('_', ' ').toUpperCase();

// ── Full-screen zoom viewer ───────────────────────────────────────────────────
class _ImageViewerScreen extends StatefulWidget {
  final List<String> urls;
  final int initialIndex;

  const _ImageViewerScreen({required this.urls, required this.initialIndex});

  @override
  State<_ImageViewerScreen> createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends State<_ImageViewerScreen> {
  late final PageController _pageController;
  late int _current;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: _textSecondary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          '${_current + 1} / ${widget.urls.length}',
          style: const TextStyle(
            color: _textSecondary,
            fontSize: 11,
            fontFamily: _mono,
            letterSpacing: 2,
          ),
        ),
        centerTitle: true,
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.urls.length,
        onPageChanged: (i) => setState(() => _current = i),
        itemBuilder: (_, i) => _ZoomableNetworkImage(url: widget.urls[i]),
      ),
      bottomNavigationBar: widget.urls.length > 1
          ? SafeArea(
              child: SizedBox(
                height: 56,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                  itemCount: widget.urls.length,
                  itemBuilder: (_, i) => GestureDetector(
                    onTap: () => _pageController.animateToPage(
                      i,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                    ),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 40,
                      height: 40,
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: i == _current ? _accent : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: Image.network(widget.urls[i], fit: BoxFit.cover),
                      ),
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }
}

class _ZoomableNetworkImage extends StatefulWidget {
  final String url;
  const _ZoomableNetworkImage({required this.url});

  @override
  State<_ZoomableNetworkImage> createState() => _ZoomableNetworkImageState();
}

class _ZoomableNetworkImageState extends State<_ZoomableNetworkImage> {
  final _transformController = TransformationController();
  TapDownDetails? _doubleTapDetails;

  void _handleDoubleTap() {
    if (_transformController.value != Matrix4.identity()) {
      _transformController.value = Matrix4.identity();
    } else {
      final pos = _doubleTapDetails!.localPosition;
      _transformController.value = Matrix4.identity()
        ..translate(-pos.dx * 1.5, -pos.dy * 1.5)
        ..scale(2.5);
    }
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        onDoubleTapDown: (d) => _doubleTapDetails = d,
        onDoubleTap: _handleDoubleTap,
        child: InteractiveViewer(
          transformationController: _transformController,
          minScale: 0.8,
          maxScale: 5.0,
          child: Center(
            child: Image.network(
              widget.url,
              fit: BoxFit.contain,
              loadingBuilder: (_, child, progress) => progress == null
                  ? child
                  : const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 1.5, color: _accent),
                      ),
                    ),
              errorBuilder: (_, __, ___) => const Center(
                child: Icon(Icons.broken_image_outlined, color: _textSecondary, size: 48),
              ),
            ),
          ),
        ),
      );
}

// ── Main screen ───────────────────────────────────────────────────────────────
class AdminDisputesScreen extends ConsumerWidget {
  const AdminDisputesScreen({super.key});

  Future<void> _resolve(WidgetRef ref, DisputeEntity dispute, String status) async {
    final repo = ref.read(trustRepositoryProvider);
    await repo.adminResolveDispute(disputeId: dispute.id, status: status);
    ref.invalidate(adminDisputesProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(adminDisputesProvider);

    return Theme(
      data: ThemeData.dark().copyWith(scaffoldBackgroundColor: _bg),
      child: Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          backgroundColor: _bg,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 16, color: _textSecondary),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          title: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'DISPUTES',
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 11,
                  fontFamily: _mono,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2.5,
                ),
              ),
            ],
          ),
          titleSpacing: 0,
          actions: [
            data.whenOrNull(
              data: (items) => Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: _accent.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: _accent.withOpacity(0.3)),
                    ),
                    child: Text(
                      '${items.length}',
                      style: const TextStyle(
                        color: _accent,
                        fontSize: 10,
                        fontFamily: _mono,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ) ?? const SizedBox.shrink(),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: _border),
          ),
        ),
        body: data.when(
          data: (items) {
            if (items.isEmpty) {
              return const Center(
                child: Text(
                  'NO OPEN DISPUTES',
                  style: TextStyle(
                    color: _textSecondary,
                    fontSize: 10,
                    fontFamily: _mono,
                    letterSpacing: 2,
                  ),
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(14),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) => _DisputeCard(
                dispute: items[index],
                onResolve: (status) => _resolve(ref, items[index], status),
                onHearing: () => context.push(
                  '/disputes/${items[index].id}/hearing?bookingId=${items[index].bookingId}',
                ),
              ),
            );
          },
          loading: () => const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 1.5, color: _accent),
            ),
          ),
          error: (err, _) => Center(
            child: Text(
              'ERR: $err',
              style: const TextStyle(color: _danger, fontSize: 11, fontFamily: _mono),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Dispute card ──────────────────────────────────────────────────────────────
class _DisputeCard extends StatelessWidget {
  final DisputeEntity dispute;
  final void Function(String) onResolve;
  final VoidCallback onHearing;

  const _DisputeCard({
    required this.dispute,
    required this.onResolve,
    required this.onHearing,
  });

  void _openViewer(BuildContext context, int index) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _ImageViewerScreen(
          urls: dispute.evidenceUrls,
          initialIndex: index,
        ),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(dispute.status);

    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: _border)),
            ),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Text(
                  _statusLabel(dispute.status),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 9,
                    fontFamily: _mono,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
                const Spacer(),
                Text(
                  '#${dispute.id.substring(0, 8).toUpperCase()}',
                  style: const TextStyle(
                    color: _textSecondary,
                    fontSize: 9,
                    fontFamily: _mono,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),

          // ── Meta ─────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _MetaRow(label: 'BOOKING', value: dispute.bookingId.substring(0, 8).toUpperCase()),
                const SizedBox(height: 6),
                _MetaRow(label: 'OPENED BY', value: dispute.openedBy.substring(0, 8).toUpperCase()),
                const SizedBox(height: 10),
                Text(
                  dispute.reason,
                  style: const TextStyle(
                    color: _textPrimary,
                    fontSize: 12.5,
                    height: 1.55,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // ── Evidence grid ────────────────────────────────────────────────
          if (dispute.evidenceUrls.isNotEmpty) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.attach_file, size: 11, color: _textSecondary),
                      const SizedBox(width: 5),
                      Text(
                        '${dispute.evidenceUrls.length} EVIDENCE · TAP TO ZOOM',
                        style: const TextStyle(
                          color: _textSecondary,
                          fontSize: 9,
                          fontFamily: _mono,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      crossAxisSpacing: 6,
                      mainAxisSpacing: 6,
                    ),
                    itemCount: dispute.evidenceUrls.length,
                    itemBuilder: (ctx, i) => GestureDetector(
                      onTap: () => _openViewer(context, i),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(5),
                            child: Image.network(
                              dispute.evidenceUrls[i],
                              fit: BoxFit.cover,
                              loadingBuilder: (_, child, progress) => progress == null
                                  ? child
                                  : Container(
                                      color: _surfaceHigh,
                                      child: const Center(
                                        child: SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 1, color: _accent),
                                        ),
                                      ),
                                    ),
                              errorBuilder: (_, __, ___) => Container(
                                decoration: BoxDecoration(
                                  color: _border,
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: const Icon(Icons.broken_image_outlined,
                                    color: _textSecondary, size: 20),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 3,
                            right: 3,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.55),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: const Icon(Icons.zoom_in, color: Colors.white, size: 11),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),

          // ── Actions ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Column(
              children: [
                // Hearing button
                GestureDetector(
                  onTap: onHearing,
                  child: Container(
                    width: double.infinity,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _accentSub.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: _accentSub.withOpacity(0.35)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.gavel_rounded, color: _accentSub, size: 14),
                        SizedBox(width: 7),
                        Text(
                          'OPEN HEARING',
                          style: TextStyle(
                            color: _accentSub,
                            fontSize: 10,
                            fontFamily: _mono,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Resolve buttons
                Row(
                  children: [
                    Expanded(
                      child: _ResolveButton(
                        label: 'REFUND',
                        color: _danger,
                        onTap: () => onResolve('resolved_refund'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ResolveButton(
                        label: 'RELEASE',
                        color: _accent,
                        onTap: () => onResolve('resolved_release'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final String label;
  final String value;

  const _MetaRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Text(
            '$label · ',
            style: const TextStyle(
              color: _textSecondary,
              fontSize: 9,
              fontFamily: _mono,
              letterSpacing: 1,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: _accentSub,
              fontSize: 9,
              fontFamily: _mono,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
        ],
      );
}

class _ResolveButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ResolveButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: color.withOpacity(0.35)),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontFamily: _mono,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
        ),
      );
}

