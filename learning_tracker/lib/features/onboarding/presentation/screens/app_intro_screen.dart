import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

const kIntroSeen = 'intro_seen';

@RoutePage()
class AppIntroScreen extends StatefulWidget {
  const AppIntroScreen({super.key});

  @override
  State<AppIntroScreen> createState() => _AppIntroScreenState();
}

class _AppIntroScreenState extends State<AppIntroScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  late final AnimationController _iconController;

  final _pages = const <_IntroPageData>[
    _IntroPageData(
      icon: Icons.schedule_rounded,
      title: 'Your Daily\nTorah Plan',
      subtitle:
          'Learning Tracker turns massive goals into clear daily tasks, so you always know what to study next.',
      bgColor: AppTheme.brandBlueSoft,
      titleColor: AppTheme.brandInk,
      subtitleColor: AppTheme.brandInkMuted,
      iconColor: AppTheme.brandBlue,
      chipText: 'INTRO',
      showIllustration: false,
    ),
    _IntroPageData(
      icon: Icons.psychology_rounded,
      title: 'Never Forget\na Mishna',
      subtitle:
          'Master your learning with intelligent review cycles. Our spaced-repetition engine helps you retain everything you learn.',
      bgColor: AppTheme.brandBlueSoft,
      titleColor: AppTheme.brandInk,
      subtitleColor: AppTheme.brandInkMuted,
      iconColor: AppTheme.brandBlue,
      chipText: 'GOAL',
      showIllustration: false,
    ),
    _IntroPageData(
      icon: Icons.emoji_events_rounded,
      title: 'Earn While You\nLearn',
      subtitle:
          'Collect points, build streaks, and unlock mystery rewards as you climb from a Novice to a Master Scholar!',
      bgColor: AppTheme.brandBlueSoft,
      titleColor: AppTheme.brandInk,
      subtitleColor: AppTheme.brandInkMuted,
      iconColor: AppTheme.brandBlue,
      chipText: 'START',
      showIllustration: true,
      illustrationType: 'rewards',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _iconController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _iconController.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) {
    setState(() => _currentPage = page);
    _iconController
      ..reset()
      ..forward();
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
      );
    } else {
      _markIntroSeenAndContinue();
    }
  }

  void _skip() {
    _markIntroSeenAndContinue();
  }

  Future<void> _markIntroSeenAndContinue() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kIntroSeen, true);
    if (mounted) unawaited(context.router.replace(const SignInRoute()));
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _currentPage == _pages.length - 1;
    final pageData = _pages[_currentPage];

    return Scaffold(
      backgroundColor: AppTheme.brandCream,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.menu_book,
                        color: pageData.iconColor,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Aleph Bright',
                        style: GoogleFonts.plusJakartaSans(
                          color: AppTheme.brandBlue,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  if (!isLast)
                    TextButton(
                      onPressed: _skip,
                      child: Text(
                        'Skip',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppTheme.brandBlue.withValues(alpha: 0.7),
                        ),
                      ),
                    )
                  else
                    const SizedBox(width: 60),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  return _IntroPage(
                    data: _pages[index],
                    iconAnimation: _iconController,
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                children: [
                  if (_pages.length > 1)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 28),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_pages.length, (index) {
                          final isActive = index == _currentPage;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 350),
                            curve: Curves.easeOutCubic,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: isActive ? 32 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              color: isActive
                                  ? pageData.iconColor
                                  : AppTheme.brandOutline,
                            ),
                          );
                        }),
                      ),
                    ),
                  _GlowingButton(
                    onTap: _nextPage,
                    label: isLast ? 'Get Started →' : 'Continue Journey →',
                    bgColor: AppTheme.brandBlue,
                    showArrow: false,
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

class _IntroPageData {
  const _IntroPageData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.bgColor,
    required this.titleColor,
    required this.subtitleColor,
    required this.iconColor,
    required this.chipText,
    this.showIllustration = false,
    this.illustrationType = 'default',
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color bgColor;
  final Color titleColor;
  final Color subtitleColor;
  final Color iconColor;
  final String chipText;
  final bool showIllustration;
  final String illustrationType;
}

class _IntroPage extends StatelessWidget {
  const _IntroPage({required this.data, required this.iconAnimation});

  final _IntroPageData data;
  final Animation<double> iconAnimation;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Illustration area
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: _buildIllustration(),
                  ),
                  // Content area
                  Column(
                    children: [
                      AnimatedBuilder(
                        animation: iconAnimation,
                        builder: (context, _) {
                          final fade = CurvedAnimation(
                            parent: iconAnimation,
                            curve: const Interval(
                              0.3,
                              0.8,
                              curve: Curves.easeOut,
                            ),
                          ).value;
                          return Opacity(
                            opacity: fade,
                            child: Text(
                              data.title,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.plusJakartaSans(
                                color: data.titleColor,
                                fontSize: 36,
                                fontWeight: FontWeight.w800,
                                height: 1.2,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      AnimatedBuilder(
                        animation: iconAnimation,
                        builder: (context, _) {
                          final fade = CurvedAnimation(
                            parent: iconAnimation,
                            curve: const Interval(
                              0.4,
                              0.9,
                              curve: Curves.easeOut,
                            ),
                          ).value;
                          return Opacity(
                            opacity: fade,
                            child: Text(
                              data.subtitle,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.plusJakartaSans(
                                color: data.subtitleColor,
                                fontSize: 15,
                                height: 1.5,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildIllustration() {
    return AnimatedBuilder(
      animation: iconAnimation,
      builder: (context, _) {
        final scale = CurvedAnimation(
          parent: iconAnimation,
          curve: Curves.elasticOut,
        ).value;
        return Transform.scale(
          scale: 0.8 + (scale * 0.2),
          child: Container(
            width: 180,
            height: 260,
            decoration: BoxDecoration(
              color: AppTheme.brandBlue,
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.brandBlue.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (data.showIllustration && data.illustrationType == 'rewards')
                  _buildRewardsIllustration()
                else
                  _buildDefaultIllustration(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDefaultIllustration() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.15),
          ),
          child: Icon(data.icon, size: 54, color: Colors.white),
        ),
      ],
    );
  }

  Widget _buildRewardsIllustration() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Trophy icon at top
        Padding(
          padding: const EdgeInsets.only(top: 24),
          child: Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFFA500),
            ),
            child: const Icon(
              Icons.emoji_events_rounded,
              size: 50,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 24),
        // Badge Collection & Mystery Prizes cards
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.card_giftcard_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Badge\nCollection',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.card_giftcard_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Mystery\nPrizes',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Scholar level indicator
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Scholar Level',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'NOVICE',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    'Level 4',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'MASTER',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GlowingButton extends StatelessWidget {
  const _GlowingButton({
    required this.onTap,
    required this.label,
    required this.bgColor,
    this.showArrow = false,
  });

  final VoidCallback onTap;
  final String label;
  final Color bgColor;
  final bool showArrow;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          color: bgColor,
          boxShadow: [
            BoxShadow(
              color: bgColor.withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: AppTheme.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(28),
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.plusJakartaSans(
                      color: AppTheme.brandCreamCard,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (showArrow) ...[
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      color: AppTheme.brandCreamCard,
                      size: 20,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
