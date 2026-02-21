// lib/features/search/presentation/widgets/search_filter_sheet.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/search_provider.dart';

class SearchFilterSheet extends ConsumerStatefulWidget {
  const SearchFilterSheet({super.key});

  @override
  ConsumerState<SearchFilterSheet> createState() => _SearchFilterSheetState();

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const SearchFilterSheet(),
    );
  }
}

class _SearchFilterSheetState extends ConsumerState<SearchFilterSheet> {
  late SearchFilters _tempFilters;
  
  // Slider values
  double _ratingValue = 0;
  RangeValues _priceRange = const RangeValues(0, 50000);
  double _distanceValue = 50;

  @override
  void initState() {
    super.initState();
    final currentFilters = ref.read(searchProvider).filters;
    _tempFilters = currentFilters;
    _ratingValue = currentFilters.minRating ?? 0;
    _distanceValue = currentFilters.maxDistance ?? 50;
    _priceRange = RangeValues(
      currentFilters.minPrice ?? 0,
      currentFilters.maxPrice ?? 50000,
    );
  }

  void _applyFilters() {
    ref.read(searchProvider.notifier).updateFilters(_tempFilters.copyWith(
      minRating: _ratingValue > 0 ? _ratingValue : null,
      maxDistance: _distanceValue < 50 ? _distanceValue : null,
      minPrice: _priceRange.start > 0 ? _priceRange.start : null,
      maxPrice: _priceRange.end < 50000 ? _priceRange.end : null,
      clearRating: _ratingValue == 0,
      clearDistance: _distanceValue >= 50,
      clearPrice: _priceRange.start == 0 && _priceRange.end >= 50000,
    ));
    Navigator.pop(context);
  }

