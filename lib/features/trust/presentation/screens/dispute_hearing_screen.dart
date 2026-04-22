import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/trust_provider.dart';

class DisputeHearingScreen extends ConsumerStatefulWidget {
  final String disputeId;
  final String bookingId;

  const DisputeHearingScreen({
    super.key,
    required this.disputeId,
    required this.bookingId,
  });

  @override
  ConsumerState<DisputeHearingScreen> createState() => _DisputeHearingScreenState();
}

class _DisputeHearingScreenState extends ConsumerState<DisputeHearingScreen>
    with SingleTickerProviderStateMixin {
  final _messageController = TextEditingController();
  late final TabController _tabController;

  // ── Design tokens ────────────────────────────────────────────────────────────
  static const _bg = Color(0xFF0D0E11);
  static const _surface = Color(0xFF161820);
  static const _border = Color(0xFF252830);
  static const _accent = Color(0xFFE2FF5D); // electric lime
  static const _accentSub = Color(0xFF5D7EFF); // cool indigo
  static const _textPrimary = Color(0xFFF0F1F5);
  static const _textSecondary = Color(0xFF6B7080);
  static const _danger = Color(0xFFFF5D7E);
  static const _mono = 'monospace';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _messageController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  // ── Actions ──────────────────────────────────────────────────────────────────
  Future<void> _submitMessage() async {
    final user = ref.read(authProvider).user;
    if (user == null) return;
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final ok = await ref.read(disputeHearingActionProvider.notifier).submitMessage(
          disputeId: widget.disputeId,
          senderId: user.id,
          message: text,
        );
    if (!mounted) return;
    if (ok) {
      _messageController.clear();
      ref.invalidate(disputeMessagesProvider(widget.disputeId));
      ref.invalidate(disputeEventsProvider(widget.disputeId));
    } else {
      _showSnack('Failed to submit response', isError: true);
    }
  }

  Future<void> _updateStatus(String status, String label) async {
    final user = ref.read(authProvider).user;
    if (user == null) return;
    final ok = await ref.read(disputeHearingActionProvider.notifier).updateStatus(
          disputeId: widget.disputeId,
          actorId: user.id,
          status: status,
          note: 'Updated by admin',
        );
    if (!mounted) return;
    _showSnack(ok ? 'Status → $label' : 'Failed to update status', isError: !ok);
    if (ok) ref.invalidate(disputeEventsProvider(widget.disputeId));
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? _danger.withOpacity(0.15) : _accent.withOpacity(0.12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: isError ? _danger : _accent, width: 0.5),
        ),
        content: Text(
          msg,
          style: TextStyle(
            color: isError ? _danger : _accent,
            fontSize: 12,
            fontFamily: _mono,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final isAdmin = user?.userType == 'admin';
    final disputeAsync = ref.watch(disputeDetailsProvider(widget.disputeId));
    final messagesAsync = ref.watch(disputeMessagesProvider(widget.disputeId));
    final eventsAsync = ref.watch(disputeEventsProvider(widget.disputeId));
    final isBusy = ref.watch(disputeHearingActionProvider).isLoading;

    return Theme(
      data: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: _bg,
        dividerColor: _border,
      ),
      child: Scaffold(
        backgroundColor: _bg,
        appBar: _buildAppBar(),
        body: Column(
          children: [
            _MetaStrip(
              bookingId: widget.bookingId,
              disputeId: widget.disputeId,
              status: disputeAsync.maybeWhen(
                data: (d) => d.status,
                orElse: () => null,
              ),
            ),
            disputeAsync.when(
              data: (dispute) => _DisputeSummary(dispute: dispute),
              loading: () => const _SummaryLoading(),
              error: (err, _) => _SummaryError(error: err.toString()),
            ),
            _buildTabBar(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _TimelineTab(eventsAsync: eventsAsync),
                  _StatementsTab(messagesAsync: messagesAsync),
                ],
              ),
            ),
            if (isAdmin) _AdminControls(isBusy: isBusy, onUpdate: _updateStatus),
            _InputBar(
              controller: _messageController,
              isBusy: isBusy,
              onSend: _submitMessage,
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() => AppBar(
        backgroundColor: _bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 16, color: _textSecondary),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'DISPUTE HEARING',
              style: TextStyle(
                color: _textPrimary,
                fontSize: 11,
                fontFamily: _mono,
                fontWeight: FontWeight.w600,
                letterSpacing: 2.5,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              '#${widget.disputeId.substring(0, 8).toUpperCase()}',
              style: const TextStyle(
                color: _textSecondary,
                fontSize: 10,
                fontFamily: _mono,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        titleSpacing: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _border),
        ),
      );

  Widget _buildTabBar() => Container(
        color: _surface,
        child: TabBar(
          controller: _tabController,
          indicatorColor: _accent,
          indicatorWeight: 1.5,
          indicatorSize: TabBarIndicatorSize.tab,
          labelColor: _accent,
          unselectedLabelColor: _textSecondary,
          labelStyle: const TextStyle(
            fontSize: 10,
            fontFamily: _mono,
            fontWeight: FontWeight.w600,
            letterSpacing: 2,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 10,
            fontFamily: _mono,
            letterSpacing: 2,
          ),
          tabs: const [
            Tab(text: 'TIMELINE'),
            Tab(text: 'STATEMENTS'),
          ],
        ),
      );
}

// ── Meta strip ────────────────────────────────────────────────────────────────
class _MetaStrip extends StatelessWidget {
  final String bookingId;
  final String disputeId;
  final String? status;

  const _MetaStrip({
    required this.bookingId,
    required this.disputeId,
    required this.status,
  });

  static const _bg = Color(0xFF0D0E11);
  static const _border = Color(0xFF252830);
  static const _textSecondary = Color(0xFF6B7080);
  static const _accentSub = Color(0xFF5D7EFF);
  static const _mono = 'monospace';

  @override
  Widget build(BuildContext context) {
    final statusLabel = (status ?? '...').replaceAll('_', ' ').toUpperCase();
    final bookingLabel = bookingId.isEmpty
        ? '—'
        : (bookingId.length >= 8 ? bookingId.substring(0, 8) : bookingId);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      decoration: const BoxDecoration(
        color: _bg,
        border: Border(bottom: BorderSide(color: _border)),
      ),
      child: Row(
        children: [
          _chip(Icons.receipt_long_outlined, 'BKG', bookingLabel.toUpperCase()),
          const SizedBox(width: 16),
          _chip(Icons.circle, 'STATUS', statusLabel, dotColor: Color(0xFFE2FF5D)),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String label, String value, {Color? dotColor}) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dotColor != null) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
          ] else ...[
            Icon(icon, size: 11, color: _textSecondary),
            const SizedBox(width: 5),
          ],
          Text(
            '$label · ',
            style: const TextStyle(
              color: _textSecondary,
              fontSize: 10,
              fontFamily: _mono,
              letterSpacing: 1,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: _accentSub,
              fontSize: 10,
              fontFamily: _mono,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
        ],
      );
}

class _DisputeSummary extends StatelessWidget {
  final dynamic dispute;

  const _DisputeSummary({required this.dispute});

  static const _surface = Color(0xFF161820);
  static const _border = Color(0xFF252830);
  static const _textPrimary = Color(0xFFF0F1F5);
  static const _textSecondary = Color(0xFF6B7080);
  static const _accent = Color(0xFFE2FF5D);
  static const _mono = 'monospace';

  void _openEvidence(BuildContext context, String url) {
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        backgroundColor: Colors.black,
        child: InteractiveViewer(
          child: Image.network(
            url,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Padding(
              padding: EdgeInsets.all(24),
              child: Icon(Icons.broken_image_outlined, color: _textSecondary),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final evidence = (dispute.evidenceUrls as List?)?.map((e) => e.toString()).toList() ?? const [];
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'DISPUTE SUMMARY',
            style: TextStyle(
              color: _textSecondary,
              fontSize: 9,
              fontFamily: _mono,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            dispute.reason as String,
            style: const TextStyle(
              color: _textPrimary,
              fontSize: 12.5,
              height: 1.55,
            ),
          ),
          if (evidence.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.attach_file, size: 12, color: _textSecondary),
                const SizedBox(width: 4),
                Text(
                  '${evidence.length} EVIDENCE',
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
            SizedBox(
              height: 64,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: evidence.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (ctx, i) => GestureDetector(
                  onTap: () => _openEvidence(context, evidence[i]),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.network(
                      evidence[i],
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                      loadingBuilder: (_, child, progress) => progress == null
                          ? child
                          : Container(
                              width: 64,
                              height: 64,
                              alignment: Alignment.center,
                              color: _border,
                              child: const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.2,
                                  color: _accent,
                                ),
                              ),
                            ),
                      errorBuilder: (_, __, ___) => Container(
                        width: 64,
                        height: 64,
                        color: _border,
                        child: const Icon(Icons.broken_image_outlined,
                            color: _textSecondary, size: 20),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryLoading extends StatelessWidget {
  const _SummaryLoading();

  static const _border = Color(0xFF252830);
  static const _surface = Color(0xFF161820);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _border),
      ),
      child: const SizedBox(
        height: 56,
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 1.4),
          ),
        ),
      ),
    );
  }
}

class _SummaryError extends StatelessWidget {
  final String error;

  const _SummaryError({required this.error});

  static const _border = Color(0xFF252830);
  static const _surface = Color(0xFF161820);
  static const _danger = Color(0xFFFF5D7E);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _border),
      ),
      child: Text(
        'Failed to load dispute summary: $error',
        style: const TextStyle(color: _danger, fontSize: 11),
      ),
    );
  }
}

