// lib/features/trust/presentation/screens/report_form_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/trust_provider.dart';

class ReportFormScreen extends ConsumerStatefulWidget {
  final String targetType;
  final String targetId;
  final String targetLabel;

  const ReportFormScreen({
    super.key,
    required this.targetType,
    required this.targetId,
    required this.targetLabel,
  });

  @override
  ConsumerState<ReportFormScreen> createState() => _ReportFormScreenState();
}

class _ReportFormScreenState extends ConsumerState<ReportFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  bool _alsoBlockUser = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final user = ref.read(authProvider).user;
    if (user == null) return;

    final ok = await ref.read(reportProvider.notifier).submitReport(
          reporterId: user.id,
          targetType: widget.targetType,
          targetId: widget.targetId,
          reason: _reasonController.text.trim(),
        );

    if (ok &&
        _alsoBlockUser &&
        widget.targetType == 'user' &&
        widget.targetId.isNotEmpty) {
      await ref.read(blockActionProvider.notifier).blockUser(
            blockerId: user.id,
            blockedUserId: widget.targetId,
            reason: _reasonController.text.trim(),
          );
    }

    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _alsoBlockUser && widget.targetType == 'user'
                ? 'Report submitted and user blocked'
                : 'Report submitted',
          ),
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reportState = ref.watch(reportProvider);

    ref.listen<ReportState>(reportProvider, (previous, next) {
      if (next.error != null && next.error != previous?.error && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.error!)),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Report'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reporting: ${widget.targetLabel}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Form(
              key: _formKey,
              child: TextFormField(
                controller: _reasonController,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Reason',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please describe the issue';
                  }
                  return null;
                },
              ),
            ),
            if (widget.targetType == 'user') ...[
              const SizedBox(height: 12),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _alsoBlockUser,
                onChanged: (value) {
                  setState(() {
                    _alsoBlockUser = value ?? false;
                  });
                },
                title: const Text('Also block this user'),
                subtitle: const Text(
                  'You can unblock them later from Settings.',
                ),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: reportState.isSubmitting ? null : _submit,
                child: reportState.isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Submit Report'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
