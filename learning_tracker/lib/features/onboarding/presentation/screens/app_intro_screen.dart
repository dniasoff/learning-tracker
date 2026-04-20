import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
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
      bgColor: Color(0xFFE8D7C3),
      titleColor: Color(0xFF2B2520),
      subtitleColor: Color(0xFF6B6159),
      iconColor: Color(0xFF4A5F8F),
    ),
    _IntroPageData(
      icon: Icons.update_rounded,
      title: 'Never Forget\na Mishna',
      subtitle:
          'Our intelligent chazara engine schedules reviews based on your pace. Spaced repetition ensures your learning stays with you forever.',
      bgColor: Color(0xFFD4E4F7),
      titleColor: Color(0xFF2B2520),
      subtitleColor: Color(0xFF6B6159),
      iconColor: Color(0xFF4A5F8F),
    ),
    _IntroPageData(
      icon: Icons.trending_up_rounded,
      title: 'Master Your\nLearning at Scale',
      subtitle:
          'Juggling Mishnah, Talmud, and Bible is hard. We turn large-scale learning goals into a clear daily plan tailored to you.',
      bgColor: Color(0xFFF5E6D3),
      titleColor: Color(0xFF2B2520),
      subtitleColor: Color(0xFF6B6159),
      iconColor: Color(0xFFC99B3D),
    ),
    _IntroPageData(
      icon: Icons.school_rounded,
      title: 'Designed for Every\nScholar',
      subtitle:
          'Choose Child Mode for a gamified journey with points and rewards, or Adult Mode for clean, scholarly progress tracking.',
      bgColor: Color(0xFFE6D4F0),
      titleColor: Color(0xFF2B2520),
      subtitleColor: Color(0xFF6B6159),
      iconColor: Color(0xFF8B6BA8),
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
      backgroundColor: const Color(0xFFF8F6F0),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Container(
                      key: ValueKey(_currentPage),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: pageData.iconColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: pageData.iconColor.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Text(
                        '${_currentPage + 1} of ${_pages.length}',
                        style: TextStyle(
                          color: pageData.iconColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  if (!isLast)
                    TextButton(
                      onPressed: _skip,
                      child: const Text(
                        'Skip',
                        style: TextStyle(
                          color: Color(0xFF999999),
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
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
                              : const Color(0xFFDDD9D0),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 32),
                  _GlowingButton(
                    onTap: _nextPage,
                    label: isLast ? 'Get Started 🚀' : 'Next',
                    bgColor: pageData.iconColor,
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
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color bgColor;
  final Color titleColor;
  final Color subtitleColor;
  final Color iconColor;
}

class _IntroPage extends StatelessWidget {
  const _IntroPage({required this.data, required this.iconAnimation});

  final _IntroPageData data;
  final Animation<double> iconAnimation;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: size.width * 0.06),
      child: Column(
        children: [
          SizedBox(height: size.height * 0.02),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: data.bgColor,
                borderRadius: BorderRadius.circular(32),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    flex: 2,
                    child: AnimatedBuilder(
                      animation: iconAnimation,
                      builder: (context, _) {
                        final scale = CurvedAnimation(
                          parent: iconAnimation,
                          curve: Curves.elasticOut,
                        ).value;
                        return Transform.scale(
                          scale: scale,
                          child: Icon(
                            data.icon,
                            size: 140,
                            color: data.iconColor,
                          ),
                        );
                      },
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 20,
                      ),
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
                                  style: GoogleFonts.playfairDisplay(
                                    color: data.titleColor,
                                    fontSize: 32,
                                    fontWeight: FontWeight.w700,
                                    height: 1.15,
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 16),
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
                                  style: GoogleFonts.inter(
                                    color: data.subtitleColor,
                                    fontSize: 14,
                                    height: 1.5,
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
          SizedBox(height: size.height * 0.02),
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
          color: Colors.transparent,
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
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (showArrow) ...[
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white,
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