// ── Timeline tab ──────────────────────────────────────────────────────────────
class _TimelineTab extends StatelessWidget {
  final AsyncValue eventsAsync;

  const _TimelineTab({required this.eventsAsync});

  static const _bg = Color(0xFF0D0E11);
  static const _border = Color(0xFF252830);
  static const _textPrimary = Color(0xFFF0F1F5);
  static const _textSecondary = Color(0xFF6B7080);
  static const _accent = Color(0xFFE2FF5D);
  static const _mono = 'monospace';

  @override
  Widget build(BuildContext context) {
    return eventsAsync.when(
      data: (events) => events.isEmpty
          ? _empty()
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 12),
              itemCount: events.length,
              itemBuilder: (ctx, i) => _EventTile(
                event: events[i],
                isLast: i == events.length - 1,
              ),
            ),
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
          style: const TextStyle(color: Color(0xFFFF5D7E), fontSize: 11, fontFamily: _mono),
        ),
      ),
    );
  }

  Widget _empty() => const Center(
        child: Text(
          'NO EVENTS',
          style: TextStyle(color: _textSecondary, fontSize: 10, fontFamily: _mono, letterSpacing: 2),
        ),
      );
}

class _EventTile extends StatelessWidget {
  final dynamic event;
  final bool isLast;

