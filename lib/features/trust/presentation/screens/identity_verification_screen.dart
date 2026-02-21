// lib/features/trust/presentation/screens/identity_verification_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path;
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/trust_provider.dart';
import '../widgets/camera_screen.dart';

class IdentityVerificationScreen extends ConsumerStatefulWidget {
  const IdentityVerificationScreen({super.key});

  @override
  ConsumerState<IdentityVerificationScreen> createState() =>
      _IdentityVerificationScreenState();
}

class _IdentityVerificationScreenState
    extends ConsumerState<IdentityVerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _docTypes = const [
    'National ID',
    'Driver License',
    'Passport',
  ];

  String _selectedDocType = 'National ID';
  String? _docPath;
  String? _selfiePath;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadExistingVerification();
    });
  }

  void _loadExistingVerification() {
    if (!mounted) return;
    try {
      final user = ref.read(authProvider).user;
      if (user != null) {
        ref.read(identityVerificationProvider.notifier).loadLatest(user.id);
      }
    } catch (e) {
      debugPrint('Error loading verification: $e');
    }
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

  /// Pick document from gallery
  Future<void> _pickDocument() async {
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
      final XFile? file = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
      );

      if (!mounted) return;

      if (file != null) {
        final savedPath = await _saveImageToAppDirectory(file.path, 'document');
        
        if (!mounted) return;
        
        if (savedPath != null) {
          setState(() => _docPath = savedPath);
          _showSnackBar('Document uploaded successfully');
        } else {
          _showSnackBar('Failed to save document');
        }
      }
    } catch (e) {
      debugPrint('Document pick error: $e');
      if (!mounted) return;
      _showSnackBar('Error: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  /// Open in-app camera for document
  Future<void> _captureDocument() async {
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

      final String? imagePath = await Navigator.of(context).push<String>(
        MaterialPageRoute(
          builder: (context) => const CameraScreen(useFrontCamera: false),
        ),
      );

      if (!mounted) return;

      if (imagePath != null) {
        final savedPath = await _saveImageToAppDirectory(imagePath, 'document');
        
        if (!mounted) return;
        
        if (savedPath != null) {
          setState(() => _docPath = savedPath);
          _showSnackBar('Document captured successfully');
        } else {
          _showSnackBar('Failed to save document');
        }
      }
    } catch (e) {
      debugPrint('Document capture error: $e');
      if (!mounted) return;
      _showSnackBar('Error: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  /// Open in-app camera for selfie
  Future<void> _captureSelfie() async {
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

      final String? imagePath = await Navigator.of(context).push<String>(
        MaterialPageRoute(
          builder: (context) => const CameraScreen(useFrontCamera: true),
        ),
      );

      if (!mounted) return;

      if (imagePath != null) {
        final savedPath = await _saveImageToAppDirectory(imagePath, 'selfie');
        
        if (!mounted) return;
        
        if (savedPath != null) {
          setState(() => _selfiePath = savedPath);
          _showSnackBar('Selfie captured successfully');
        } else {
          _showSnackBar('Failed to save selfie');
        }
      }
    } catch (e) {
      debugPrint('Selfie capture error: $e');
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
      final newPath = path.join(appDir.path, 'verification', fileName);
      
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

  /// Submit verification
  Future<void> _submitVerification() async {
    if (!mounted) return;
    
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_docPath == null || _selfiePath == null) {
      _showSnackBar('Please upload both ID document and selfie');
      return;
    }

    try {
      final docExists = await File(_docPath!).exists();
      final selfieExists = await File(_selfiePath!).exists();

      if (!mounted) return;

      if (!docExists || !selfieExists) {
        _showSnackBar('One or more files are missing. Please re-upload.');
        setState(() {
          if (!docExists) _docPath = null;
          if (!selfieExists) _selfiePath = null;
        });
        return;
      }

      final user = ref.read(authProvider).user;
      if (user == null) {
        _showSnackBar('User not authenticated');
        return;
      }
      final supaUser = Supabase.instance.client.auth.currentUser;
      if (supaUser == null) {
        _showSnackBar('Session expired. Please sign in again.');
        return;
      }
      
      final success = await ref
          .read(identityVerificationProvider.notifier)
          .submit(
            userId: user.id,
            docType: _selectedDocType,
            docFilePath: _docPath!,
            selfieFilePath: _selfiePath!,
          );

      if (!mounted) return;

      if (success) {
        _showSnackBar('Verification submitted successfully');
        setState(() {
          _docPath = null;
          _selfiePath = null;
        });
        // Reload to show updated status
        _loadExistingVerification();
      }
    } catch (e) {
      debugPrint('Submit error: $e');
      if (!mounted) return;
      _showSnackBar('Failed to submit verification: ${e.toString()}');
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
    final colorScheme = theme.colorScheme;
    final state = ref.watch(identityVerificationProvider);
    final verification = state.verification;

    ref.listen<IdentityVerificationState>(
      identityVerificationProvider,
      (previous, next) {
        if (next.error != null && 
            next.error != previous?.error && 
            mounted) {
          _showSnackBar(next.error!);
        }
      },
    );

    final isPending = verification?.status == 'pending';
    final isVerified = verification?.status == 'verified';
    final isRejected = verification?.status == 'rejected';
    
    // ✅ Only allow editing if not verified and not pending
    final canEdit = !isVerified && !isPending && !state.isSubmitting && !_isProcessing;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Identity Verification'),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadExistingVerification,
            tooltip: 'Refresh status',
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ✅ Status Card - Always shown
              _buildStatusCard(
                theme: theme,
                colorScheme: colorScheme,
                status: verification?.status,
                rejectionReason: verification?.rejectionReason,
              ),
              
              // ✅ Show verified badge prominently
              if (isVerified) ...[
                const SizedBox(height: 24),
                _buildVerifiedBadge(theme, colorScheme),
              ],
              
              // ✅ Only show upload form if NOT verified
              if (!isVerified) ...[
                const SizedBox(height: 24),
                _buildInstructionsCard(theme, colorScheme),
                const SizedBox(height: 24),
                
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: _selectedDocType,
                        decoration: InputDecoration(
                          labelText: 'Document Type',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.badge_outlined),
                        ),
                        items: _docTypes
                            .map(
                              (type) => DropdownMenuItem(
                                value: type,
                                child: Text(type),
                              ),
                            )
                            .toList(),
                        onChanged: canEdit
                            ? (value) {
                                if (value != null) {
                                  setState(() => _selectedDocType = value);
                                }
                              }
                            : null,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please select a document type';
                          }
                          return null;
                        },
                      ),
                      
                      const SizedBox(height: 20),
                      
                      _buildImagePickerCard(
                        label: 'Government ID',
                        icon: Icons.credit_card,
                        imagePath: _docPath,
                        onCamera: canEdit ? _captureDocument : null,
                        onGallery: canEdit ? _pickDocument : null,
                        isProcessing: _isProcessing,
                        colorScheme: colorScheme,
                      ),
                      
                      const SizedBox(height: 16),
                      
                      _buildImagePickerCard(
                        label: 'Selfie Photo',
                        icon: Icons.face,
                        imagePath: _selfiePath,
                        onCamera: canEdit ? _captureSelfie : null,
                        onGallery: null,
                        isProcessing: _isProcessing,
                        colorScheme: colorScheme,
                      ),
                      
                      const SizedBox(height: 32),
                      
                      FilledButton(
                        onPressed: canEdit ? _submitVerification : null,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: state.isSubmitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                isRejected ? 'Resubmit Verification' : 'Submit Verification',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ],
              
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard({
    required ThemeData theme,
    required ColorScheme colorScheme,
    required String? status,
    String? rejectionReason,
  }) {
    Color color;
    IconData icon;
    String text;
    String description;

    switch (status) {
      case 'verified':
        color = Colors.green;
        icon = Icons.verified;
        text = 'Identity Verified ✓';
        description = 'Your identity has been successfully verified! You now have full access to all platform features.';
        break;
      case 'rejected':
        color = Colors.red;
        icon = Icons.cancel;
        text = 'Verification Rejected';
        description = 'Your verification was rejected. Please review the reason below and resubmit with corrected documents.';
        break;
      case 'pending':
        color = Colors.orange;
        icon = Icons.pending;
        text = 'Under Review';
        description = 'Your verification is being reviewed by our team. This typically takes 1-2 business days. We\'ll notify you once complete.';
        break;
      default:
        color = colorScheme.primary;
        icon = Icons.info_outline;
        text = 'Not Submitted';
        description = 'Complete identity verification to unlock all platform features and build trust with other users.';
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(0.15),
            color.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.4),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  text,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.8),
              height: 1.5,
            ),
          ),
          if (rejectionReason != null && rejectionReason.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.red.withOpacity(0.3),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Rejection Reason:',
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          rejectionReason,
                          style: TextStyle(
                            color: Colors.red[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInstructionsCard(ThemeData theme, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.primary.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.checklist,
                color: colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Requirements',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInstructionItem('Take a clear photo of your government-issued ID'),
          const SizedBox(height: 8),
          _buildInstructionItem('Capture a selfie with your face clearly visible'),
          const SizedBox(height: 8),
          _buildInstructionItem('Ensure all text on your ID is readable'),
          const SizedBox(height: 8),
          _buildInstructionItem('Make sure photos are well-lit and in focus'),
        ],
      ),
    );
  }

  Widget _buildInstructionItem(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('• ', style: TextStyle(fontSize: 16)),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildImagePickerCard({
    required String label,
    required IconData icon,
    required String? imagePath,
    required VoidCallback? onCamera,
    required VoidCallback? onGallery,
    required bool isProcessing,
    required ColorScheme colorScheme,
  }) {
    final hasImage = imagePath != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(
          color: hasImage ? Colors.green.withOpacity(0.5) : colorScheme.outline.withOpacity(0.3),
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(12),
        color: hasImage 
            ? Colors.green.withOpacity(0.05) 
            : colorScheme.surfaceContainerHighest.withOpacity(0.3),
      ),
      child: Column(
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: hasImage
                    ? Image.file(
                        File(imagePath),
                        width: 70,
                        height: 70,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return _buildImagePlaceholder(icon, colorScheme);
                        },
                      )
                    : _buildImagePlaceholder(icon, colorScheme),
              ),
              
              const SizedBox(width: 16),
              
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hasImage ? 'Image uploaded' : 'Tap button to capture',
                      style: TextStyle(
                        fontSize: 14,
                        color: hasImage ? Colors.green : colorScheme.onSurfaceVariant,
                        fontWeight: hasImage ? FontWeight.w500 : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
              
              if (isProcessing)
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (hasImage)
                const Icon(Icons.check_circle, color: Colors.green, size: 28),
            ],
          ),
          
          if (!hasImage && onCamera != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onCamera,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Camera'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                if (onGallery != null) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onGallery,
                      icon: const Icon(Icons.photo_library),
                      label: const Text('Gallery'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildImagePlaceholder(IconData icon, ColorScheme colorScheme) {
    return Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        icon,
        color: colorScheme.onSurfaceVariant,
        size: 32,
      ),
    );
  }

  Widget _buildVerifiedBadge(ThemeData theme, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.green.withOpacity(0.15),
            Colors.green.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.green.withOpacity(0.4),
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.verified, color: Colors.green, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Identity Verified',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'You have full access to all platform features',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.green.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}