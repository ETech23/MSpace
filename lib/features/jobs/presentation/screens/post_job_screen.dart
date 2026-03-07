// ================================================================
// POST JOB SCREEN (WITH PROPER FEEDBACK)
// lib/features/jobs/presentation/screens/post_job_screen.dart
// ================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/widgets/location_permission_nudge.dart';
import '../../data/models/job_model.dart';
import '../providers/job_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class PostJobScreen extends ConsumerStatefulWidget {
  const PostJobScreen({super.key});

  @override
  ConsumerState<PostJobScreen> createState() => _PostJobScreenState();
}

class _PostJobScreenState extends ConsumerState<PostJobScreen> {
  final _formKey = GlobalKey<FormState>();
  final LocationService _locationService = LocationService();

  String? _selectedCategory;
  final _categoryInputController = TextEditingController();
  final _descriptionController = TextEditingController();
  double? _budgetMin;
  double? _budgetMax;
  DateTime? _preferredDate;
  TimeOfDay? _preferredTime;
  bool _isUrgent = false;

  double? _latitude;
  double? _longitude;
  String? _address;
  bool _isLoadingLocation = false;
  bool _hasShownLocationSettingsNudge = false;

  final List<String> _categories = [
    'Plumber',
    'Electrician',
    'Carpenter',
    'Painter',
    'Mason',
    'Mechanic',
    'Cleaner',
    'General',
  ];

  @override
  void initState() {
    super.initState();
    _loadLocation();
  }

