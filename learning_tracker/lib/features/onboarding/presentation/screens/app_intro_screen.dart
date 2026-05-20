import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:learning_tracker/core/labels/domain_term_labels.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/features/onboarding/presentation/widgets/glowing_cta_button.dart';
import 'package:learning_tracker/features/onboarding/presentation/widgets/intro_daily_plan_page.dart';
import 'package:learning_tracker/features/onboarding/presentation/widgets/intro_mishna_page.dart';
import 'package:learning_tracker/features/onboarding/presentation/widgets/intro_rewards_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

export 'package:learning_tracker/features/onboarding/presentation/widgets/glowing_cta_button.dart'
    show GlowingCtaButton;
export 'package:learning_tracker/features/onboarding/presentation/widgets/intro_daily_plan_page.dart'
    show IntroDailyPlanIllustration, IntroDailyPlanProgressBar;
export 'package:learning_tracker/features/onboarding/presentation/widgets/intro_mishna_page.dart'
    show IntroMishnaIllustration, IntroMishnaProgressBar;
export 'package:learning_tracker/features/onboarding/presentation/widgets/intro_page_indicator.dart'
    show IntroPageIndicator;
export 'package:learning_tracker/features/onboarding/presentation/widgets/intro_rewards_page.dart'
    show
        IntroChildModeTag,
        IntroFeatureCardsRow,
        IntroRewardsHeroIllustration,
        IntroScholarLevelCard;

const kIntroSeen = 'intro_seen';

/// Onboarding intro palette (design mockup).
const _kNavy = Color(0xFF1A36A5);
const _kBg = Color(0xFFF8F9FB);

/// End padding so scroll content clears the overlaid bottom CTA (not in Column flex).
const _kIntroScrollCtaSpacer = 112.0;

/// Overlaid CTA: bottom inset + `GlowingCtaButton` height + small gap.
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
              child: GlowingCtaButton(
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
        alignment: AlignmentDirectional.centerEnd,
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

// --- Per-page content -------------------------------------------------------

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
      return _buildDailyPlanBottomAnchored(ref);
    }
    return _buildScrolledPage(ref);
  }

  /// First intro: taller hero zone, then copy + bar; scrolls on very short viewports.
  Widget _buildDailyPlanBottomAnchored(WidgetRef ref) {
    final terms = domainTermLabels(ref);
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
                        child: IntroDailyPlanIllustration(
                          animation: iconAnimation,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildTitleBlock(),
                  const SizedBox(height: 10),
                  _buildSubtitleBlock(
                    useHebrew: terms.isHebrew,
                    talmidChochomLabel: terms.talmidChochom,
                  ),
                  const SizedBox(height: 12),
                  const IntroDailyPlanProgressBar(),
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
    final terms = domainTermLabels(ref);
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
                  const IntroChildModeTag(),
                  const SizedBox(height: 12),
                ],
                _buildTitleBlock(),
                const SizedBox(height: 14),
                _buildSubtitleBlock(
                  useHebrew: terms.isHebrew,
                  talmidChochomLabel: terms.talmidChochom,
                ),
                const SizedBox(height: 20),
                _buildProgressArea(),
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
        return IntroDailyPlanIllustration(animation: iconAnimation);
      case _IntroPageVariant.mishna:
        return IntroMishnaIllustration(animation: iconAnimation);
      case _IntroPageVariant.rewards:
        return IntroRewardsHeroIllustration(animation: iconAnimation);
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

  Widget _buildSubtitleBlock({
    bool useHebrew = false,
    String talmidChochomLabel = 'Talmid Chochom',
  }) {
    return AnimatedBuilder(
      animation: iconAnimation,
      builder: (context, _) {
        final fade = CurvedAnimation(
          parent: iconAnimation,
          curve: const Interval(0.3, 0.85, curve: Curves.easeOut),
        ).value;
        return Opacity(
          opacity: fade,
          child: _subtitleRich(
            useHebrew: useHebrew,
            talmidChochomLabel: talmidChochomLabel,
          ),
        );
      },
    );
  }

  Widget _subtitleRich({
    bool useHebrew = false,
    String talmidChochomLabel = 'Talmid Chochom',
  }) {
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
        return Text(
          'Collect points, build streaks, and unlock mystery rewards as you '
          'climb from a Novice to a $talmidChochomLabel!',
          textAlign: TextAlign.center,
          style: _subStyle,
        );
    }
  }

  Widget _buildProgressArea() {
    switch (data.variant) {
      case _IntroPageVariant.dailyPlan:
        return const IntroDailyPlanProgressBar();
      case _IntroPageVariant.mishna:
        return const IntroMishnaProgressBar();
      case _IntroPageVariant.rewards:
        return const Column(
          children: [
            IntroFeatureCardsRow(),
            SizedBox(height: 20),
            IntroScholarLevelCard(),
          ],
        );
    }
  }
}