  const _EventTile({required this.event, required this.isLast});

  static const _border = Color(0xFF252830);
  static const _textPrimary = Color(0xFFF0F1F5);
  static const _textSecondary = Color(0xFF6B7080);
  static const _accent = Color(0xFFE2FF5D);
  static const _mono = 'monospace';

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(width: 20),
          Column(
            children: [
              Container(
                width: 7,
                height: 7,
                margin: const EdgeInsets.only(top: 5),
                decoration: BoxDecoration(
                  color: _accent,
                  shape: BoxShape.circle,
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(width: 1, color: _border),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (event.eventType as String).replaceAll('_', ' ').toUpperCase(),
                    style: const TextStyle(
                      color: _textPrimary,
                      fontSize: 11,
                      fontFamily: _mono,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
                    ),
                  ),
                  if ((event.note ?? '').isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      event.note!,
                      style: const TextStyle(
                        color: _textSecondary,
                        fontSize: 10,
                        fontFamily: _mono,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
    );
  }
}

// ── Statements tab ────────────────────────────────────────────────────────────
class _StatementsTab extends StatelessWidget {
  final AsyncValue messagesAsync;

  const _StatementsTab({required this.messagesAsync});

  static const _accent = Color(0xFFE2FF5D);
  static const _textSecondary = Color(0xFF6B7080);
  static const _mono = 'monospace';

  @override
  Widget build(BuildContext context) {
    return messagesAsync.when(
      data: (messages) => messages.isEmpty
          ? const Center(
              child: Text(
                'NO STATEMENTS',
                style: TextStyle(
                  color: _textSecondary,
                  fontSize: 10,
                  fontFamily: _mono,
                  letterSpacing: 2,
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(14),
              itemCount: messages.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) => _StatementCard(message: messages[i]),
            ),
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
          style: const TextStyle(color: Color(0xFFFF5D7E), fontSize: 11, fontFamily: _mono),
        ),
      ),
    );
  }
}

class _StatementCard extends StatelessWidget {
  final dynamic message;

  const _StatementCard({required this.message});

  static const _surface = Color(0xFF161820);
  static const _border = Color(0xFF252830);
  static const _textPrimary = Color(0xFFF0F1F5);
  static const _textSecondary = Color(0xFF6B7080);
  static const _accentSub = Color(0xFF5D7EFF);
  static const _mono = 'monospace';

  @override
  Widget build(BuildContext context) {
    final evidence = (message.evidenceUrls as List?)?.map((e) => e.toString()).toList() ?? const [];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: _accentSub.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(color: _accentSub.withOpacity(0.3)),
                ),
                child: Text(
                  (message.senderId as String).substring(0, 8).toUpperCase(),
                  style: const TextStyle(
                    color: _accentSub,
                    fontSize: 9,
                    fontFamily: _mono,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                _formatTime(message.createdAt as DateTime),
                style: const TextStyle(
                  color: _textSecondary,
                  fontSize: 9,
                  fontFamily: _mono,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            message.message as String,
            style: const TextStyle(
              color: _textPrimary,
              fontSize: 12.5,
              height: 1.55,
            ),
          ),
          if (evidence.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: evidence
                  .map((url) => ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Image.network(
                          url,
                          width: 64,
                          height: 64,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 64,
                            height: 64,
                            color: _border,
                            child: const Icon(Icons.broken_image_outlined,
                                color: _textSecondary, size: 18),
                          ),
                        ),
                      ))
                  .toList(growable: false),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final l = dt.toLocal();
    return '${l.year}-${l.month.toString().padLeft(2, '0')}-${l.day.toString().padLeft(2, '0')} '
        '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
  }
}

// ── Admin controls ────────────────────────────────────────────────────────────
class _AdminControls extends StatelessWidget {
  final bool isBusy;
  final Future<void> Function(String, String) onUpdate;

  const _AdminControls({required this.isBusy, required this.onUpdate});

  static const _border = Color(0xFF252830);
  static const _surface = Color(0xFF161820);
  static const _textSecondary = Color(0xFF6B7080);
  static const _accent = Color(0xFFE2FF5D);
  static const _danger = Color(0xFFFF5D7E);
  static const _accentSub = Color(0xFF5D7EFF);
  static const _mono = 'monospace';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: const BoxDecoration(
        color: _surface,
        border: Border(top: BorderSide(color: _border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'ADMIN CONTROLS',
            style: TextStyle(
              color: _textSecondary,
              fontSize: 9,
              fontFamily: _mono,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _ctl(label: 'AWAIT', color: _textSecondary, onTap: () => onUpdate('open', 'Await Respondent')),
              const SizedBox(width: 6),
              _ctl(label: 'REVIEW', color: _accentSub, onTap: () => onUpdate('in_review', 'Under Review')),
              const SizedBox(width: 6),
              _ctl(label: 'REFUND', color: _danger, filled: true, onTap: () => onUpdate('resolved_refund', 'Refund')),
              const SizedBox(width: 6),
              _ctl(label: 'RELEASE', color: _accent, filled: true, onTap: () => onUpdate('resolved_release', 'Release')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _ctl({
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool filled = false,
  }) =>
      Expanded(
        child: GestureDetector(
          onTap: isBusy ? null : onTap,
          child: AnimatedOpacity(
            opacity: isBusy ? 0.4 : 1,
            duration: const Duration(milliseconds: 150),
            child: Container(
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: filled ? color.withOpacity(0.14) : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: color.withOpacity(filled ? 0.5 : 0.3)),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 9,
                  fontFamily: _mono,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ),
        ),
      );
}

// ── Input bar ─────────────────────────────────────────────────────────────────
class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool isBusy;
  final VoidCallback onSend;

  const _InputBar({
    required this.controller,
    required this.isBusy,
    required this.onSend,
  });

  static const _bg = Color(0xFF0D0E11);
  static const _surface = Color(0xFF161820);
  static const _border = Color(0xFF252830);
  static const _accent = Color(0xFFE2FF5D);
  static const _textPrimary = Color(0xFFF0F1F5);
  static const _textSecondary = Color(0xFF6B7080);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        decoration: const BoxDecoration(
          color: _bg,
          border: Border(top: BorderSide(color: _border)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _border),
                ),
                child: TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 4,
                  style: const TextStyle(
                    color: _textPrimary,
                    fontSize: 13,
                    height: 1.4,
                  ),
                  cursorColor: _accent,
                  cursorWidth: 1.5,
                  decoration: const InputDecoration(
                    hintText: 'Add your statement...',
                    hintStyle: TextStyle(color: _textSecondary, fontSize: 13),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: isBusy ? null : onSend,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isBusy ? _border : _accent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  Icons.arrow_upward_rounded,
                  color: isBusy ? _textSecondary : const Color(0xFF0D0E11),
                  size: 18,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


