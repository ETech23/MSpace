import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/services/onboarding_service.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // ── Skip Button ────────────────────────────────────────────────
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: TextButton(
                  onPressed: () async {
                    await OnboardingService.markOnboardingAsShown();
                    if (context.mounted) context.go('/login');
                  },
                  child: Text(
                    'Skip',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: colorScheme.primary,
                        ),
                  ),
                ),
              ),
            ),

            // ── Page View ──────────────────────────────────────────────────
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                children: [
                  _buildWelcomePage(theme, colorScheme, isDark),
                  _buildUserTypesOverviewPage(theme, colorScheme, isDark),
                  _buildArtisanPage(theme, colorScheme, isDark),
                  _buildBusinessPage(theme, colorScheme, isDark),
                  _buildCustomerPage(theme, colorScheme, isDark),
                ],
              ),
            ),

            // ── Page Indicators & Buttons ──────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      5,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        height: 8,
                        width: _currentPage == index ? 24 : 8,
                        decoration: BoxDecoration(
                          color: _currentPage == index
                              ? colorScheme.primary
                              : colorScheme.outlineVariant,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Buttons
                  Row(
                    children: [
                      if (_currentPage > 0) ...[
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              _pageController.previousPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOutCubic,
                              );
                            },
                            child: const Text('Back'),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: FilledButton(
                          onPressed: () async {
                            if (_currentPage < 4) {
                              _pageController.nextPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOutCubic,
                              );
                            } else {
                              // Mark onboarding as shown and navigate to login
                              await OnboardingService.markOnboardingAsShown();
                              if (context.mounted) {
                                context.go('/login');
                              }
                            }
                          },
                          child: Text(
                            _currentPage == 4 ? 'Get Started' : 'Next',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Page 1: Welcome ────────────────────────────────────────────────────
  Widget _buildWelcomePage(
      ThemeData theme, ColorScheme colorScheme, bool isDark) {
    return _PageContent(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Hero Icon
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colorScheme.primary,
                  colorScheme.primary.withOpacity(0.7),
                ],
              ),
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.primary.withOpacity(0.3),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Icon(
              Icons.workspace_premium_rounded,
              size: 60,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 32),

          // Heading
          Text(
            'Welcome to MSpace',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineLarge?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 16),

          // Subtitle
          Text(
            'Connect with skilled professionals and discover amazing services in your area',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.5,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 32),

          // Features
          _FeatureItem(
            icon: Icons.search_rounded,
            title: 'Discover',
            description: 'Find skilled artisans and services near you',
            colorScheme: colorScheme,
          ),
          const SizedBox(height: 16),
          _FeatureItem(
            icon: Icons.verified_user_rounded,
            title: 'Verified',
            description: 'Trusted professionals with verified ratings',
            colorScheme: colorScheme,
          ),
          const SizedBox(height: 16),
          _FeatureItem(
            icon: Icons.handshake_rounded,
            title: 'Easy Booking',
            description: 'Seamless communication and secure bookings',
            colorScheme: colorScheme,
          ),
        ],
      ),
    );
  }

  // ── Page 2: User Types Overview ────────────────────────────────────────
  Widget _buildUserTypesOverviewPage(
      ThemeData theme, ColorScheme colorScheme, bool isDark) {
    return _PageContent(
      child: Column(
        children: [
          Text(
            'Choose Your Role',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'The right account unlocks the best experience for you',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 32),
          _UserTypePreviewCard(
            icon: Icons.handyman_rounded,
            title: 'Artisan',
            description: 'Individual service provider',
            emoji: '🛠️',
            colorScheme: colorScheme,
            theme: theme,
          ),
          const SizedBox(height: 12),
          _UserTypePreviewCard(
            icon: Icons.store_mall_directory_rounded,
            title: 'Business',
            description: 'Team or company offering services',
            emoji: '🏢',
            colorScheme: colorScheme,
            theme: theme,
          ),
          const SizedBox(height: 12),
          _UserTypePreviewCard(
            icon: Icons.person_rounded,
            title: 'Customer',
            description: 'Looking for services and professionals',
            emoji: '👤',
            colorScheme: colorScheme,
            theme: theme,
          ),
        ],
      ),
    );
  }

  // ── Page 3: Artisan ────────────────────────────────────────────────────
  Widget _buildArtisanPage(
      ThemeData theme, ColorScheme colorScheme, bool isDark) {
    return _PageContent(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.handyman_rounded,
                  size: 28,
                  color: Colors.amber[700],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '🛠️  Artisan',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'Individual Service Provider',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          Text(
            'Perfect for you if you:',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          _BulletPoint(
            text: 'Offer a skilled service (plumbing, carpentry, tutoring, etc.)',
            colorScheme: colorScheme,
          ),
          _BulletPoint(
            text: 'Work independently or as a sole practitioner',
            colorScheme: colorScheme,
          ),
          _BulletPoint(
            text: 'Want to reach more customers in your area',
            colorScheme: colorScheme,
          ),
          _BulletPoint(
            text: 'Can manage bookings and communicate with clients',
            colorScheme: colorScheme,
          ),

          const SizedBox(height: 24),
          _InfoBox(
            title: 'Artisan Benefits',
            items: [
              'Build your professional profile and reputation',
              'Connect directly with clients who need your services',
              'Display your work and get customer reviews',
              'Manage your schedule and availability',
              'Track earnings and payments',
            ],
            icon: Icons.star_rounded,
            colorScheme: colorScheme,
            theme: theme,
          ),
        ],
      ),
    );
  }

  // ── Page 4: Business ───────────────────────────────────────────────────
  Widget _buildBusinessPage(
      ThemeData theme, ColorScheme colorScheme, bool isDark) {
    return _PageContent(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.store_mall_directory_rounded,
                  size: 28,
                  color: Colors.green[700],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '🏢  Business',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'Team or Company',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          Text(
            'Perfect for you if you:',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          _BulletPoint(
            text: 'Lead a team or company offering services',
            colorScheme: colorScheme,
          ),
          _BulletPoint(
            text: 'Manage multiple team members and locations',
            colorScheme: colorScheme,
          ),
          _BulletPoint(
            text: 'Want to showcase your business and services',
            colorScheme: colorScheme,
          ),
          _BulletPoint(
            text: 'Need advanced tools for team coordination',
            colorScheme: colorScheme,
          ),

          const SizedBox(height: 24),
          _InfoBox(
            title: 'Business Benefits',
            items: [
              'Showcase your entire team and service offerings',
              'Reach a wide customer base in your coverage area',
              'Manage multiple team members and appointments',
              'Build business credibility and customer trust',
              'Access business analytics and performance data',
            ],
            icon: Icons.trending_up_rounded,
            colorScheme: colorScheme,
            theme: theme,
          ),
        ],
      ),
    );
  }

  // ── Page 5: Customer ───────────────────────────────────────────────────
  Widget _buildCustomerPage(
      ThemeData theme, ColorScheme colorScheme, bool isDark) {
    return _PageContent(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.person_rounded,
                  size: 28,
                  color: Colors.blue[700],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '👤  Customer',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'Service Seeker',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          Text(
            'Perfect for you if you:',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          _BulletPoint(
            text: 'Need services like repairs, cleaning, or professional help',
            colorScheme: colorScheme,
          ),
          _BulletPoint(
            text: 'Want to discover trusted professionals near you',
            colorScheme: colorScheme,
          ),
          _BulletPoint(
            text: 'Prefer browsing and comparing services before booking',
            colorScheme: colorScheme,
          ),
          _BulletPoint(
            text: 'Want to communicate directly with service providers',
            colorScheme: colorScheme,
          ),

          const SizedBox(height: 24),
          _InfoBox(
            title: 'Customer Benefits',
            items: [
              'Browse verified artisans and service providers',
              'Read real customer reviews and ratings',
              'Get competitive pricing from different providers',
              'Easy communication and booking process',
              'Secure and transparent service transactions',
            ],
            icon: Icons.shopping_cart_rounded,
            colorScheme: colorScheme,
            theme: theme,
          ),
        ],
      ),
    );
  }
}

