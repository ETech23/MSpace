// lib/features/booking/presentation/screens/create_booking_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../home/domain/entities/artisan_entity.dart';
import '../providers/booking_provider.dart';

class CreateBookingScreen extends ConsumerStatefulWidget {
  final ArtisanEntity artisan;

  const CreateBookingScreen({
    super.key,
    required this.artisan,
  });

  @override
  ConsumerState<CreateBookingScreen> createState() => _CreateBookingScreenState();
}

class _CreateBookingScreenState extends ConsumerState<CreateBookingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _serviceTypeController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _notesController = TextEditingController();
  final _estimatedPriceController = TextEditingController();

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  @override
  void initState() {
    super.initState();
    _serviceTypeController.text = widget.artisan.category;
  }

  @override
  void dispose() {
    _serviceTypeController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _notesController.dispose();
    _estimatedPriceController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _createBooking() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a preferred date')),
      );
      return;
    }

    if (_selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a preferred time')),
      );
      return;
    }

    final currentUser = ref.read(authProvider).user;
    if (currentUser == null) return;

    // Check if trying to book yourself
    if (currentUser.id == widget.artisan.userId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You cannot book yourself!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Combine date and time
    final scheduledDateTime = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );

    final estimatedPrice = double.tryParse(_estimatedPriceController.text);

    final success = await ref.read(bookingProvider.notifier).createBooking(
          customerId: currentUser.id,
          artisanId: widget.artisan.userId,
          artisanProfileId: widget.artisan.id,
          serviceType: _serviceTypeController.text,
          description: _descriptionController.text,
          preferredDate: scheduledDateTime,
          preferredTime: _selectedTime!.format(context),
          locationAddress: _locationController.text,
          locationLatitude: currentUser.latitude,
          locationLongitude: currentUser.longitude,
          estimatedPrice: estimatedPrice,
          customerNotes: _notesController.text.isEmpty ? null : _notesController.text,
        );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Booking request sent successfully!'),
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
    final bookingState = ref.watch(bookingProvider);

    // Show error if any
    ref.listen<BookingState>(bookingProvider, (previous, next) {
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: Colors.red,
          ),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Book Service'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Artisan info card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundImage: widget.artisan.photoUrl != null
                          ? NetworkImage(widget.artisan.photoUrl!)
                          : null,
                      child: widget.artisan.photoUrl == null
                          ? const Icon(Icons.person, size: 30)
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.artisan.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            widget.artisan.category,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          Row(
                            children: [
                              Icon(Icons.star, size: 16, color: Colors.amber[700]),
                              const SizedBox(width: 4),
                              Text(
                                '${widget.artisan.rating.toStringAsFixed(1)} (${widget.artisan.reviewCount})',
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Service Type
              TextFormField(
                controller: _serviceTypeController,
                decoration: const InputDecoration(
                  labelText: 'Service Type',
                  prefixIcon: Icon(Icons.build_outlined),
                  border: OutlineInputBorder(),
                  hintText: 'e.g., Plumbing, Electrical work',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter service type';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Description
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  prefixIcon: Icon(Icons.description_outlined),
                  border: OutlineInputBorder(),
                  hintText: 'Describe the work you need done',
                ),
                maxLines: 4,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please provide a description';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Date and Time
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: _selectDate,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Preferred Date',
                          prefixIcon: Icon(Icons.calendar_today),
                          border: OutlineInputBorder(),
                        ),
                        child: Text(
                          _selectedDate != null
                              ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                              : 'Select date',
                          style: TextStyle(
                            color: _selectedDate != null
                                ? null
                                : theme.textTheme.bodySmall?.color,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: InkWell(
                      onTap: _selectTime,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Preferred Time',
                          prefixIcon: Icon(Icons.access_time),
                          border: OutlineInputBorder(),
                        ),
                        child: Text(
                          _selectedTime != null
                              ? _selectedTime!.format(context)
                              : 'Select time',
                          style: TextStyle(
                            color: _selectedTime != null
                                ? null
                                : theme.textTheme.bodySmall?.color,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Location
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: 'Location Address',
                  prefixIcon: Icon(Icons.location_on_outlined),
                  border: OutlineInputBorder(),
                  hintText: 'Where should the artisan come?',
                ),
                maxLines: 2,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter location';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Estimated Price (optional)
              TextFormField(
                controller: _estimatedPriceController,
                decoration: const InputDecoration(
                  labelText: 'Budget (Optional)',
                  prefixIcon: Icon(Icons.attach_money),
                  border: OutlineInputBorder(),
                  hintText: 'Your budget for this service',
                  suffixText: 'NGN',
                ),
                keyboardType: TextInputType.number,
              ),

              const SizedBox(height: 16),

              // Additional Notes
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Additional Notes (Optional)',
                  prefixIcon: Icon(Icons.note_outlined),
                  border: OutlineInputBorder(),
                  hintText: 'Any special requirements or instructions',
                ),
                maxLines: 3,
              ),

              const SizedBox(height: 32),

              // Create Booking Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton.icon(
                  onPressed: bookingState.isCreating ? null : _createBooking,
                  icon: bookingState.isCreating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check),
                  label: Text(
                    bookingState.isCreating ? 'Creating...' : 'Send Booking Request',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}