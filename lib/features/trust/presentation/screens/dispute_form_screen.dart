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

  /// Request camera permission
  Future<bool> _requestCameraPermission() async {
    try {
      final status = await Permission.camera.request();
      return status.isGranted;
    } catch (e) {
      debugPrint('Camera permission error: $e');
      return false;
    }
  }

  /// Request storage permission
  Future<bool> _requestStoragePermission() async {
    try {
      if (Platform.isAndroid) {
        var status = await Permission.photos.request();
        if (status.isGranted) return true;
        
        status = await Permission.storage.request();
        return status.isGranted;
      } else {
        final status = await Permission.photos.request();
        return status.isGranted;
      }
    } catch (e) {
      debugPrint('Storage permission error: $e');
      return false;
    }
  }

  /// Show permission dialog
  Future<void> _showPermissionDialog(String permission) async {
    if (!mounted) return;
    
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$permission Permission Required'),
        content: Text(
          'Please enable $permission permission in your device settings to continue.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  /// Capture evidence with camera
  Future<void> _captureEvidence() async {
    if (_isProcessing) return;
    
    setState(() => _isProcessing = true);
    
    try {
      final hasPermission = await _requestCameraPermission();
      
      if (!hasPermission) {
        if (!mounted) return;
        await _showPermissionDialog('Camera');
        return;
      }

      if (!mounted) return;

      // Open custom camera screen
      final String? imagePath = await Navigator.of(context).push<String>(
        MaterialPageRoute(
          builder: (context) => const CameraScreen(useFrontCamera: false),
        ),
      );

      if (!mounted) return;

      if (imagePath != null) {
        final savedPath = await _saveImageToAppDirectory(imagePath, 'evidence');
        
        if (!mounted) return;
        
        if (savedPath != null) {
          setState(() => _evidencePaths.add(savedPath));
          _showSnackBar('Evidence photo added');
        } else {
          _showSnackBar('Failed to save photo');
        }
      }
    } catch (e) {
      debugPrint('Evidence capture error: $e');
      if (!mounted) return;
      _showSnackBar('Error: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  /// Pick evidence from gallery
  Future<void> _pickEvidence() async {
    if (_isProcessing) return;
    
    setState(() => _isProcessing = true);
    
    try {
      final hasPermission = await _requestStoragePermission();
      
      if (!hasPermission) {
        if (!mounted) return;
        await _showPermissionDialog('Storage');
        return;
      }

      final picker = ImagePicker();
      final images = await picker.pickMultiImage(
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
      );
      
      if (!mounted) return;

      if (images.isNotEmpty) {
        for (final image in images) {
          final savedPath = await _saveImageToAppDirectory(image.path, 'evidence');
          if (savedPath != null) {
            setState(() => _evidencePaths.add(savedPath));
          }
        }
        if (mounted) {
          _showSnackBar('${images.length} photo(s) added');
        }
      }
    } catch (e) {
      debugPrint('Evidence pick error: $e');
      if (!mounted) return;
      _showSnackBar('Error: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  /// Save image to app directory
  Future<String?> _saveImageToAppDirectory(String sourcePath, String prefix) async {
    try {
      final sourceFile = File(sourcePath);
      
      if (!await sourceFile.exists()) {
        debugPrint('Source file does not exist');
        return null;
      }

      final appDir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${prefix}_$timestamp.jpg';
      final newPath = path.join(appDir.path, 'disputes', fileName);
      
      final newFile = File(newPath);
      await newFile.parent.create(recursive: true);
      await sourceFile.copy(newPath);
      
      final exists = await newFile.exists();
      if (!exists) return null;
      
      final size = await newFile.length();
      if (size == 0) {
        await newFile.delete();
        return null;
      }
      
      debugPrint('Image saved: $newPath (${size} bytes)');
      return newPath;
    } catch (e) {
      debugPrint('Error saving image: $e');
      return null;
    }
  }

  /// Remove evidence photo
  void _removeEvidence(int index) {
    setState(() {
      _evidencePaths.removeAt(index);
    });
  }

  /// Submit dispute
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    final user = ref.read(authProvider).user;
    if (user == null) {
      _showSnackBar('User not authenticated');
      return;
    }

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

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final disputeState = ref.watch(disputeProvider);
    final disputesAsync = ref.watch(disputesByBookingProvider(widget.bookingId));

    ref.listen<DisputeState>(disputeProvider, (previous, next) {
      if (next.error != null && next.error != previous?.error && mounted) {
        _showSnackBar(next.error!);
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Open Dispute'),
        centerTitle: true,
        elevation: 0,
      ),
      body: disputesAsync.when(
        data: (disputes) {
          final hasOpenDispute = disputes.any(
            (d) => d.status == 'open' || d.status == 'investigating',
          );

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasOpenDispute) ...[
                  _buildInfoCard(
                    theme,
                    'This booking already has an open dispute.',
                    Colors.amber,
                    Icons.warning_amber,
                  ),
                  const SizedBox(height: 16),
                ],
                
                _buildInfoCard(
                  theme,
                  'Tell us what went wrong and provide evidence if possible.',
                  theme.colorScheme.primary,
                  Icons.info_outline,
                ),
                
                const SizedBox(height: 24),
                
                Form(
                  key: _formKey,
                  child: TextFormField(
                    controller: _reasonController,
                    maxLines: 5,
                    decoration: InputDecoration(
                      labelText: 'Reason for Dispute',
                      hintText: 'Describe the issue in detail...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.report_problem_outlined),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please describe the issue';
                      }
                      if (value.trim().length < 10) {
                        return 'Please provide more details (at least 10 characters)';
                      }
                      return null;
                    },
                    enabled: !hasOpenDispute && !disputeState.isSubmitting,
                  ),
                ),
                
                const SizedBox(height: 24),
                
                Text(
                  'Evidence (Optional)',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                
                const SizedBox(height: 12),
                
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: hasOpenDispute || disputeState.isSubmitting || _isProcessing
                            ? null
                            : _captureEvidence,
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('Take Photo'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: hasOpenDispute || disputeState.isSubmitting || _isProcessing
                            ? null
                            : _pickEvidence,
                        icon: const Icon(Icons.photo_library),
                        label: const Text('From Gallery'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                if (_evidencePaths.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.photo, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              '${_evidencePaths.length} photo(s) attached',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _evidencePaths.asMap().entries.map((entry) {
                            final index = entry.key;
                            final path = entry.value;
                            
                            return Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.file(
                                    File(path),
                                    width: 100,
                                    height: 100,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        width: 100,
                                        height: 100,
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade300,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Icon(Icons.broken_image),
                                      );
                                    },
                                  ),
                                ),
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: GestureDetector(
                                    onTap: () => _removeEvidence(index),
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.6),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                
                if (_isProcessing)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
                
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: hasOpenDispute || disputeState.isSubmitting || _isProcessing
                        ? null
                        : _submit,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: disputeState.isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Submit Dispute',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error: $err'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  ref.invalidate(disputesByBookingProvider(widget.bookingId));
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(
    ThemeData theme,
    String text,
    Color color,
    IconData icon,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
