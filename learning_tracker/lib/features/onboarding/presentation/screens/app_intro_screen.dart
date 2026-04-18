import 'dart:async';
import 'dart:math';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persistent flag — once set, intro slides are never shown again on this device.
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

  late final AnimationController _particleController;
  late final AnimationController _pulseController;
  late final AnimationController _iconController;

  static const _gold = AppTheme.heritageGold;
  static const _goldSoft = Color(0xFFE0C27A);
  final _pages = const <_IntroPageData>[
    _IntroPageData(
      icon: Icons.auto_stories_rounded,
      secondaryIcon: Icons.menu_book_rounded,
      title: 'Your Torah\nLearning Journey',
      subtitle:
          'Track every daf, perek, and halacha across all major '
          'Torah curricula — Mishnayos, Bavli, Yerushalmi, and more.',
      gradientColors: [AppTheme.heritageGoldMuted, AppTheme.heritageGold],
      accentColor: AppTheme.heritageGold,
    ),
    _IntroPageData(
      icon: Icons.insights_rounded,
      secondaryIcon: Icons.trending_up_rounded,
      title: 'Smart Progress\nTracking',
      subtitle:
          'Visualize your learning with beautiful charts, streak '
          'tracking, and milestone celebrations as you grow.',
      gradientColors: [AppTheme.heritageGoldMuted, AppTheme.heritageGold],
      accentColor: AppTheme.heritageGold,
    ),
    _IntroPageData(
      icon: Icons.schedule_rounded,
      secondaryIcon: Icons.notifications_active_rounded,
      title: 'Pace-Based\nGoals & Reminders',
      subtitle:
          'Set personalized learning goals, get daily reminders, '
          'and stay on pace to complete your learning on time.',
      gradientColors: [AppTheme.heritageGold, AppTheme.heritageGoldSoft],
      accentColor: AppTheme.heritageGoldSoft,
    ),
    _IntroPageData(
      icon: Icons.people_rounded,
      secondaryIcon: Icons.emoji_events_rounded,
      title: 'Learn Together,\nGrow Together',
      subtitle:
          'Whether you learn alone, with a chavrusa, or in a class — '
          'track personal, school, and tutor assignments all in one place.',
      gradientColors: [AppTheme.heritageGoldMuted, AppTheme.heritageGold],
      accentColor: AppTheme.heritageGold,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _iconController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _particleController.dispose();
    _pulseController.dispose();
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
      backgroundColor: AppTheme.heritageNavy,
      body: Stack(
        children: [
          // Animated particle background
          AnimatedBuilder(
            animation: _particleController,
            builder: (context, _) => CustomPaint(
              size: MediaQuery.of(context).size,
              painter: _ParticlePainter(
                progress: _particleController.value,
                color: pageData.accentColor,
              ),
            ),
          ),

          // Top gradient orb
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, _) {
              final pulse = 0.4 + _pulseController.value * 0.2;
              return Positioned(
                top: -120,
                right: -80,
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        pageData.accentColor.withValues(alpha: pulse * 0.15),
                        pageData.accentColor.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),

          // Content
          SafeArea(
            child: Column(
              children: [
                // Top bar with skip button and page indicator
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Animated step counter
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Container(
                          key: ValueKey(_currentPage),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: pageData.accentColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: pageData.accentColor.withValues(
                                alpha: 0.2,
                              ),
                            ),
                          ),
                          child: Text(
                            '${_currentPage + 1} / ${_pages.length}',
                            style: TextStyle(
                              color: pageData.accentColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      if (!isLast)
                        TextButton(
                          onPressed: _skip,
                          child: Text(
                            'Skip',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
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

                // Page content
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: _onPageChanged,
                    itemCount: _pages.length,
                    itemBuilder: (context, index) {
                      return _IntroPage(
                        data: _pages[index],
                        isActive: index == _currentPage,
                        iconAnimation: _iconController,
                        pulseAnimation: _pulseController,
                      );
                    },
                  ),
                ),

                // Bottom section
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                  child: Column(
                    children: [
                      // Page dots
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
                              gradient: isActive
                                  ? LinearGradient(
                                      colors: pageData.gradientColors,
                                    )
                                  : null,
                              color: isActive
                                  ? null
                                  : Colors.white.withValues(alpha: 0.15),
                              boxShadow: isActive
                                  ? [
                                      BoxShadow(
                                        color: pageData.accentColor.withValues(
                                          alpha: 0.4,
                                        ),
                                        blurRadius: 8,
                                      ),
                                    ]
                                  : null,
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 32),

                      // Continue / Get Started button
                      _GlowingButton(
                        onTap: _nextPage,
                        label: isLast ? 'Get Started' : 'Continue',
                        gradientColors: isLast
                            ? const [_gold, _goldSoft]
                            : pageData.gradientColors,
                        glowColor: pageData.accentColor,
                        showArrow: !isLast,
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// -- Data model --

class _IntroPageData {
  const _IntroPageData({
    required this.icon,
    required this.secondaryIcon,
    required this.title,
    required this.subtitle,
    required this.gradientColors,
    required this.accentColor,
  });

  final IconData icon;
  final IconData secondaryIcon;
  final String title;
  final String subtitle;
  final List<Color> gradientColors;
  final Color accentColor;
}

// -- Single intro page --

class _IntroPage extends StatelessWidget {
  const _IntroPage({
    required this.data,
    required this.isActive,
    required this.iconAnimation,
    required this.pulseAnimation,
  });

  final _IntroPageData data;
  final bool isActive;
  final Animation<double> iconAnimation;
  final Animation<double> pulseAnimation;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          const Spacer(flex: 1),

          // Animated illustration area
          AnimatedBuilder(
            animation: Listenable.merge([iconAnimation, pulseAnimation]),
            builder: (context, _) {
              final iconScale = CurvedAnimation(
                parent: iconAnimation,
                curve: Curves.easeOutBack,
              ).value;
              final pulse = pulseAnimation.value;

              return SizedBox(
                height: 240,
                width: 240,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer rotating ring
                    Transform.rotate(
                      angle: pulseAnimation.value * pi * 0.1,
                      child: Container(
                        width: 220 + pulse * 10,
                        height: 220 + pulse * 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: data.accentColor.withValues(
                              alpha: 0.06 + pulse * 0.04,
                            ),
                            width: 1,
                          ),
                        ),
                      ),
                    ),

                    // Middle ring with dashed effect
                    Transform.rotate(
                      angle: -pulseAnimation.value * pi * 0.05,
                      child: Container(
                        width: 180 + pulse * 6,
                        height: 180 + pulse * 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: data.accentColor.withValues(
                              alpha: 0.08 + pulse * 0.05,
                            ),
                            width: 1,
                          ),
                        ),
                      ),
                    ),

                    // Glow background
                    Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            data.accentColor.withValues(
                              alpha: 0.12 + pulse * 0.06,
                            ),
                            data.accentColor.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),

                    // Inner circle with icon
                    Transform.scale(
                      scale: iconScale,
                      child: Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              data.gradientColors[0].withValues(alpha: 0.15),
                              data.gradientColors[1].withValues(alpha: 0.08),
                            ],
                          ),
                          border: Border.all(
                            color: data.accentColor.withValues(alpha: 0.25),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: data.accentColor.withValues(alpha: 0.2),
                              blurRadius: 30,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Icon(
                          data.icon,
                          size: 48,
                          color: data.accentColor,
                        ),
                      ),
                    ),

                    // Floating secondary icon (top-right)
                    Positioned(
                      top: 20,
                      right: 20,
                      child: Transform.scale(
                        scale: iconScale * 0.9,
                        child: Transform.translate(
                          offset: Offset(0, sin(pulse * pi) * 6),
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: AppTheme.heritageNavyCard,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: data.accentColor.withValues(alpha: 0.15),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: data.accentColor.withValues(
                                    alpha: 0.1,
                                  ),
                                  blurRadius: 12,
                                ),
                              ],
                            ),
                            child: Icon(
                              data.secondaryIcon,
                              size: 22,
                              color: data.accentColor.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Floating accent dot (bottom-left)
                    Positioned(
                      bottom: 30,
                      left: 15,
                      child: Transform.translate(
                        offset: Offset(
                          sin(pulse * pi * 1.5) * 4,
                          cos(pulse * pi) * 5,
                        ),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: data.gradientColors,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: data.accentColor.withValues(alpha: 0.3),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.star_rounded,
                            size: 18,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          const Spacer(flex: 1),

          // Title
          AnimatedBuilder(
            animation: iconAnimation,
            builder: (context, _) {
              final fade = CurvedAnimation(
                parent: iconAnimation,
                curve: const Interval(0.2, 0.8, curve: Curves.easeOut),
              ).value;
              final slide = Tween<double>(begin: 30, end: 0)
                  .animate(
                    CurvedAnimation(
                      parent: iconAnimation,
                      curve: const Interval(
                        0.2,
                        0.8,
                        curve: Curves.easeOutCubic,
                      ),
                    ),
                  )
                  .value;

              return Transform.translate(
                offset: Offset(0, slide),
                child: Opacity(
                  opacity: fade,
                  child: Column(
                    children: [
                      Text(
                        data.title,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.playfairDisplay(
                          color: AppTheme.heritageInk,
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          height: 1.15,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        data.subtitle,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          color: AppTheme.heritageInkMuted,
                          fontSize: 15,
                          height: 1.6,
                          letterSpacing: 0.1,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          const Spacer(flex: 2),
        ],
      ),
    );
  }
}

// -- Glowing CTA button --

class _GlowingButton extends StatefulWidget {
  const _GlowingButton({
    required this.onTap,
    required this.label,
    required this.gradientColors,
    required this.glowColor,
    this.showArrow = false,
  });

  final VoidCallback onTap;
  final String label;
  final List<Color> gradientColors;
  final Color glowColor;
  final bool showArrow;

  @override
  State<_GlowingButton> createState() => _GlowingButtonState();
}

class _GlowingButtonState extends State<_GlowingButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glowController,
      builder: (context, _) {
        final glow = 0.25 + _glowController.value * 0.25;
        return Container(
          height: 58,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(29),
            gradient: LinearGradient(colors: widget.gradientColors),
            boxShadow: [
              BoxShadow(
                color: widget.glowColor.withValues(alpha: glow),
                blurRadius: 24,
                offset: const Offset(0, 8),
                spreadRadius: -4,
              ),
              BoxShadow(
                color: widget.glowColor.withValues(alpha: glow * 0.3),
                blurRadius: 40,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(29),
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.label,
                      style: GoogleFonts.inter(
                        color: AppTheme.heritageNavy,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                    if (widget.showArrow) ...[
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        color: AppTheme.heritageNavy,
                        size: 20,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// -- Particle painter for floating dots --

class _ParticlePainter extends CustomPainter {
  _ParticlePainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final random = Random(42);

    for (var i = 0; i < 30; i++) {
      final baseX = random.nextDouble() * size.width;
      final baseY = random.nextDouble() * size.height;
      final speed = 0.3 + random.nextDouble() * 0.7;
      final phase = random.nextDouble() * 2 * pi;

      final x = baseX + sin(progress * 2 * pi * speed + phase) * 20;
      final y = baseY + cos(progress * 2 * pi * speed * 0.7 + phase) * 15;

      final radius = 1.0 + random.nextDouble() * 2.0;
      final alpha =
          (0.08 + random.nextDouble() * 0.12) *
          (0.5 + sin(progress * 2 * pi + phase) * 0.5);

      canvas.drawCircle(
        Offset(x, y),
        radius,
        Paint()..color = color.withValues(alpha: alpha),
      );
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
