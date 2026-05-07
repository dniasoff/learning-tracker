import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:learning_tracker/core/constants/hebrew_terms.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/features/settings/presentation/providers/hebrew_terms_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const kIntroSeen = 'intro_seen';

/// Onboarding intro palette (design mockup).
const _kNavy = Color(0xFF1A36A5);
const _kGreen = Color(0xFF1DB97D);
const _kCoral = Color(0xFFF86B6B);
const _kPeach = Color(0xFFFFD8C8);
const _kGoldTrophy = Color(0xFFFFC94A);
const _kBg = Color(0xFFF8F9FB);
const _kPillBlue = Color(0xFFC8D8F8);
const _kMysteryBorder = Color(0xFFC9A86A);
const _kBadgeBg = Color(0xFFE8ECFF);
const _kMysteryBg = Color(0xFFFFF3E0);

/// End padding so scroll content clears the overlaid bottom CTA (not in Column flex).
const _kIntroScrollCtaSpacer = 112.0;

/// Overlaid CTA: bottom inset + `_GlowingButton` height + small gap.
const _kIntroCtaOverlayReserve = 82.0;

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

  static const _pages = <_IntroPageData>[
    _IntroPageData(variant: _IntroPageVariant.dailyPlan),
    _IntroPageData(variant: _IntroPageVariant.mishna),
    _IntroPageData(variant: _IntroPageVariant.rewards),
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

    return Scaffold(
      backgroundColor: _kBg,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned.fill(
              child: Column(
                children: [
                  _IntroHeader(onSkip: _skip),
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
                ],
              ),
            ),
            Positioned(
              left: 24,
              right: 24,
              bottom: 20,
              child: _GlowingButton(
                onTap: _nextPage,
                label: isLast ? 'Get Started' : 'Continue Journey',
                showArrow: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Header -----------------------------------------------------------------

class _IntroHeader extends StatelessWidget {
  const _IntroHeader({required this.onSkip});

  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
      child: Align(
        alignment: Alignment.centerRight,
        child: TextButton(
          onPressed: onSkip,
          style: TextButton.styleFrom(foregroundColor: AppTheme.brandInkSoft),
          child: Text(
            'Skip',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: AppTheme.brandInkSoft,
            ),
          ),
        ),
      ),
    );
  }
}

// --- Data -------------------------------------------------------------------

enum _IntroPageVariant { dailyPlan, mishna, rewards }

class _IntroPageData {
  const _IntroPageData({required this.variant});
  final _IntroPageVariant variant;
}

// --- Per page content ------------------------------------------------------

class _IntroPage extends ConsumerWidget {
  const _IntroPage({required this.data, required this.iconAnimation});

  final _IntroPageData data;
  final Animation<double> iconAnimation;

  TextStyle get _headStyle => GoogleFonts.plusJakartaSans(
    color: AppTheme.brandInk,
    fontSize: 32,
    fontWeight: FontWeight.w800,
    height: 1.15,
  );

  TextStyle get _subStyle => GoogleFonts.plusJakartaSans(
    color: AppTheme.brandInkMuted,
    fontSize: 15,
    height: 1.55,
    fontWeight: FontWeight.w400,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (data.variant == _IntroPageVariant.dailyPlan) {
      return _buildDailyPlanBottomAnchored();
    }
    return _buildScrolledPage(ref);
  }

  /// First intro: taller hero zone, then copy + bar; scrolls on very short viewports.
  Widget _buildDailyPlanBottomAnchored() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: LayoutBuilder(
        builder: (context, c) {
          // Reserve a generous vertical band for the task-card (scale-to-fit via FittedBox).
          const minHero = 220.0;
          const maxHero = 320.0;
          final heroH = (c.maxHeight * 0.55).clamp(minHero, maxHero);
          return SingleChildScrollView(
            clipBehavior: Clip.hardEdge,
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: c.maxHeight),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: heroH,
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.contain,
                        child: _buildHero(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildTitleBlock(),
                  const SizedBox(height: 10),
                  _buildSubtitleBlock(),
                  const SizedBox(height: 12),
                  _buildProgressArea(),
                  const SizedBox(height: _kIntroCtaOverlayReserve),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Pages 2 & 3: full-page scroll.
  Widget _buildScrolledPage(WidgetRef ref) {
    final hebrewTerms = ref.watch(hebrewTermsScriptProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        clipBehavior: Clip.hardEdge,
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              children: [
                const SizedBox(height: 8),
                _buildHero(),
                const SizedBox(height: 24),
                if (data.variant == _IntroPageVariant.rewards) ...[
                  const _ChildModeTag(),
                  const SizedBox(height: 12),
                ],
                _buildTitleBlock(),
                const SizedBox(height: 14),
                _buildSubtitleBlock(hebrewTerms: hebrewTerms),
                const SizedBox(height: 20),
                _buildProgressArea(hebrewTerms: hebrewTerms),
                const SizedBox(height: 24),
              ],
            ),
          ),
          const SliverToBoxAdapter(
            child: SizedBox(height: _kIntroScrollCtaSpacer),
          ),
        ],
      ),
    );
  }

  Widget _buildHero() {
    switch (data.variant) {
      case _IntroPageVariant.dailyPlan:
        return _IntroDailyPlanIllustration(animation: iconAnimation);
      case _IntroPageVariant.mishna:
        return _IntroMishnaIllustration(animation: iconAnimation);
      case _IntroPageVariant.rewards:
        return _IntroRewardsHeroIllustration(animation: iconAnimation);
    }
  }

  Widget _buildTitleBlock() {
    return AnimatedBuilder(
      animation: iconAnimation,
      builder: (context, _) {
        final fade = CurvedAnimation(
          parent: iconAnimation,
          curve: const Interval(0.2, 0.75, curve: Curves.easeOut),
        ).value;
        return Opacity(opacity: fade, child: _titleRich());
      },
    );
  }

  Widget _titleRich() {
    switch (data.variant) {
      case _IntroPageVariant.dailyPlan:
        return Text.rich(
          TextSpan(
            style: _headStyle.copyWith(fontSize: 28, height: 1.1),
            children: const [
              TextSpan(text: 'Your Daily\n'),
              TextSpan(
                text: 'Torah Plan',
                style: TextStyle(color: _kNavy, fontStyle: FontStyle.italic),
              ),
            ],
          ),
          textAlign: TextAlign.center,
        );
      case _IntroPageVariant.mishna:
        return Text.rich(
          TextSpan(
            style: _headStyle,
            children: const [
              TextSpan(text: 'Never Forget\na '),
              TextSpan(
                text: 'Mishna',
                style: TextStyle(color: _kNavy, fontStyle: FontStyle.italic),
              ),
            ],
          ),
          textAlign: TextAlign.center,
        );
      case _IntroPageVariant.rewards:
        return Text(
          'Earn While You Learn',
          textAlign: TextAlign.center,
          style: _headStyle,
        );
    }
  }

  Widget _buildSubtitleBlock({bool hebrewTerms = false}) {
    return AnimatedBuilder(
      animation: iconAnimation,
      builder: (context, _) {
        final fade = CurvedAnimation(
          parent: iconAnimation,
          curve: const Interval(0.3, 0.85, curve: Curves.easeOut),
        ).value;
        return Opacity(
          opacity: fade,
          child: _subtitleRich(hebrewTerms: hebrewTerms),
        );
      },
    );
  }

  Widget _subtitleRich({bool hebrewTerms = false}) {
    switch (data.variant) {
      case _IntroPageVariant.dailyPlan:
        return Text.rich(
          TextSpan(
            style: _subStyle.copyWith(fontSize: 14, height: 1.45),
            children: const [
              TextSpan(text: 'Learning Tracker turns massive goals into '),
              TextSpan(
                text: 'clear daily tasks',
                style: TextStyle(
                  color: AppTheme.brandInk,
                  fontWeight: FontWeight.w700,
                ),
              ),
              TextSpan(text: ', so you always know what to study next.'),
            ],
          ),
          textAlign: TextAlign.center,
        );
      case _IntroPageVariant.mishna:
        return Text.rich(
          TextSpan(
            style: _subStyle,
            children: const [
              TextSpan(
                text:
                    'Master your learning with intelligent review cycles. Our ',
              ),
              TextSpan(
                text: 'spaced-repetition engine',
                style: TextStyle(
                  color: AppTheme.brandInk,
                  fontWeight: FontWeight.w700,
                ),
              ),
              TextSpan(text: ' helps you retain everything you learn.'),
            ],
          ),
          textAlign: TextAlign.center,
        );
      case _IntroPageVariant.rewards:
        final tierLabel = hebrewTerms
            ? HebrewTerms.uiTalmidChochom
            : 'Talmid Chochom';
        return Text(
          'Collect points, build streaks, and unlock mystery rewards as you '
          'climb from a Novice to a $tierLabel!',
          textAlign: TextAlign.center,
          style: _subStyle,
        );
    }
  }

  Widget _buildProgressArea({bool hebrewTerms = false}) {
    switch (data.variant) {
      case _IntroPageVariant.dailyPlan:
        return Column(
          children: [
            SizedBox(
              width: double.infinity,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1 / 3),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  builder: (context, t, child) {
                    return LayoutBuilder(
                      builder: (context, c) {
                        return Stack(
                          children: [
                            Container(
                              width: c.maxWidth,
                              height: 6,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE2E5EB),
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                width: c.maxWidth * t,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: _kGreen,
                                  borderRadius: BorderRadius.horizontal(
                                    left: Radius.circular(999),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'SETUP PROGRESS',
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.brandInkSoft,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
          ],
        );
      case _IntroPageVariant.mishna:
        return SizedBox(
          width: double.infinity,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 2 / 3),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (context, t, child) {
                return LayoutBuilder(
                  builder: (context, c) {
                    return Stack(
                      children: [
                        Container(
                          width: c.maxWidth,
                          height: 5,
                          color: const Color(0xFFE2E5EB),
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            width: c.maxWidth * t,
                            height: 5,
                            color: const Color(0xFFB8C0CC),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        );
      case _IntroPageVariant.rewards:
        return Column(
          children: [
            const _FeatureCardsRow(),
            const SizedBox(height: 20),
            _ScholarLevelCard(hebrewTerms: hebrewTerms),
          ],
        );
    }
  }
}

// --- Page 1 illustration --------------------------------------------------

class _IntroDailyPlanIllustration extends StatelessWidget {
  const _IntroDailyPlanIllustration({required this.animation});
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final scale = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
        ).value.clamp(0.85, 1.0);
        return Transform.scale(scale: scale, child: child);
      },
      child: Stack(
        clipBehavior: Clip.hardEdge,
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 4,
            top: 0,
            child: Container(
              width: 52,
              height: 52,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: _kPeach,
              ),
            ),
          ),
          // Card Column is ~180+ px intrinsic; FittedBox scales to fit the Stack
          // (prevents ~30px RenderFlex overflow in tight maxHeight).
          Center(
            child: FittedBox(
              fit: BoxFit.contain,
              alignment: Alignment.center,
              child: Container(
                width: 248,
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                decoration: BoxDecoration(
                  color: AppTheme.brandCreamCard,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: _kNavy.withValues(alpha: 0.12),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Row(
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _WindowDot(c: _kCoral),
                            _WindowDot(c: Color(0xFFFFC94A)),
                            _WindowDot(c: Color(0xFF5BC0EB)),
                          ],
                        ),
                        Spacer(),
                        Icon(
                          Icons.calendar_today_outlined,
                          size: 14,
                          color: AppTheme.brandInkMuted,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    _dailyListRow1Checked(),
                    const SizedBox(height: 4),
                    _dailyListRow2Highlight(),
                    const SizedBox(height: 4),
                    _dailyListRowEmpty(filled: true),
                    const SizedBox(height: 4),
                    _dailyListRowEmpty(filled: false),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: _kNavy,
              ),
              child: const Center(
                child: Icon(Icons.auto_awesome, color: _kGoldTrophy, size: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Widget _dailyListRow1Checked() {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
    decoration: BoxDecoration(
      color: const Color(0xFFF0F1F4),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Row(
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: _kNavy,
          ),
          child: const Icon(
            Icons.check,
            size: 14,
            color: AppTheme.brandCreamCard,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            height: 7,
            decoration: BoxDecoration(
              color: const Color(0xFFDCDFE5),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _dailyListRow2Highlight() {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
    decoration: BoxDecoration(
      color: _kNavy,
      borderRadius: BorderRadius.circular(999),
      boxShadow: [
        BoxShadow(
          color: _kNavy.withValues(alpha: 0.2),
          blurRadius: 8,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(
            color: AppTheme.brandCreamCard,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.play_arrow_rounded, color: _kNavy, size: 16),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            height: 8,
            decoration: BoxDecoration(
              color: AppTheme.brandCreamCard.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _dailyListRowEmpty({required bool filled}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
    decoration: BoxDecoration(
      color: const Color(0xFFF0F1F4),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Row(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFC9CED6)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            height: 7,
            decoration: BoxDecoration(
              color: filled ? const Color(0xFFDCDFE5) : const Color(0xFFE5E7EC),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
      ],
    ),
  );
}

class _WindowDot extends StatelessWidget {
  const _WindowDot({required this.c});
  final Color c;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 5),
      width: 7,
      height: 7,
      decoration: BoxDecoration(shape: BoxShape.circle, color: c),
    );
  }
}

// --- Page 2 illustration --------------------------------------------------

class _IntroMishnaIllustration extends StatelessWidget {
  const _IntroMishnaIllustration({required this.animation});
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final t = animation.value;
        return Transform.rotate(angle: -0.04 + (0.01 * (1 - t)), child: child);
      },
      child: SizedBox(
        height: 250,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Positioned(
              left: 0,
              top: 20,
              child: Transform.rotate(
                angle: -0.1,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _kPillBlue,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Review…',
                    style: GoogleFonts.plusJakartaSans(
                      color: _kNavy,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 0,
              top: 40,
              child: Transform.rotate(
                angle: 0.08,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _kPeach.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '…yos',
                    style: GoogleFonts.plusJakartaSans(
                      color: AppTheme.brandInk,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            Center(
              child: Container(
                width: 188,
                height: 200,
                decoration: BoxDecoration(
                  color: _kNavy,
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: _kNavy.withValues(alpha: 0.28),
                      blurRadius: 22,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    const Center(
                      child: Icon(
                        Icons.psychology_rounded,
                        color: AppTheme.brandCreamCard,
                        size: 96,
                      ),
                    ),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: _kCoral,
                        ),
                        child: const Icon(
                          Icons.sync,
                          color: AppTheme.brandCreamCard,
                          size: 20,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 8,
                      bottom: 8,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppTheme.brandCreamCard,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.lightbulb_outline,
                          color: _kNavy,
                          size: 26,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Page 3 hero + feature cards + scholar ----------------------------------

class _IntroRewardsHeroIllustration extends StatelessWidget {
  const _IntroRewardsHeroIllustration({required this.animation});
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final s = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
        ).value.clamp(0.88, 1.0);
        return Transform.scale(scale: s, child: child);
      },
      child: SizedBox(
        height: 200,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Container(
              width: 168,
              height: 168,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: _kNavy,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x40000000),
                    blurRadius: 18,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(
                Icons.emoji_events_rounded,
                color: _kGoldTrophy,
                size: 84,
              ),
            ),
            Positioned(
              top: 0,
              right: 32,
              child: Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: _kPeach,
                ),
                child: const Icon(
                  Icons.star,
                  color: AppTheme.brandInk,
                  size: 24,
                ),
              ),
            ),
            Positioned(
              left: 0,
              bottom: 6,
              child: Transform.rotate(
                angle: -0.1,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _kCoral,
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x2E000000),
                        blurRadius: 6,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.local_fire_department,
                        size: 14,
                        color: AppTheme.brandCreamCard,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '7 DAY STREAK',
                        style: GoogleFonts.plusJakartaSans(
                          color: AppTheme.brandCreamCard,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureCardsRow extends StatelessWidget {
  const _FeatureCardsRow();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(
          child: _FeatureCard(
            icon: Icons.military_tech_outlined,
            label: 'Badge\nCollection',
            bottomBorder: _kNavy,
            circleColor: _kBadgeBg,
            textColor: _kNavy,
            iconColor: _kNavy,
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: _FeatureCard(
            icon: Icons.card_giftcard_rounded,
            label: 'Mystery\nPrizes',
            bottomBorder: _kMysteryBorder,
            circleColor: _kMysteryBg,
            textColor: Color(0xFF5C4A2A),
            iconColor: Color(0xFF6B4E1E),
          ),
        ),
      ],
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.icon,
    required this.label,
    required this.bottomBorder,
    required this.circleColor,
    required this.textColor,
    required this.iconColor,
  });

  final IconData icon;
  final String label;
  final Color bottomBorder;
  final Color circleColor;
  final Color textColor;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 0),
      decoration: BoxDecoration(
        color: AppTheme.brandCreamCard,
        borderRadius: BorderRadius.circular(20),
        border: Border(bottom: BorderSide(color: bottomBorder, width: 3)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.brandInk.withValues(alpha: 0.07),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: circleColor,
            ),
            child: Icon(icon, size: 24, color: iconColor),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _ChildModeTag extends StatelessWidget {
  const _ChildModeTag();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: _kBadgeBg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.child_care_rounded,
            size: 14,
            color: _kNavy,
          ),
          const SizedBox(width: 6),
          Text(
            'CHILD MODE FEATURE',
            style: GoogleFonts.plusJakartaSans(
              color: _kNavy,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScholarLevelCard extends StatelessWidget {
  const _ScholarLevelCard({required this.hebrewTerms});

  final bool hebrewTerms;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: AppTheme.brandCreamCard,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppTheme.brandInk.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Scholar Level',
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.brandInk,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                'Level 4',
                style: GoogleFonts.plusJakartaSans(
                  color: _kNavy,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, c) {
              return Stack(
                children: [
                  Container(
                    width: c.maxWidth,
                    height: 8,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8EAEF),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width: c.maxWidth * 0.6,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: _kGreen,
                        borderRadius: BorderRadius.horizontal(
                          left: Radius.circular(999),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'NOVICE',
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.brandInkSoft,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
              Text(
                hebrewTerms
                    ? HebrewTerms.uiTalmidChochom
                    : 'TALMID CHOCHOM',
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.brandInkSoft,
                  fontSize: hebrewTerms ? 11 : 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: hebrewTerms ? 0 : 0.3,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// --- CTA button -------------------------------------------------------------

class _GlowingButton extends StatelessWidget {
  const _GlowingButton({
    required this.onTap,
    required this.label,
    this.showArrow = true,
  });

  final VoidCallback onTap;
  final String label;
  final bool showArrow;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(27),
          color: _kNavy,
          boxShadow: [
            BoxShadow(
              color: _kNavy.withValues(alpha: 0.28),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(27),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          color: AppTheme.brandCreamCard,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (showArrow) ...[
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          color: AppTheme.brandCreamCard,
                          size: 22,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