  void _clearFilters() {
    setState(() {
      _tempFilters = const SearchFilters();
      _ratingValue = 0;
      _priceRange = const RangeValues(0, 50000);
      _distanceValue = 50;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final searchState = ref.watch(searchProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.onSurfaceVariant.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Filters',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      )),
                    TextButton(
                      onPressed: _clearFilters,
                      child: const Text('Clear All'),
                    ),
                  ],
                ),
              ),
              
              const Divider(height: 1),
              
              // Filter content
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Category filter
                    _buildSectionTitle(theme, 'Category'),
                    const SizedBox(height: 12),
                    _buildCategoryChips(cs, searchState),
                    
                    const SizedBox(height: 24),
                    
                    // Rating filter
                    _buildSectionTitle(theme, 'Minimum Rating'),
                    const SizedBox(height: 8),
                    _buildRatingFilter(cs),
                    
                    const SizedBox(height: 24),
                    
                    // Distance filter
                    _buildSectionTitle(theme, 'Maximum Distance'),
                    const SizedBox(height: 8),
                    _buildDistanceFilter(cs),
                    
                    const SizedBox(height: 24),
                    
                    // Price range filter
                    _buildSectionTitle(theme, 'Hourly Rate Range'),
                    const SizedBox(height: 8),
                    _buildPriceFilter(cs),
                    
                    const SizedBox(height: 24),
                    
                    // Availability filter
                    _buildAvailabilityFilter(theme, cs),
                    
                    const SizedBox(height: 100), // Space for button
                  ],
                ),
              ),
              
              // Apply button
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cs.surface,
                  boxShadow: [
                    BoxShadow(
                      color: cs.shadow.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: Row(
                    children: [
                      // Active filter count
                      if (_getActiveFilterCount() > 0) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: cs.primaryContainer,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${_getActiveFilterCount()} active',
                            style: TextStyle(
                              color: cs.onPrimaryContainer,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: FilledButton(
                          onPressed: _applyFilters,
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text('Apply Filters'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionTitle(ThemeData theme, String title) {
    return Text(title,
      style: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
      ));
  }

  Widget _buildCategoryChips(ColorScheme cs, SearchState searchState) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: searchState.availableCategories.map((category) {
        final isSelected = _tempFilters.category == category;
        return FilterChip(
          label: Text(category),
          selected: isSelected,
          onSelected: (selected) {
            setState(() {
              _tempFilters = _tempFilters.copyWith(
                category: selected ? category : null,
                clearCategory: !selected,
              );
            });
          },
          avatar: Icon(_getCategoryIcon(category), size: 18),
          selectedColor: cs.primaryContainer,
          checkmarkColor: cs.onPrimaryContainer,
          showCheckmark: false,
        );
      }).toList(),
    );
  }

  Widget _buildRatingFilter(ColorScheme cs) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: List.generate(5, (i) {
                return Icon(
                  i < _ratingValue ? Icons.star : Icons.star_border,
                  color: i < _ratingValue ? Colors.amber : cs.onSurfaceVariant,
                  size: 24,
                );
              }),
            ),
            Text(
              _ratingValue > 0 ? '${_ratingValue.toStringAsFixed(1)}+' : 'Any',
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        Slider(
          value: _ratingValue,
          min: 0,
          max: 5,
          divisions: 10,
          label: _ratingValue > 0 ? _ratingValue.toStringAsFixed(1) : 'Any',
          onChanged: (v) => setState(() => _ratingValue = v),
        ),
      ],
    );
  }

  Widget _buildDistanceFilter(ColorScheme cs) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _distanceValue < 50
                  ? '${_distanceValue.round()} km'
                  : 'Any distance',
              style: TextStyle(
                color: cs.onSurface,
                fontWeight: FontWeight.w500,
                fontSize: 16,
              ),
            ),
            Icon(Icons.location_on, color: cs.primary),
          ],
        ),
        Slider(
          value: _distanceValue,
          min: 1,
          max: 50,
          divisions: 49,
          label: '${_distanceValue.round()} km',
          onChanged: (v) => setState(() => _distanceValue = v),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('1 km', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
            Text('50+ km', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
          ],
        ),
      ],
    );
  }

  Widget _buildPriceFilter(ColorScheme cs) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '₦${_priceRange.start.round().toString().replaceAllMapped(
                RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
                (m) => '${m[1]},',
              )}',
              style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w500),
            ),
            Text(
              _priceRange.end >= 50000
                  ? '₦50,000+'
                  : '₦${_priceRange.end.round().toString().replaceAllMapped(
                      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
                      (m) => '${m[1]},',
                    )}',
              style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        RangeSlider(
          values: _priceRange,
          min: 0,
          max: 50000,
          divisions: 100,
          labels: RangeLabels(
            '₦${_priceRange.start.round()}',
            '₦${_priceRange.end.round()}',
          ),
          onChanged: (v) => setState(() => _priceRange = v),
        ),
      ],
    );
  }

  Widget _buildAvailabilityFilter(ThemeData theme, ColorScheme cs) {
    return SwitchListTile(
      title: const Text('Available Now'),
      subtitle: Text(
        'Show only artisans currently available',
        style: TextStyle(color: cs.onSurfaceVariant),
      ),
      value: _tempFilters.isAvailable ?? false,
      onChanged: (v) {
        setState(() {
          _tempFilters = _tempFilters.copyWith(isAvailable: v ? true : null);
        });
      },
      secondary: Icon(
        Icons.access_time,
        color: _tempFilters.isAvailable == true ? cs.primary : cs.onSurfaceVariant,
      ),
      contentPadding: EdgeInsets.zero,
    );
  }

  int _getActiveFilterCount() {
    int count = 0;
    if (_tempFilters.category != null) count++;
    if (_ratingValue > 0) count++;
    if (_distanceValue < 50) count++;
    if (_priceRange.start > 0 || _priceRange.end < 50000) count++;
    if (_tempFilters.isAvailable == true) count++;
    return count;
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'plumber': return Icons.plumbing;
      case 'electrician': return Icons.electrical_services;
      case 'carpenter': return Icons.carpenter;
      case 'painter': return Icons.format_paint;
      case 'mechanic': return Icons.build;
      case 'tailor': return Icons.checkroom;
      case 'barber': return Icons.content_cut;
      case 'mason': return Icons.foundation;
      case 'welder': return Icons.construction;
      case 'ac repair': return Icons.ac_unit;
      case 'cleaner': return Icons.cleaning_services;
      case 'gardner': return Icons.grass;
      case 'driver': return Icons.drive_eta;
      case 'chef': return Icons.restaurant;
      case 'photographer': return Icons.camera_alt;
      default: return Icons.work;
    }
  }
}