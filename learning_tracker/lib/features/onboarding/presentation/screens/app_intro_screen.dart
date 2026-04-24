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
      icon: Icons.menu_book_rounded,
      title: '9 Curricula, One App',
      subtitle:
          'From Biblical texts and Oral Law to Law Codes and Ethics. All your learning, sourced from Sefaria and available offline.',
      bgColor: AppTheme.brandBlueSoft,
      titleColor: AppTheme.brandInk,
      subtitleColor: AppTheme.brandInkMuted,
      iconColor: AppTheme.brandBlue,
      chipText: 'Intro 2: The Curricula',
    ),
    _IntroPageData(
      icon: Icons.update_rounded,
      title: 'Never Forget\na Mishna',
      subtitle:
          'Our intelligent chazara engine schedules reviews based on your pace. Spaced repetition ensures your learning stays with you forever.',
      bgColor: AppTheme.brandCreamSoft,
      titleColor: AppTheme.brandInk,
      subtitleColor: AppTheme.brandInkMuted,
      iconColor: AppTheme.brandBlueBright,
      chipText: 'Intro 3: Smart Review',
    ),
    _IntroPageData(
      icon: Icons.trending_up_rounded,
      title: 'Master Your\nLearning at Scale',
      subtitle:
          'Juggling Mishnah, Talmud, and Bible is hard. We turn large-scale learning goals into a clear daily plan tailored to you.',
      bgColor: AppTheme.brandGoldSoft,
      titleColor: AppTheme.brandInk,
      subtitleColor: AppTheme.brandInkMuted,
      iconColor: AppTheme.brandGoldDeep,
      chipText: 'Intro 1: Our Mission',
    ),
    _IntroPageData(
      icon: Icons.school_rounded,
      title: 'Designed for Every\nScholar',
      subtitle:
          'Choose Child Mode for a gamified journey with points and rewards, or Adult Mode for clean, scholarly progress tracking.',
      bgColor: AppTheme.brandCoralSoft,
      titleColor: AppTheme.brandInk,
      subtitleColor: AppTheme.brandInkMuted,
      iconColor: AppTheme.curriculumMussar,
      chipText: 'Intro 4: Your Mode',
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
    if (mounted) unawaited(context.router.replace(const WelcomeRoute()));
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
                  Row(
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
                  const SizedBox(height: 32),
                  _GlowingButton(
                    onTap: _nextPage,
                    label: isLast ? 'Get Started 🚀' : 'Next',
                    bgColor: AppTheme.brandBlueBright,
                    showArrow: !isLast,
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
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color bgColor;
  final Color titleColor;
  final Color subtitleColor;
  final Color iconColor;
  final String chipText;
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
          const SizedBox(height: 10),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: data.bgColor,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: AppTheme.brandCreamCard.withValues(alpha: 0.6),
                  width: 1.6,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.brandBlue.withValues(alpha: 0.08),
                    blurRadius: 26,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    flex: 2,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 18, 24, 12),
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppTheme.brandCreamCard.withValues(alpha: 0.78),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Stack(
                          children: [
                            Positioned(
                              top: 12,
                              right: 14,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: data.iconColor.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  data.chipText,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: data.iconColor,
                                  ),
                                ),
                              ),
                            ),
                            Center(
                              child: AnimatedBuilder(
                                animation: iconAnimation,
                                builder: (context, _) {
                                  final scale = CurvedAnimation(
                                    parent: iconAnimation,
                                    curve: Curves.elasticOut,
                                  ).value;
                                  return Transform.scale(
                                    scale: 0.7 + (scale * 0.3),
                                    child: Container(
                                      width: 116,
                                      height: 116,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            data.iconColor.withValues(
                                              alpha: 0.22,
                                            ),
                                            AppTheme.brandCreamCard,
                                          ],
                                        ),
                                        border: Border.all(
                                          color: data.iconColor.withValues(
                                            alpha: 0.22,
                                          ),
                                        ),
                                      ),
                                      child: Icon(
                                        data.icon,
                                        size: 56,
                                        color: data.iconColor,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(28, 2, 28, 18),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
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
                                    fontWeight: FontWeight.w700,
                                    height: 1.1,
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
                                    fontSize: 14,
                                    height: 1.45,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
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