// ── Helper Widgets ──────────────────────────────────────────────────────

class _PageContent extends StatelessWidget {
  final Widget child;

  const _PageContent({required this.child});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: child,
    );
  }
}

class _FeatureItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final ColorScheme colorScheme;

  const _FeatureItem({
    required this.icon,
    required this.title,
    required this.description,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: colorScheme.primary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: 24,
            color: colorScheme.primary,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _UserTypePreviewCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String emoji;
  final ColorScheme colorScheme;
  final ThemeData theme;

  const _UserTypePreviewCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.emoji,
    required this.colorScheme,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outlineVariant,
          width: 1,
        ),
        color: colorScheme.surfaceContainerLow,
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: colorScheme.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: colorScheme.primary, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$emoji  $title',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.arrow_forward_rounded,
            color: colorScheme.outlineVariant,
            size: 20,
          ),
        ],
      ),
    );
  }
}

class _BulletPoint extends StatelessWidget {
  final String text;
  final ColorScheme colorScheme;

  const _BulletPoint({
    required this.text,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6, right: 12),
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: colorScheme.primary,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    height: 1.5,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  final String title;
  final List<String> items;
  final IconData icon;
  final ColorScheme colorScheme;
  final ThemeData theme;

  const _InfoBox({
    required this.title,
    required this.items,
    required this.icon,
    required this.colorScheme,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.primary.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 4, right: 8),
                      child: Icon(
                        Icons.check_circle_rounded,
                        size: 18,
                        color: colorScheme.primary,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        item,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
