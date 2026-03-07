// lib/features/trust/presentation/screens/dispute_form_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/trust_provider.dart';
import '../widgets/camera_screen.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────
const _bg = Color(0xFF0D0E11);
const _surface = Color(0xFF161820);
const _border = Color(0xFF252830);
const _accent = Color(0xFFE2FF5D);
const _accentSub = Color(0xFF5D7EFF);
const _textPrimary = Color(0xFFF0F1F5);
const _textSecondary = Color(0xFF6B7080);
const _danger = Color(0xFFFF5D7E);
const _warn = Color(0xFFFFB547);
const _mono = 'monospace';

// ── Full-screen zoom viewer ───────────────────────────────────────────────────
class _ImageViewerScreen extends StatefulWidget {
  final List<String> paths;
  final int initialIndex;

  const _ImageViewerScreen({required this.paths, required this.initialIndex});

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
          '${_current + 1} / ${widget.paths.length}',
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
        itemCount: widget.paths.length,
        onPageChanged: (i) => setState(() => _current = i),
        itemBuilder: (ctx, i) => _ZoomableImage(filePath: widget.paths[i]),
      ),
      bottomNavigationBar: widget.paths.length > 1
          ? SafeArea(
              child: SizedBox(
                height: 56,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                  itemCount: widget.paths.length,
                  itemBuilder: (ctx, i) => GestureDetector(
                    onTap: () {
                      _pageController.animateToPage(
                        i,
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOut,
                      );
                    },
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
                        child: Image.file(
                          File(widget.paths[i]),
                          fit: BoxFit.cover,
                        ),
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

class _ZoomableImage extends StatefulWidget {
  final String filePath;
  const _ZoomableImage({required this.filePath});

  @override
  State<_ZoomableImage> createState() => _ZoomableImageState();
}

class _ZoomableImageState extends State<_ZoomableImage> {
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
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTapDown: (d) => _doubleTapDetails = d,
      onDoubleTap: _handleDoubleTap,
      child: InteractiveViewer(
        transformationController: _transformController,
        minScale: 0.8,
        maxScale: 5.0,
        child: Center(
          child: Image.file(
            File(widget.filePath),
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Center(
              child: Icon(Icons.broken_image_outlined, color: _textSecondary, size: 48),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Main screen ───────────────────────────────────────────────────────────────
class DisputeFormScreen extends ConsumerStatefulWidget {
  final String bookingId;

  const DisputeFormScreen({
    super.key,
    required this.bookingId,
  });

  @override
  ConsumerState<DisputeFormScreen> createState() => _DisputeFormScreenState();
}

class _DisputeFormScreenState extends ConsumerState<DisputeFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  final List<String> _evidencePaths = [];
  bool _isProcessing = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<bool> _requestCameraPermission() async {
    try {
      return (await Permission.camera.request()).isGranted;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _requestStoragePermission() async {
    try {
      if (Platform.isAndroid) {
        if ((await Permission.photos.request()).isGranted) return true;
        return (await Permission.storage.request()).isGranted;
      }
      return (await Permission.photos.request()).isGranted;
    } catch (e) {
      return false;
    }
  }

  Future<void> _showPermissionDialog(String permission) async {
    if (!mounted) return;
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: _border),
        ),
        title: Text(
          '$permission Permission Required'.toUpperCase(),
          style: const TextStyle(color: _textPrimary, fontSize: 12, fontFamily: _mono, letterSpacing: 1),
        ),
        content: Text(
          'Please enable $permission permission in your device settings to continue.',
          style: const TextStyle(color: _textSecondary, fontSize: 12),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel', style: TextStyle(color: _textSecondary, fontSize: 11, fontFamily: _mono)),
          ),
          TextButton(
            onPressed: () { Navigator.of(context).pop(); openAppSettings(); },
            child: const Text('Open Settings', style: TextStyle(color: _accent, fontSize: 11, fontFamily: _mono)),
          ),
        ],
      ),
    );
  }

  Future<void> _captureEvidence() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    try {
      if (!await _requestCameraPermission()) {
        if (!mounted) return;
        await _showPermissionDialog('Camera');
        return;
      }
      if (!mounted) return;
      final String? imagePath = await Navigator.of(context).push<String>(
        MaterialPageRoute(builder: (_) => const CameraScreen(useFrontCamera: false)),
      );
      if (!mounted) return;
      if (imagePath != null) {
        final savedPath = await _saveImageToAppDirectory(imagePath, 'evidence');
        if (!mounted) return;
        if (savedPath != null) {
          setState(() => _evidencePaths.add(savedPath));
          _showSnackBar('Evidence photo added');
        } else {
          _showSnackBar('Failed to save photo', isError: true);
        }
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Error: ${e.toString()}', isError: true);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _pickEvidence() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    try {
      if (!await _requestStoragePermission()) {
        if (!mounted) return;
        await _showPermissionDialog('Storage');
        return;
      }
      final images = await ImagePicker().pickMultiImage(imageQuality: 85, maxWidth: 1920, maxHeight: 1920);
      if (!mounted) return;
      if (images.isNotEmpty) {
        for (final image in images) {
          final savedPath = await _saveImageToAppDirectory(image.path, 'evidence');
          if (savedPath != null) setState(() => _evidencePaths.add(savedPath));
        }
        if (mounted) _showSnackBar('${images.length} photo(s) added');
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Error: ${e.toString()}', isError: true);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<String?> _saveImageToAppDirectory(String sourcePath, String prefix) async {
    try {
      final sourceFile = File(sourcePath);
      if (!await sourceFile.exists()) return null;
      final appDir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${prefix}_$timestamp.jpg';
      final newPath = path.join(appDir.path, 'disputes', fileName);
      final newFile = File(newPath);
      await newFile.parent.create(recursive: true);
      await sourceFile.copy(newPath);
      if (!await newFile.exists()) return null;
      if (await newFile.length() == 0) { await newFile.delete(); return null; }
      return newPath;
    } catch (e) {
      return null;
    }
  }

  void _removeEvidence(int index) => setState(() => _evidencePaths.removeAt(index));

  void _openViewer(int index) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _ImageViewerScreen(paths: _evidencePaths, initialIndex: index),
        fullscreenDialog: true,
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final user = ref.read(authProvider).user;
    if (user == null) { _showSnackBar('User not authenticated', isError: true); return; }
    final ok = await ref.read(disputeProvider.notifier).openDispute(
      bookingId: widget.bookingId,
      openedBy: user.id,
      reason: _reasonController.text.trim(),
      evidenceFilePaths: _evidencePaths,
    );
    if (!mounted) return;
    if (ok) {
      ref.invalidate(disputesByBookingProvider(widget.bookingId));
      _showSnackBar('Dispute opened successfully');
      Navigator.pop(context);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? _danger.withOpacity(0.15) : _accent.withOpacity(0.12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: BorderSide(color: isError ? _danger : _accent, width: 0.5),
        ),
        content: Text(
          message,
          style: TextStyle(
            color: isError ? _danger : _accent,
            fontSize: 11,
            fontFamily: _mono,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final disputeState = ref.watch(disputeProvider);
    final disputesAsync = ref.watch(disputesByBookingProvider(widget.bookingId));

    ref.listen<DisputeState>(disputeProvider, (previous, next) {
      if (next.error != null && next.error != previous?.error && mounted) {
        _showSnackBar(next.error!, isError: true);
      }
    });

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
                'OPEN DISPUTE',
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
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: _border),
          ),
        ),
        body: disputesAsync.when(
          data: (disputes) {
            final hasOpenDispute = disputes.any(
              (d) => d.status == 'open' || d.status == 'investigating',
            );
            final isBusy = disputeState.isSubmitting || _isProcessing;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (hasOpenDispute) ...[
                    _InfoBanner(
                      text: 'An open dispute already exists for this booking.',
                      color: _warn,
                      icon: Icons.warning_amber_rounded,
                    ),
                    const SizedBox(height: 10),
                  ],
                  _InfoBanner(
                    text: 'Describe the issue clearly and attach evidence where possible.',
                    color: _accentSub,
                    icon: Icons.info_outline_rounded,
                  ),
                  const SizedBox(height: 20),

                  // ── Reason field ───────────────────────────────────────────
                  _Label(text: 'REASON'),
                  const SizedBox(height: 8),
                  Form(
                    key: _formKey,
                    child: TextFormField(
                      controller: _reasonController,
                      maxLines: 5,
                      style: const TextStyle(color: _textPrimary, fontSize: 13, height: 1.5),
                      cursorColor: _accent,
                      cursorWidth: 1.5,
                      enabled: !hasOpenDispute && !isBusy,
                      decoration: InputDecoration(
                        hintText: 'Describe the issue in detail...',
                        hintStyle: const TextStyle(color: _textSecondary, fontSize: 13),
                        filled: true,
                        fillColor: _surface,
                        contentPadding: const EdgeInsets.all(14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: const BorderSide(color: _border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: const BorderSide(color: _border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: const BorderSide(color: _accent, width: 1),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: const BorderSide(color: _danger),
                        ),
                        errorStyle: const TextStyle(color: _danger, fontSize: 10, fontFamily: _mono),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) return 'Please describe the issue';
                        if (value.trim().length < 10) return 'Minimum 10 characters required';
                        return null;
                      },
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Evidence section ───────────────────────────────────────
                  _Label(text: 'EVIDENCE'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.camera_alt_outlined,
                          label: 'CAMERA',
                          disabled: hasOpenDispute || isBusy,
                          onTap: _captureEvidence,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.photo_library_outlined,
                          label: 'GALLERY',
                          disabled: hasOpenDispute || isBusy,
                          onTap: _pickEvidence,
                        ),
                      ),
                    ],
                  ),

                  if (_isProcessing) ...[
                    const SizedBox(height: 16),
                    const Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 1.5, color: _accent),
                      ),
                    ),
                  ],

                  if (_evidencePaths.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _EvidenceGrid(
                      paths: _evidencePaths,
                      onTap: _openViewer,
                      onRemove: _removeEvidence,
                      disabled: isBusy,
                    ),
                  ],

                  const SizedBox(height: 28),

                  // ── Submit ─────────────────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: GestureDetector(
                      onTap: hasOpenDispute || isBusy ? null : _submit,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        decoration: BoxDecoration(
                          color: (hasOpenDispute || isBusy)
                              ? _border
                              : _accent,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        alignment: Alignment.center,
                        child: disputeState.isSubmitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.5,
                                  color: _bg,
                                ),
                              )
                            : Text(
                                'SUBMIT DISPUTE',
                                style: TextStyle(
                                  color: (hasOpenDispute || isBusy) ? _textSecondary : _bg,
                                  fontSize: 11,
                                  fontFamily: _mono,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 2,
                                ),
                              ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
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
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: _danger, size: 36),
                const SizedBox(height: 12),
                Text('ERR: $err',
                    style: const TextStyle(color: _textSecondary, fontSize: 11, fontFamily: _mono)),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () => ref.invalidate(disputesByBookingProvider(widget.bookingId)),
                  child: const Text('RETRY',
                      style: TextStyle(color: _accent, fontSize: 11, fontFamily: _mono, letterSpacing: 2)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Evidence grid with tap-to-zoom ────────────────────────────────────────────
class _EvidenceGrid extends StatelessWidget {
  final List<String> paths;
  final void Function(int) onTap;
  final void Function(int) onRemove;
  final bool disabled;

  const _EvidenceGrid({
    required this.paths,
    required this.onTap,
    required this.onRemove,
    required this.disabled,
  });

  @override
  Widget build(BuildContext context) {
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
              const Icon(Icons.attach_file, size: 12, color: _textSecondary),
              const SizedBox(width: 6),
              Text(
                '${paths.length} ATTACHMENT${paths.length == 1 ? '' : 'S'}',
                style: const TextStyle(
                  color: _textSecondary,
                  fontSize: 9,
                  fontFamily: _mono,
                  letterSpacing: 2,
                ),
              ),
              const Spacer(),
              const Text(
                'TAP TO ZOOM',
                style: TextStyle(
                  color: _textSecondary,
                  fontSize: 9,
                  fontFamily: _mono,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.zoom_in, size: 12, color: _textSecondary),
            ],
          ),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: paths.length,
            itemBuilder: (ctx, i) => _EvidenceThumbnail(
              filePath: paths[i],
              index: i,
              onTap: () => onTap(i),
              onRemove: disabled ? null : () => onRemove(i),
            ),
          ),
        ],
      ),
    );
  }
}

class _EvidenceThumbnail extends StatelessWidget {
  final String filePath;
  final int index;
  final VoidCallback onTap;
  final VoidCallback? onRemove;

  const _EvidenceThumbnail({
    required this.filePath,
    required this.index,
    required this.onTap,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: Image.file(
              File(filePath),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                decoration: BoxDecoration(
                  color: _border,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: const Icon(Icons.broken_image_outlined, color: _textSecondary, size: 24),
              ),
            ),
          ),
          // Zoom hint overlay
          Positioned(
            bottom: 4,
            right: 4,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.55),
                borderRadius: BorderRadius.circular(3),
              ),
              child: const Icon(Icons.zoom_in, color: Colors.white, size: 13),
            ),
          ),
          // Remove button
          if (onRemove != null)
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: onRemove,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.65),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 12),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Small reusable widgets ────────────────────────────────────────────────────
class _Label extends StatelessWidget {
  final String text;
  const _Label({required this.text});

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          color: _textSecondary,
          fontSize: 9,
          fontFamily: _mono,
          letterSpacing: 2,
        ),
      );
}

class _InfoBanner extends StatelessWidget {
  final String text;
  final Color color;
  final IconData icon;

  const _InfoBanner({required this.text, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 15),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: TextStyle(color: color, fontSize: 12, height: 1.4),
              ),
            ),
          ],
        ),
      );
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool disabled;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.disabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: disabled ? null : onTap,
        child: AnimatedOpacity(
          opacity: disabled ? 0.35 : 1,
          duration: const Duration(milliseconds: 150),
          child: Container(
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: _border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: _textSecondary, size: 15),
                const SizedBox(width: 7),
                Text(
                  label,
                  style: const TextStyle(
                    color: _textSecondary,
                    fontSize: 10,
                    fontFamily: _mono,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

