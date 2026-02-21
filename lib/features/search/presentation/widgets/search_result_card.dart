// lib/features/search/presentation/widgets/search_result_card.dart

import 'package:flutter/material.dart';
import '../../../home/domain/entities/artisan_entity.dart';

class SearchResultCard extends StatelessWidget {
  final ArtisanEntity artisan;
  final VoidCallback onTap;
  final String searchQuery;

  const SearchResultCard({
    super.key,
    required this.artisan,
    required this.onTap,
    required this.searchQuery,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Card(
      elevation: 0,
      color: cs.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: cs.outlineVariant.withOpacity(0.3),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar with verification badge
              _buildAvatar(cs),
              const SizedBox(width: 12),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name row with match indicator
                    Row(
                      children: [
                        Expanded(
                          child: _HighlightedText(
                            text: artisan.name,
                            query: searchQuery,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: cs.onSurface,
                            ),
                          ),
                        ),
                        if (artisan.isVerified)
                          Container(
                            margin: const EdgeInsets.only(left: 4),
                            child: Icon(
                              Icons.verified,
                              size: 18,
                              color: cs.primary,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Category & Location
                    Row(
                      children: [
                        Icon(Icons.work_outline, size: 14, color: cs.primary),
                        const SizedBox(width: 4),
                        Flexible(
                          child: _HighlightedText(
                            text: artisan.category,
                            query: searchQuery,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        // Show city/address if available
                        if (_getLocationText() != null) ...[
                          Text(' • ', style: TextStyle(color: cs.onSurfaceVariant)),
                          Icon(Icons.location_on, size: 14, color: cs.onSurfaceVariant),
                          const SizedBox(width: 2),
                          Flexible(
                            child: _HighlightedText(
                              text: _getLocationText()!,
                              query: searchQuery,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Rating, reviews, distance row
                    _buildStatsRow(theme, cs),
                    const SizedBox(height: 8),

                    // Skills chips
                    if (artisan.skills != null && artisan.skills!.isNotEmpty)
                      _buildSkillsRow(theme, cs),

                    // Match type indicator
                    if (artisan.matchType != null && 
                        artisan.matchType != 'none' &&
                        artisan.matchType != 'category_match')
                      _buildMatchIndicator(cs),
                  ],
                ),
              ),

              // Price & arrow
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (artisan.hourlyRate != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: cs.primaryContainer.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '₦${_formatPrice(artisan.hourlyRate!)}/hr',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: cs.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Get location text to display (city or extracted from address)
  String? _getLocationText() {
    // First try displayCity getter
    if (artisan.displayCity != null && artisan.displayCity!.isNotEmpty) {
      return artisan.displayCity;
    }
    
    // Fallback to address
    if (artisan.address != null && artisan.address!.isNotEmpty) {
      // Return shortened address
      final parts = artisan.address!.split(',');
      if (parts.length > 1) {
        return parts.sublist(parts.length > 2 ? parts.length - 2 : 0).join(',').trim();
      }
      return artisan.address!.length > 25 
          ? '${artisan.address!.substring(0, 25)}...' 
          : artisan.address;
    }
    
    return null;
  }

  Widget _buildAvatar(ColorScheme cs) {
    return Hero(
      tag: 'artisan_avatar_${artisan.id}',
      child: Stack(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: cs.primaryContainer,
              image: artisan.photoUrl != null
                  ? DecorationImage(
                      image: NetworkImage(artisan.photoUrl!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: artisan.photoUrl == null
                ? Icon(Icons.person, size: 32, color: cs.primary)
                : null,
          ),
          // Availability indicator
          if (artisan.isAvailable)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                  border: Border.all(color: cs.surface, width: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(ThemeData theme, ColorScheme cs) {
    return Row(
      children: [
        // Rating
        if (artisan.rating > 0) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.star, size: 14, color: Colors.amber[700]),
                const SizedBox(width: 2),
                Text(
                  artisan.rating.toStringAsFixed(1),
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.amber[800],
                  ),
                ),
                if (artisan.reviewCount > 0) ...[
                  Text(
                    ' (${artisan.reviewCount})',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.amber[700],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
        ],

        // Distance
        if (artisan.distance != null) ...[
          Icon(Icons.near_me, size: 14, color: cs.onSurfaceVariant),
          const SizedBox(width: 2),
          Text(
            _formatDistance(artisan.distance!),
            style: theme.textTheme.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 8),
        ],

        // Experience
        if (artisan.experienceYears != null) ...[
          Icon(Icons.work_history, size: 14, color: cs.onSurfaceVariant),
          const SizedBox(width: 2),
          Text(
            '${artisan.experienceYears}y exp',
            style: theme.textTheme.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
        ],

        // Completed jobs
        if (artisan.completedJobs > 0 && artisan.experienceYears == null) ...[
          Icon(Icons.check_circle_outline, size: 14, color: cs.onSurfaceVariant),
          const SizedBox(width: 2),
          Text(
            '${artisan.completedJobs} jobs',
            style: theme.textTheme.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSkillsRow(ThemeData theme, ColorScheme cs) {
    final queryLower = searchQuery.toLowerCase();
    final matchingSkills = artisan.skills!
        .where((s) => s.toLowerCase().contains(queryLower))
        .toList();
    final otherSkills = artisan.skills!
        .where((s) => !s.toLowerCase().contains(queryLower))
        .toList();

    // Show matching skills first, then others
    final orderedSkills = [...matchingSkills, ...otherSkills].take(4);

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: orderedSkills.map((skill) {
        final isMatch = skill.toLowerCase().contains(queryLower);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isMatch
                ? cs.primaryContainer.withOpacity(0.7)
                : cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
            border: isMatch
                ? Border.all(color: cs.primary.withOpacity(0.3))
                : null,
          ),
          child: Text(
            skill,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isMatch ? FontWeight.w600 : FontWeight.normal,
              color: isMatch ? cs.primary : cs.onSurfaceVariant,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMatchIndicator(ColorScheme cs) {
    final matchLabel = _getMatchLabel(artisan.matchType);
    if (matchLabel == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(Icons.auto_awesome, size: 12, color: cs.tertiary),
          const SizedBox(width: 4),
          Text(
            matchLabel,
            style: TextStyle(
              fontSize: 10,
              color: cs.tertiary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  String? _getMatchLabel(String? matchType) {
    switch (matchType) {
      case 'name_match':
        return 'Matched by name';
      case 'skill_match':
        return 'Matched by skill';
      case 'location_match':
        return 'Matched by location';
      case 'bio_match':
        return 'Matched by description';
      default:
        return null;
    }
  }

  String _formatDistance(double km) {
    if (km < 1) {
      return '${(km * 1000).round()}m away';
    }
    return '${km.toStringAsFixed(1)}km away';
  }

  String _formatPrice(double price) {
    if (price >= 1000) {
      return '${(price / 1000).toStringAsFixed(price % 1000 == 0 ? 0 : 1)}k';
    }
    return price.toStringAsFixed(0);
  }
}

// Highlighted text widget with query matching
class _HighlightedText extends StatelessWidget {
  final String text;
  final String query;
  final TextStyle? style;

  const _HighlightedText({
    required this.text,
    required this.query,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    
    if (query.isEmpty || query.length < 2) {
      return Text(text, style: style, maxLines: 1, overflow: TextOverflow.ellipsis);
    }

    final matches = <_Match>[];
    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();

    // Find all matches
    int start = 0;
    while (true) {
      final index = lowerText.indexOf(lowerQuery, start);
      if (index == -1) break;
      matches.add(_Match(index, index + query.length));
      start = index + 1;
    }

    if (matches.isEmpty) {
      return Text(text, style: style, maxLines: 1, overflow: TextOverflow.ellipsis);
    }

    final spans = <TextSpan>[];
    int lastEnd = 0;

    for (final match in matches) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, match.start)));
      }
      spans.add(TextSpan(
        text: text.substring(match.start, match.end),
        style: TextStyle(
          backgroundColor: cs.primaryContainer,
          fontWeight: FontWeight.w700,
          color: cs.onPrimaryContainer,
        ),
      ));
      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd)));
    }

    return RichText(
      text: TextSpan(style: style, children: spans),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _Match {
  final int start;
  final int end;
  _Match(this.start, this.end);
}