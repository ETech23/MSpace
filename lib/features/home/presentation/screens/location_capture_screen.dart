import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/services/location_service.dart';

class LocationCaptureScreen extends ConsumerStatefulWidget {
  final String userId;
  final bool isArtisan;

  const LocationCaptureScreen({
    super.key,
    required this.userId,
    this.isArtisan = false,
  });

  @override
  ConsumerState<LocationCaptureScreen> createState() => _LocationCaptureScreenState();
}

class _LocationCaptureScreenState extends ConsumerState<LocationCaptureScreen> {
  final LocationService _locationService = LocationService();
  
  bool _isLoading = false;
  String? _locationStatus;
  Position? _currentPosition;
  String? _address;
  String? _city;
  String? _state;

  @override
  void initState() {
    super.initState();
    _detectLocation();
  }

  Future<void> _detectLocation() async {
    setState(() {
      _isLoading = true;
      _locationStatus = 'Detecting your location...';
    });

    try {
      final position = await _locationService.getCurrentLocation();
      
      if (position != null) {
        setState(() => _currentPosition = position);
        await _getAddressFromPosition(position);
        
        setState(() {
          _isLoading = false;
          _locationStatus = 'Location detected successfully!';
        });
      } else {
        setState(() {
          _isLoading = false;
          _locationStatus = 'Unable to detect location automatically';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _locationStatus = 'Error: ${e.toString()}';
      });
    }
  }

  Future<void> _getAddressFromPosition(Position position) async {
    try {
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        setState(() {
          _address = '${place.street ?? ''}, ${place.locality ?? ''}';
          _city = place.locality ?? place.administrativeArea;
          _state = place.administrativeArea;
        });
      }
    } catch (e) {
      print('Error getting address: $e');
    }
  }

  Future<void> _saveLocation() async {
    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please detect your location first')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;
      
      // Update users table
      await supabase.from('users').update({
        'latitude': _currentPosition!.latitude,
        'longitude': _currentPosition!.longitude,
        'address': _address ?? 'Not specified',
        'city': _city,
        'state': _state,
      }).eq('id', widget.userId);

      // If artisan, update artisan_profiles with PostGIS location
      if (widget.isArtisan) {
        await supabase.from('artisan_profiles').update({
          'location': 'POINT(${_currentPosition!.longitude} ${_currentPosition!.latitude})',
          'address': _address ?? 'Not specified',
        }).eq('user_id', widget.userId);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location saved successfully!')),
        );
        
        // Navigate to home
        context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving location: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _skipForNow() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Skip Location Setup?'),
        content: Text(
          widget.isArtisan
              ? 'Clients won\'t be able to find you easily without your location. You can add it later in settings.'
              : 'You can add your location later in settings to find artisans near you.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Skip'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Setup Your Location'),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Icon
            Icon(
              Icons.location_on,
              size: 80,
              color: colorScheme.primary,
            ),
            const SizedBox(height: 24),

            // Title
            Text(
              widget.isArtisan
                  ? 'Help Clients Find You'
                  : 'Find Artisans Near You',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            // Description
            Text(
              widget.isArtisan
                  ? 'Share your location so clients can discover your services nearby. This helps you get more job requests!'
                  : 'Share your location to see artisans near you and get faster service.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // Location Status Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: colorScheme.outline.withOpacity(0.2),
                ),
              ),
              child: Column(
                children: [
                  if (_isLoading)
                    const CircularProgressIndicator()
                  else if (_currentPosition != null)
                    const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 48,
                    )
                  else
                    Icon(
                      Icons.location_searching,
                      color: colorScheme.primary,
                      size: 48,
                    ),
                  const SizedBox(height: 16),

                  Text(
                    _locationStatus ?? 'Waiting...',
                    style: theme.textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),

                  if (_address != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _address!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],

                  if (_currentPosition != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Lat: ${_currentPosition!.latitude.toStringAsFixed(4)}, '
                      'Lng: ${_currentPosition!.longitude.toStringAsFixed(4)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Detect Again Button
            if (!_isLoading && _currentPosition == null)
              OutlinedButton.icon(
                onPressed: _detectLocation,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),

            if (_currentPosition != null) ...[
              // Save Location Button
              FilledButton.icon(
                onPressed: _isLoading ? null : _saveLocation,
                icon: const Icon(Icons.check),
                label: Text(_isLoading ? 'Saving...' : 'Save Location'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              const SizedBox(height: 12),

              // Re-detect Button
              OutlinedButton.icon(
                onPressed: _isLoading ? null : _detectLocation,
                icon: const Icon(Icons.refresh),
                label: const Text('Detect Again'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],

            const SizedBox(height: 12),

            // Skip Button
            TextButton(
              onPressed: _isLoading ? null : _skipForNow,
              child: const Text('Skip for now'),
            ),

            const SizedBox(height: 32),

            // Privacy Note
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.secondaryContainer.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.privacy_tip_outlined,
                    size: 20,
                    color: colorScheme.secondary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Your exact location is never shared. Only approximate distance is shown to others.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}