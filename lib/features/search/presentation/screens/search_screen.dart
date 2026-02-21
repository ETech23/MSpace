// lib/features/search/presentation/screens/search_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/search_provider.dart';
import '../widgets/search_result_card.dart';
import '../widgets/search_filter_sheet.dart';
import '../widgets/voice_search_button.dart';
import '../../data/services/voice_search_service.dart';
import '../../../../core/ads/ad_widgets.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen>
    with SingleTickerProviderStateMixin {
  late TextEditingController _searchController;
  late FocusNode _focusNode;
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _focusNode = FocusNode();

    _animController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    );
    _animController.forward();

    // Setup voice search
    voiceSearchService.onResult = _onVoiceResult;
    voiceSearchService.onStatusChanged = _onVoiceStatusChanged;
    voiceSearchService.onError = _onVoiceError;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    _animController.dispose();
    voiceSearchService.onResult = null;
    voiceSearchService.onStatusChanged = null;
    voiceSearchService.onError = null;
    super.dispose();
  }

  void _onSearchChanged(String value) {
    ref.read(searchProvider.notifier).updateQuery(value);
    if (value.trim().length >= 2) {
      ref.read(searchProvider.notifier).submitSearch(value.trim());
    } else if (value.trim().isEmpty) {
      ref.read(searchProvider.notifier).clearSearch();
    }
  }

  void _onSearchSubmitted(String value) {
    ref.read(searchProvider.notifier).submitSearch(value);
    _focusNode.unfocus();
  }

  void _onSuggestionTapped(SearchSuggestion suggestion) {
    setState(() {
      _searchController.text = suggestion.text;
      _searchController.selection = TextSelection.fromPosition(
        TextPosition(offset: suggestion.text.length),
      );
    });
    ref.read(searchProvider.notifier).submitSearch(suggestion.text);
    _focusNode.unfocus();
  }

  void _onRecentSearchTapped(String query) {
    setState(() {
      _searchController.text = query;
      _searchController.selection = TextSelection.fromPosition(
        TextPosition(offset: query.length),
      );
    });
    ref.read(searchProvider.notifier).submitSearch(query);
    _focusNode.unfocus();
  }

  void _clearSearch() {
    _searchController.clear();
    ref.read(searchProvider.notifier).clearSearch();
    _focusNode.requestFocus();
  }

  void _openFilters() {
    SearchFilterSheet.show(context);
  }

  void _onVoiceResult(String text, bool isFinal) {
    setState(() {
      _searchController.text = text;
    });
    if (isFinal && text.isNotEmpty) {
      ref.read(searchProvider.notifier).onVoiceResult(text);
    }
  }

  void _onVoiceStatusChanged(VoiceSearchStatus status) {
    ref.read(searchProvider.notifier).setListening(
      status == VoiceSearchStatus.listening,
    );
  }

  void _onVoiceError(String error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _startVoiceSearch() async {
    HapticFeedback.mediumImpact();
    await voiceSearchService.startListening();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    
    // Watch the search state - this will rebuild when state changes
    final searchState = ref.watch(searchProvider);
    
    // Debug logging
    debugPrint('🖼 Build: query="${searchState.query}", results=${searchState.results.length}, loading=${searchState.isLoading}');

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            children: [
              _buildSearchHeader(theme, cs, searchState),
              const BannerAdWidget(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
              ),
              Expanded(
                child: searchState.isSearching || searchState.query.isNotEmpty
                    ? _buildSearchContent(theme, cs, searchState)
                    : _buildDiscoveryView(theme, cs, searchState),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchHeader(ThemeData theme, ColorScheme cs, SearchState searchState) {
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 8, 8, 8),
      decoration: BoxDecoration(
        color: cs.surface,
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => context.pop(),
                icon: Icon(Icons.arrow_back, color: cs.onSurface),
              ),
              Expanded(
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 16),
                      Icon(Icons.search, color: cs.onSurfaceVariant, size: 22),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          focusNode: _focusNode,
                          onChanged: _onSearchChanged,
                          onSubmitted: _onSearchSubmitted,
                          textInputAction: TextInputAction.search,
                          style: theme.textTheme.bodyLarge?.copyWith(color: cs.onSurface),
                          decoration: InputDecoration(
                            hintText: 'Search artisans, services...',
                            hintStyle: theme.textTheme.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                      if (searchState.query.isNotEmpty)
                        IconButton(
                          onPressed: _clearSearch,
                          icon: Icon(Icons.close, color: cs.onSurfaceVariant),
                          iconSize: 20,
                        )
                      else
                        VoiceSearchButton(
                          isListening: searchState.isListening,
                          onPressed: _startVoiceSearch,
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Stack(
                children: [
                  IconButton(
                    onPressed: _openFilters,
                    icon: Icon(Icons.tune, color: cs.onSurface),
                  ),
                  if (searchState.filters.hasActiveFilters)
                    Positioned(
                      right: 8, top: 8,
                      child: Container(
                        width: 16, height: 16,
                        decoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle),
                        child: Center(
                          child: Text('${searchState.filters.activeFilterCount}',
                            style: TextStyle(color: cs.onPrimary, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          if (searchState.filters.hasActiveFilters)
            _buildActiveFilterChips(cs, searchState),
        ],
      ),
    );
  }

  Widget _buildActiveFilterChips(ColorScheme cs, SearchState searchState) {
    final filters = searchState.filters;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          if (filters.category != null)
            _buildFilterChip(filters.category!, () => 
              ref.read(searchProvider.notifier).updateFilters(filters.copyWith(clearCategory: true))),
          if (filters.minRating != null)
            _buildFilterChip('${filters.minRating}+ ★', () =>
              ref.read(searchProvider.notifier).updateFilters(filters.copyWith(clearRating: true))),
          if (filters.maxDistance != null)
            _buildFilterChip('≤${filters.maxDistance!.round()}km', () =>
              ref.read(searchProvider.notifier).updateFilters(filters.copyWith(clearDistance: true))),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, VoidCallback onRemove) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: InputChip(
        label: Text(label),
        onDeleted: onRemove,
        deleteIcon: const Icon(Icons.close, size: 16),
      ),
    );
  }

  Widget _buildDiscoveryView(ThemeData theme, ColorScheme cs, SearchState searchState) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Voice search hero
        _buildVoiceSearchHero(theme, cs),
        
        // Recent searches
        if (searchState.recentSearches.isNotEmpty) ...[
          const SizedBox(height: 24),
          _buildSectionHeader(theme, 'Recent Searches',
            onClear: () => ref.read(searchProvider.notifier).clearRecentSearches()),
          const SizedBox(height: 12),
          ...searchState.recentSearches.take(5).map((query) => ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.history, color: cs.onSurfaceVariant),
            title: Text(query),
            trailing: IconButton(
              icon: Icon(Icons.close, size: 18, color: cs.onSurfaceVariant),
              onPressed: () => ref.read(searchProvider.notifier).removeFromRecentSearches(query),
            ),
            onTap: () => _onRecentSearchTapped(query),
          )),
        ],
        
        // Popular searches
        const SizedBox(height: 24),
        _buildSectionHeader(theme, 'Popular Searches'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: searchState.popularSearches.map((q) => ActionChip(
            label: Text(q),
            avatar: const Icon(Icons.trending_up, size: 16),
            onPressed: () => _onRecentSearchTapped(q),
          )).toList(),
        ),
        
        const SizedBox(height: 32),
        _buildSearchTips(theme, cs),
      ],
    );
  }

  Widget _buildVoiceSearchHero(ThemeData theme, ColorScheme cs) {
    return GestureDetector(
      onTap: _startVoiceSearch,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [cs.primaryContainer.withOpacity(0.3), cs.secondaryContainer.withOpacity(0.2)],
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: cs.primary.withOpacity(0.15), shape: BoxShape.circle),
              child: Icon(Icons.mic, color: cs.primary, size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Try voice search', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('Say "Find a plumber near me"', style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: cs.onSurfaceVariant, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title, {VoidCallback? onClear}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
        if (onClear != null) TextButton(onPressed: onClear, child: const Text('Clear')),
      ],
    );
  }

  Widget _buildSearchTips(ThemeData theme, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tips_and_updates, color: cs.primary, size: 20),
              const SizedBox(width: 8),
              Text('Smart Search Tips', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 12),
          Text('• Typos are okay! "plomer" finds "plumber"', style: theme.textTheme.bodySmall),
          Text('• Search by location like "Owerri electrician"', style: theme.textTheme.bodySmall),
          Text('• Use skills like "AC repair" or "tiling"', style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _buildSearchContent(ThemeData theme, ColorScheme cs, SearchState searchState) {
    // Show loading
    if (searchState.isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Searching...'),
          ],
        ),
      );
    }

    // Show error
    if (searchState.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: cs.error),
            const SizedBox(height: 16),
            Text('Search failed', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(searchState.error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => ref.read(searchProvider.notifier).submitSearch(searchState.query),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    // Show empty state
    if (searchState.results.isEmpty && searchState.query.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.search_off, size: 80, color: cs.onSurfaceVariant.withOpacity(0.5)),
              const SizedBox(height: 16),
              Text('No results for "${searchState.query}"',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Text('Try different keywords or adjust filters',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
            ],
          ),
        ),
      );
    }

    // Show results
    return Column(
      children: [
        // Results count header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            children: [
              Text(
                '${searchState.results.length} result${searchState.results.length != 1 ? 's' : ''}'
                '${searchState.searchDurationMs > 0 ? ' (${searchState.searchDurationMs}ms)' : ''}',
                style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
        // Results list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: searchState.results.isEmpty
                ? 0
                : searchState.results.length +
                    (searchState.results.length / 2).floor(),
            itemBuilder: (context, index) {
              const adInterval = 2;
              final isAdIndex = (index + 1) % (adInterval + 1) == 0;
              if (isAdIndex) {
                return const NativeAdWidget();
              }

              final artisanIndex = index - (index ~/ (adInterval + 1));
              final artisan = searchState.results[artisanIndex];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SearchResultCard(
                  artisan: artisan,
                  searchQuery: searchState.query,
                  onTap: () {
                    ref.read(searchProvider.notifier).logResultClick(artisan.id);
                    context.push('/artisan/${artisan.userId}');
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
