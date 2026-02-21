// lib/features/profile/presentation/screens/edit_profile_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../profile/domain/entities/profile_update_entity.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../../profile/presentation/providers/artisan_profile_provider.dart';
import 'dart:io';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Basic Info Controllers
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  
  // Artisan-specific Controllers
  late TextEditingController _bioController;
  late TextEditingController _categoryController;
  late TextEditingController _experienceController;
  late TextEditingController _hourlyRateController;
  
  // Skills management
  final List<String> _skills = [];
  final TextEditingController _skillInputController = TextEditingController();
  
  // Certifications management
  final List<String> _certifications = [];
  final TextEditingController _certificationInputController = TextEditingController();

  String? _selectedImagePath;
  final ImagePicker _picker = ImagePicker();
  
  // Location
  double? _latitude;
  double? _longitude;
  bool _isLoadingLocation = false;
  
  // Availability
  bool _isAvailable = true;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    final user = ref.read(authProvider).user;
    
    // Basic fields
    _nameController = TextEditingController(text: user?.name ?? '');
    _phoneController = TextEditingController(text: user?.phone ?? '');
    _addressController = TextEditingController(text: user?.address ?? '');
    
    _latitude = user?.latitude;
    _longitude = user?.longitude;
    
    // Initialize artisan controllers
    _bioController = TextEditingController();
    _categoryController = TextEditingController();
    _experienceController = TextEditingController();
    _hourlyRateController = TextEditingController();
    
    // If artisan, load artisan profile data
    if (user?.isArtisan ?? false) {
      // Load artisan profile to get additional fields
      Future.microtask(() {
        final artisanProfileState = ref.read(artisanProfileProvider(user!.id));
        final artisanProfile = artisanProfileState.profile;
        
        if (artisanProfile != null && mounted) {
          setState(() {
            _bioController.text = artisanProfile.bio ?? '';
            _categoryController.text = artisanProfile.category;
            _experienceController.text = artisanProfile.experienceYears ?? '';
            _hourlyRateController.text = artisanProfile.hourlyRate?.toString() ?? '';
            _skills.addAll(artisanProfile.skills ?? []);
            _certifications.addAll(artisanProfile.certifications ?? []);
            _isAvailable = artisanProfile.isAvailable;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _bioController.dispose();
    _categoryController.dispose();
    _experienceController.dispose();
    _hourlyRateController.dispose();
    _skillInputController.dispose();
    _certificationInputController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedImagePath = image.path;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoadingLocation = true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw 'Location services are disabled';
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw 'Location permissions are denied';
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw 'Location permissions are permanently denied';
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _isLoadingLocation = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoadingLocation = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to get location: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _addSkill() {
    final skill = _skillInputController.text.trim();
    if (skill.isNotEmpty && !_skills.contains(skill)) {
      setState(() {
        _skills.add(skill);
        _skillInputController.clear();
      });
    }
  }

  void _removeSkill(String skill) {
    setState(() {
      _skills.remove(skill);
    });
  }

  void _addCertification() {
    final cert = _certificationInputController.text.trim();
    if (cert.isNotEmpty && !_certifications.contains(cert)) {
      setState(() {
        _certifications.add(cert);
        _certificationInputController.clear();
      });
    }
  }

  void _removeCertification(String cert) {
    setState(() {
      _certifications.remove(cert);
    });
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final user = ref.read(authProvider).user;
    if (user == null) return;

    // Upload photo first if selected
    String? photoUrl;
    if (_selectedImagePath != null) {
      photoUrl = await ref
          .read(profileProvider.notifier)
          .uploadProfilePhoto(user.id, _selectedImagePath!);
    }

    // Prepare basic profile updates
    final updates = ProfileUpdateEntity(
      name: _nameController.text.trim(),
      phone: _phoneController.text.trim().isEmpty 
          ? null 
          : _phoneController.text.trim(),
      address: _addressController.text.trim().isEmpty
          ? null
          : _addressController.text.trim(),
      photoUrl: photoUrl,
      latitude: _latitude,
      longitude: _longitude,
      bio: user.isArtisan ? _bioController.text.trim() : null,
    );

    // Update basic profile
    final updatedUser = await ref
        .read(profileProvider.notifier)
        .updateProfile(user.id, updates);

    if (updatedUser == null) {
      if (mounted) {
        final error = ref.read(profileProvider).error;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error ?? 'Failed to update profile'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // If artisan, update artisan-specific fields
    if (user.isArtisan) {
      final artisanUpdates = {
        'bio': _bioController.text.trim().isEmpty ? null : _bioController.text.trim(),
        'category': _categoryController.text.trim().isEmpty ? null : _categoryController.text.trim(),
        'experience_years': _experienceController.text.trim().isEmpty ? null : _experienceController.text.trim(),
        'hourly_rate': _hourlyRateController.text.trim().isEmpty 
            ? null 
            : double.tryParse(_hourlyRateController.text.trim()),
        'skills': _skills.isEmpty ? null : _skills,
        'certifications': _certifications.isEmpty ? null : _certifications,
        'availability_status': _isAvailable ? 'available' : 'unavailable',
      };

      final artisanSuccess = await ref
          .read(artisanProfileProvider(user.id).notifier)
          .updateArtisanProfile(artisanUpdates);

      if (!artisanSuccess && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated but some artisan details failed to save'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
    }

    if (mounted) {
      // Refresh auth state
      await ref.read(authProvider.notifier).refreshUser();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final user = ref.watch(authProvider).user;
    final profileState = ref.watch(profileProvider);
    final isArtisan = user?.isArtisan ?? false;
    
    // Watch artisan profile state if user is artisan
    final artisanProfileState = isArtisan 
        ? ref.watch(artisanProfileProvider(user!.id))
        : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: profileState.isLoading ? null : _saveProfile,
            child: profileState.isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    'Save',
                    style: TextStyle(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: artisanProfileState?.isLoading ?? false
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Picture Section
              Center(
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: colorScheme.primary,
                          width: 3,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 60,
                        backgroundColor: colorScheme.primaryContainer,
                        backgroundImage: _selectedImagePath != null
                            ? FileImage(File(_selectedImagePath!))
                            : (user?.photoUrl != null
                                ? NetworkImage(user!.photoUrl!)
                                : null) as ImageProvider?,
                        child: _selectedImagePath == null && user?.photoUrl == null
                            ? Icon(
                                Icons.person,
                                size: 60,
                                color: colorScheme.primary,
                              )
                            : null,
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: colorScheme.primary,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: colorScheme.surface,
                              width: 3,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.camera_alt,
                            size: 22,
                            color: colorScheme.onPrimary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Personal Information Section
              _buildSectionHeader('Personal Information', colorScheme, theme),
              const SizedBox(height: 16),

              // Name Field
              _buildTextField(
                controller: _nameController,
                label: 'Full Name *',
                icon: Icons.person_outline,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your name';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Email Field (Read-only)
              _buildTextField(
                controller: TextEditingController(text: user?.email ?? ''),
                label: 'Email',
                icon: Icons.email_outlined,
                enabled: false,
                readOnly: true,
              ),

              const SizedBox(height: 16),

              // Phone Field
              _buildTextField(
                controller: _phoneController,
                label: 'Phone Number',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
              ),

              const SizedBox(height: 16),

              // Address Field
              _buildTextField(
                controller: _addressController,
                label: 'Address',
                icon: Icons.location_on_outlined,
                maxLines: 2,
              ),

              const SizedBox(height: 16),

              // Location Coordinates
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: colorScheme.outline.withOpacity(0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.my_location,
                          size: 20,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Location Coordinates',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        if (_latitude != null && _longitude != null)
                          Icon(
                            Icons.check_circle,
                            size: 20,
                            color: Colors.green,
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_latitude != null && _longitude != null)
                      Text(
                        'Lat: ${_latitude!.toStringAsFixed(6)}\nLng: ${_longitude!.toStringAsFixed(6)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontFamily: 'monospace',
                        ),
                      )
                    else
                      Text(
                        'No location set',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _isLoadingLocation ? null : _getCurrentLocation,
                        icon: _isLoadingLocation
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.gps_fixed, size: 18),
                        label: Text(_isLoadingLocation 
                            ? 'Getting location...' 
                            : 'Update Location'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Artisan-specific fields
              if (isArtisan) ...[
                const SizedBox(height: 32),
                _buildSectionHeader('Professional Information', colorScheme, theme),
                const SizedBox(height: 16),

                // Bio
                _buildTextField(
                  controller: _bioController,
                  label: 'Professional Bio',
                  icon: Icons.info_outline,
                  maxLines: 4,
                  maxLength: 500,
                  hint: 'Tell clients about your expertise and experience...',
                ),

                const SizedBox(height: 16),

                // Category
                _buildTextField(
                  controller: _categoryController,
                  label: 'Category/Trade *',
                  icon: Icons.work_outline,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your trade/category';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // Experience Years
                _buildTextField(
                  controller: _experienceController,
                  label: 'Years of Experience',
                  icon: Icons.calendar_today,
                  hint: 'e.g., 5+ or 10',
                ),

                const SizedBox(height: 16),

                // Hourly Rate
                _buildTextField(
                  controller: _hourlyRateController,
                  label: 'Hourly Rate (₦)',
                  icon: Icons.attach_money,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                ),

                const SizedBox(height: 24),

                // Skills Section
                _buildListSection(
                  title: 'Skills',
                  items: _skills,
                  controller: _skillInputController,
                  onAdd: _addSkill,
                  onRemove: _removeSkill,
                  hint: 'Add a skill',
                  icon: Icons.build,
                  colorScheme: colorScheme,
                  theme: theme,
                ),

                const SizedBox(height: 24),

                // Certifications Section
                _buildListSection(
                  title: 'Certifications',
                  items: _certifications,
                  controller: _certificationInputController,
                  onAdd: _addCertification,
                  onRemove: _removeCertification,
                  hint: 'Add a certification',
                  icon: Icons.card_membership,
                  colorScheme: colorScheme,
                  theme: theme,
                ),

                const SizedBox(height: 24),

                // Availability Toggle
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _isAvailable 
                        ? Colors.green.withOpacity(0.1)
                        : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _isAvailable 
                          ? Colors.green.withOpacity(0.3)
                          : Colors.red.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isAvailable ? Icons.check_circle : Icons.cancel,
                        color: _isAvailable ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Availability Status',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              _isAvailable 
                                  ? 'You are available for bookings'
                                  : 'You are not accepting bookings',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _isAvailable,
                        onChanged: (value) {
                          setState(() {
                            _isAvailable = value;
                          });
                        },
                        activeThumbColor: Colors.green,
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 32),

              // Save Button
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: profileState.isLoading ? null : _saveProfile,
                  icon: profileState.isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save),
                  label: Text(
                    profileState.isLoading ? 'Saving...' : 'Save Changes',
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, ColorScheme colorScheme, ThemeData theme) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 24,
          decoration: BoxDecoration(
            color: colorScheme.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: colorScheme.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    int maxLines = 1,
    int? maxLength,
    bool enabled = true,
    bool readOnly = false,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        enabled: enabled,
      ),
      validator: validator,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      maxLines: maxLines,
      maxLength: maxLength,
      readOnly: readOnly,
    );
  }

  Widget _buildListSection({
    required String title,
    required List<String> items,
    required TextEditingController controller,
    required VoidCallback onAdd,
    required Function(String) onRemove,
    required String hint,
    required IconData icon,
    required ColorScheme colorScheme,
    required ThemeData theme,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: hint,
                  prefixIcon: Icon(icon),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                ),
                onSubmitted: (_) => onAdd(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              style: IconButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
            ),
          ],
        ),
        if (items.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: items.map((item) {
              return Chip(
                label: Text(item),
                deleteIcon: const Icon(Icons.close, size: 18),
                onDeleted: () => onRemove(item),
                backgroundColor: colorScheme.secondaryContainer,
                labelStyle: TextStyle(
                  color: colorScheme.onSecondaryContainer,
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}