  @override
  void dispose() {
    _categoryInputController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadLocation() async {
    setState(() => _isLoadingLocation = true);

    try {
      final permission = await _locationService.checkPermissionStatus();
      if (permission == LocationPermission.denied) {
        final hasRequested = await _locationService.hasRequestedLocationPermission();
        if (!hasRequested && mounted) {
          final shouldRequest = await _showLocationPermissionRationaleDialog();
          if (shouldRequest == true) {
            final result = await _locationService.requestPermissionOnce();
            if (result != LocationPermission.always &&
                result != LocationPermission.whileInUse) {
              await _showLocationSettingsNudge();
              if (mounted) setState(() => _isLoadingLocation = false);
              return;
            }
          } else {
            if (mounted) setState(() => _isLoadingLocation = false);
            return;
          }
        } else {
          await _showLocationSettingsNudge();
          if (mounted) setState(() => _isLoadingLocation = false);
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        await _showLocationSettingsNudge();
        if (mounted) setState(() => _isLoadingLocation = false);
        return;
      }

      final position = await _locationService.getCurrentLocation();
      if (position != null && mounted) {
        setState(() {
          _latitude = position.latitude;
          _longitude = position.longitude;
        });

        try {
          final address = await _locationService.getAddressFromCoordinates(
            position.latitude,
            position.longitude,
          );
          
          if (mounted) {
            setState(() {
              _address = address ?? 'Location detected';
              _isLoadingLocation = false;
            });
          }
        } catch (e) {
          // Address fetch failed, but we have coordinates
          if (mounted) {
            setState(() {
              _address = 'Location detected';
              _isLoadingLocation = false;
            });
          }
        }
      } else if (mounted) {
        setState(() => _isLoadingLocation = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingLocation = false);
      }
    }
  }

  Future<bool?> _showLocationPermissionRationaleDialog() {
    return LocationPermissionNudge.showRationaleDialog(
      context,
      title: 'Allow location for job posting?',
      message:
          'We need your location to match your job request with nearby artisans.',
      primaryLabel: 'Allow location',
      secondaryLabel: 'Not now',
    );
  }

  Future<void> _showLocationSettingsNudge() async {
    if (!mounted || _hasShownLocationSettingsNudge) return;
    _hasShownLocationSettingsNudge = true;
    LocationPermissionNudge.showSettingsBanner(
      context,
      message:
          'Location access is off. Enable it in Settings to post location-based jobs.',
      onOpenSettings: _locationService.openAppSettings,
    );
  }

  // In post_job_screen.dart - Update _submitJob

Future<void> _submitJob() async {
  if (!_formKey.currentState!.validate()) return;

  final resolvedCategory = _resolveJobCategory();
  if (resolvedCategory == null) {
    _showError('Please select or type a service category');
    return;
  }
  
  if (_latitude == null || _longitude == null) {
    _showError('Location is required. Please enable location services.');
    return;
  }

  final user = ref.read(authProvider).user;
  if (user == null) {
    _showError('Please login to post a job');
    return;
  }

  String? timeStart;
  if (_preferredTime != null) {
    timeStart = '${_preferredTime!.hour.toString().padLeft(2, '0')}:${_preferredTime!.minute.toString().padLeft(2, '0')}';
  }

  final rawCategoryText = _categoryInputController.text.trim();
  final titleCategory =
      rawCategoryText.isNotEmpty ? rawCategoryText : resolvedCategory;
  final descriptionText = _buildSmartDescription(
    rawCategoryText: rawCategoryText,
    resolvedCategory: resolvedCategory,
    baseDescription: _descriptionController.text.trim(),
  );

  final form = JobFormModel(
    title: '$titleCategory Service',
    description: descriptionText,
    category: resolvedCategory,
    serviceQuery: rawCategoryText.isNotEmpty ? rawCategoryText : null,
    budgetMin: _budgetMin,
    budgetMax: _budgetMax,
    latitude: _latitude,
    longitude: _longitude,
    address: _address,
    preferredDate: _preferredDate,
    preferredTimeStart: timeStart,
    isUrgent: _isUrgent,
  );

  final job = await ref.read(jobProvider.notifier).postJob(form, user.id);

  if (job != null && mounted) {
    // ✅ WAIT for matching to complete (give it 3 seconds)
    await Future.delayed(const Duration(seconds: 3));
    
    // ✅ RELOAD job to get updated notified_artisan_count
    await ref.read(jobProvider.notifier).loadCustomerJobs(user.id);
    final updatedJob = ref.read(jobProvider).customerJobs
        .firstWhere((j) => j.id == job.id, orElse: () => job);
    
    if (mounted) {
      final openMyJobs = await _showSuccessDialog(updatedJob);
      if (!mounted) return;
      if (openMyJobs == true) {
        context.go('/my-jobs');
      } else {
        context.pop();
      }
    }
  } else if (mounted) {
    final error = ref.read(jobProvider).error;
    _showError(error ?? 'Failed to post job');
  }
}

String? _resolveJobCategory() {
  final typed = _categoryInputController.text.trim();
  if (_selectedCategory != null && _selectedCategory!.isNotEmpty) {
    return _selectedCategory;
  }
  if (typed.isEmpty) return null;
  return _mapToCanonicalCategory(typed);
}

String _buildSmartDescription({
  required String rawCategoryText,
  required String resolvedCategory,
  required String baseDescription,
}) {
  if (rawCategoryText.isEmpty) return baseDescription;
  if (rawCategoryText.toLowerCase() == resolvedCategory.toLowerCase()) {
    return baseDescription;
  }
  return 'Requested skill/category: $rawCategoryText\n$baseDescription';
}

String _mapToCanonicalCategory(String input) {
  final text = input.toLowerCase().trim();
  if (text.isEmpty) return 'General';

  final direct = _categories.firstWhere(
    (c) => c.toLowerCase() == text,
    orElse: () => '',
  );
  if (direct.isNotEmpty) return direct;

  const keywordMap = <String, List<String>>{
    'Plumber': ['plumb', 'pipe', 'leak', 'water', 'tap', 'toilet', 'drain', 'bathroom'],
    'Electrician': ['elect', 'wiring', 'socket', 'power', 'light', 'generator', 'inverter', 'circuit'],
    'Carpenter': ['carpent', 'wood', 'furniture', 'wardrobe', 'cabinet', 'shelf', 'door frame'],
    'Painter': ['paint', 'wall coating', 'interior', 'exterior', 'spray paint'],
    'Mason': ['mason', 'block', 'brick', 'concrete', 'tiling', 'tile', 'screed', 'plaster'],
    'Mechanic': ['mechanic', 'car', 'engine', 'vehicle', 'auto', 'brake', 'gearbox'],
    'Cleaner': ['clean', 'laundry', 'janitor', 'fumigation', 'wash', 'housekeeping'],
  };

  for (final entry in keywordMap.entries) {
    for (final keyword in entry.value) {
      if (text.contains(keyword)) return entry.key;
    }
  }

  return _toTitleCase(input);
}

String _toTitleCase(String value) {
  final words = value.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
  return words
      .map((w) => w.length == 1
          ? w.toUpperCase()
          : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
      .join(' ');
}

Future<bool?> _showSuccessDialog(JobModel job) async {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      icon: Icon(
        job.notifiedArtisanCount > 0 ? Icons.check_circle : Icons.info,
        color: job.notifiedArtisanCount > 0 ? Colors.green : Colors.orange,
        size: 64,
      ),
      title: Text(
        job.notifiedArtisanCount > 0 
            ? 'Job Posted Successfully!' 
            : 'Job Posted',
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            job.notifiedArtisanCount > 0
                ? '✅ ${job.notifiedArtisanCount} nearby artisans have been notified'
                : '⚠️ No artisans found within 20km',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: job.notifiedArtisanCount > 0 
                  ? Colors.green[700] 
                  : Colors.orange[700],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            job.notifiedArtisanCount > 0
                ? 'You\'ll receive a notification when someone accepts your job.'
                : 'We\'ll keep searching for available artisans in your area.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
      actions: [
        if (job.notifiedArtisanCount == 0)
          TextButton(
            onPressed: () {
              Navigator.pop(context, false);
              // TODO: Expand search radius
            },
            child: const Text('Search Wider Area'),
          ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('View My Jobs'),
        ),
      ],
    ),
  );
}

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isPosting = ref.watch(jobProvider).isPosting;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Post a Job'),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'What do you need help with?',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),

            // Category Selection
            Text(
              'Service Category',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _categories.map((category) {
                final isSelected = _selectedCategory == category;
                return ChoiceChip(
                  label: Text(category),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      _selectedCategory = selected ? category : null;
                      if (selected) {
                        _categoryInputController.text = category;
                      }
                    });
                  },
                  selectedColor: colorScheme.primaryContainer,
                  backgroundColor: colorScheme.surfaceContainerHighest,
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _categoryInputController,
              decoration: InputDecoration(
                labelText: 'Or type category/skill',
                hintText: 'e.g. pipe leakage, tiling, wiring',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest,
              ),
              onChanged: (value) {
                final typed = value.trim();
                if (typed.isEmpty) {
                  setState(() => _selectedCategory = null);
                  return;
                }
                final mapped = _mapToCanonicalCategory(typed);
                setState(() => _selectedCategory = mapped);
              },
            ),
            const SizedBox(height: 24),

            // Description
            Text(
              'Job Description',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descriptionController,
              maxLines: 4,
              maxLength: 300,
              decoration: InputDecoration(
                hintText: 'Describe what you need done...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please describe the job';
                }
                if (value.trim().length < 20) {
                  return 'Please provide more details (min 20 characters)';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // Location Display
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: colorScheme.primary.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.location_on, color: colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _isLoadingLocation
                        ? const Text('Detecting location...')
                        : Text(
                            _address ?? 'Location not available',
                            style: theme.textTheme.bodyMedium,
                          ),
                  ),
                  if (!_isLoadingLocation)
                    TextButton(
                      onPressed: _loadLocation,
                      child: const Text('Update'),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Budget (Optional)
            Text(
              'Budget (Optional)',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    decoration: InputDecoration(
                      labelText: 'Min (₦)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: colorScheme.surfaceContainerHighest,
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      _budgetMin = double.tryParse(value);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    decoration: InputDecoration(
                      labelText: 'Max (₦)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: colorScheme.surfaceContainerHighest,
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      _budgetMax = double.tryParse(value);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Preferred Date/Time
            Text(
              'When do you need this done?',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 90)),
                      );
                      if (date != null) {
                        setState(() => _preferredDate = date);
                      }
                    },
                    icon: const Icon(Icons.calendar_today),
                    label: Text(
                      _preferredDate == null
                          ? 'Select Date'
                          : '${_preferredDate!.day}/${_preferredDate!.month}/${_preferredDate!.year}',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.now(),
                      );
                      if (time != null) {
                        setState(() => _preferredTime = time);
                      }
                    },
                    icon: const Icon(Icons.access_time),
                    label: Text(
                      _preferredTime == null
                          ? 'Select Time'
                          : _preferredTime!.format(context),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Urgent Toggle
            SwitchListTile(
              value: _isUrgent,
              onChanged: (value) => setState(() => _isUrgent = value),
              title: const Text('This is urgent'),
              subtitle: const Text('Get priority notifications to artisans'),
              contentPadding: EdgeInsets.zero,
            ),

            const SizedBox(height: 32),

            // Submit Button
            FilledButton(
              onPressed: isPosting ? null : _submitJob,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: isPosting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Post Job',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
            
            const SizedBox(height: 16),
            
            Text(
              'Nearby artisans will be notified. You\'ll be contacted once someone accepts.',
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
