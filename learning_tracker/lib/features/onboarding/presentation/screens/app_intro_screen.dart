import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:learning_tracker/core/labels/domain_term_labels.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/features/onboarding/presentation/providers/onboarding_resume_store.dart'
    show kPermissionsPrompted;
import 'package:learning_tracker/features/onboarding/presentation/widgets/glowing_cta_button.dart';
import 'package:learning_tracker/features/onboarding/presentation/widgets/intro_daily_plan_page.dart';
import 'package:learning_tracker/features/onboarding/presentation/widgets/intro_mishna_page.dart';
import 'package:learning_tracker/features/onboarding/presentation/widgets/intro_rewards_page.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
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

/// Horizontal inset for the pinned CTA region (matches the page content gutter).
const _kIntroCtaHInset = 24.0;

/// Vertical inset above/below the pinned CTA region.
const _kIntroCtaVInset = 20.0;

/// Sentinel passed into the bold-highlight subtitle ICU getters, then split out
/// again so the emphasised phrase can be rendered in its own [TextStyle]. Uses a
/// Unicode Private-Use character that can never appear in real copy, keeping the
/// split deterministic across locales.
const _kHighlightPlaceholder = '\uE000';

/// Onboarding intro palette (design mockup).
const _kNavy = Color(0xFF1A36A5);

/// Breathing room at the bottom of the scroll content above the pinned CTA.
/// The CTA is now a non-overlapping Column sibling (not an overlay), so this is
/// just visual padding — not a clearance reserve.
const _kIntroScrollBottomGap = 16.0;

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
    if (!mounted) return;
    // Ask for the device-level permissions (notifications + location) once, as
    // the closing step of the first-run flow — before sign-in — so every user
    // is prompted regardless of which post-sign-in path they take (profile
    // creation, tutor join, or skip-to-empty-login). Reuses the canonical
    // PermissionPromptScreen; it pops back here when the user resolves or skips.
    await context.router.push(PermissionPromptRoute(isOnboarding: true));
    await prefs.setBool(kPermissionsPrompted, true);
    if (mounted) unawaited(context.router.replace(const SignInRoute()));
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _currentPage == _pages.length - 1;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppTheme.brandCream,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        // Non-overlapping layout: the PageView (Expanded) sits above the pinned
        // CTA in a Column, so the scroll viewport's bottom edge is the CTA's top
        // edge. Nothing can ever be hidden behind the CTA at first paint — at
        // any text scale — because the CTA is no longer a Positioned overlay
        // drawing on top of the scroll content (the old bug: the rewards page's
        // reward cards were clipped by the overlaid CTA at rest, worse at 1.3).
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
            Padding(
              padding: const EdgeInsets.fromLTRB(
                _kIntroCtaHInset,
                _kIntroCtaVInset,
                _kIntroCtaHInset,
                _kIntroCtaVInset,
              ),
              child: GlowingCtaButton(
                onTap: _nextPage,
                label: isLast ? l10n.getStarted : l10n.introContinueJourney,
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
            AppLocalizations.of(context)!.skip,
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
    final l10n = AppLocalizations.of(context)!;
    if (data.variant == _IntroPageVariant.dailyPlan) {
      return _buildDailyPlanBottomAnchored(ref, l10n);
    }
    return _buildScrolledPage(ref, l10n);
  }

  /// First intro: taller hero zone, then copy + bar; scrolls on very short viewports.
  Widget _buildDailyPlanBottomAnchored(WidgetRef ref, AppLocalizations l10n) {
    final terms = domainTermLabels(ref);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: LayoutBuilder(
        builder: (context, c) {
          // Reserve a generous vertical band for the task-card (scale-to-fit via FittedBox).
          // On phones the natural 55 % fraction lands under 320 px so the hard
          // cap is irrelevant. On tablets/large viewports the old hard 320 cap
          // left a large empty gap below the progress bar; capping at 65 % of
          // the available height instead lets the hero absorb the extra space
          // and eliminates the dead zone without touching the phone layout.
          const minHero = 220.0;
          final heroH = (c.maxHeight * 0.55).clamp(minHero, c.maxHeight * 0.65);
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
                  _buildTitleBlock(l10n: l10n, mishnaLabel: terms.mishnah),
                  const SizedBox(height: 10),
                  _buildSubtitleBlock(
                    l10n: l10n,
                    talmidChochomLabel: terms.talmidChochom,
                  ),
                  const SizedBox(height: 12),
                  const IntroDailyPlanProgressBar(),
                  const SizedBox(height: _kIntroScrollBottomGap),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Pages 2 & 3: full-page scroll.
  ///
  /// The rewards page (page 3) is content-rich — hero + child-mode tag + title
  /// + subtitle + two reward cards + a scholar-level card. The pinned CTA is a
  /// non-overlapping Column sibling below this scroll view, so the scroll
  /// viewport ends where the CTA begins and the reward cards can never be hidden
  /// behind it — at any text scale. When the content is taller than the viewport
  /// (e.g. font scale 1.3) the page simply scrolls; the cards are reachable and
  /// uncovered. The rewards page keeps tighter lead spacing so as much content
  /// as possible is visible on first paint.
  Widget _buildScrolledPage(WidgetRef ref, AppLocalizations l10n) {
    final terms = domainTermLabels(ref);
    final isRewards = data.variant == _IntroPageVariant.rewards;
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
                SizedBox(height: isRewards ? 0 : 8),
                _buildHero(),
                SizedBox(height: isRewards ? 14 : 24),
                if (isRewards) ...[
                  const IntroChildModeTag(),
                  const SizedBox(height: 12),
                ],
                _buildTitleBlock(l10n: l10n, mishnaLabel: terms.mishnah),
                SizedBox(height: isRewards ? 8 : 14),
                _buildSubtitleBlock(
                  l10n: l10n,
                  talmidChochomLabel: terms.talmidChochom,
                ),
                SizedBox(height: isRewards ? 14 : 20),
                _buildProgressArea(),
                const SizedBox(height: 24),
              ],
            ),
          ),
          const SliverToBoxAdapter(
            child: SizedBox(height: _kIntroScrollBottomGap),
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

  Widget _buildTitleBlock({
    required AppLocalizations l10n,
    required String mishnaLabel,
  }) {
    return AnimatedBuilder(
      animation: iconAnimation,
      builder: (context, _) {
        final fade = CurvedAnimation(
          parent: iconAnimation,
          curve: const Interval(0.2, 0.75, curve: Curves.easeOut),
        ).value;
        return Opacity(
          opacity: fade,
          child: _titleRich(l10n: l10n, mishnaLabel: mishnaLabel),
        );
      },
    );
  }

  Widget _titleRich({
    required AppLocalizations l10n,
    required String mishnaLabel,
  }) {
    const highlightStyle = TextStyle(
      color: _kNavy,
      fontStyle: FontStyle.italic,
    );
    switch (data.variant) {
      case _IntroPageVariant.dailyPlan:
        return Text.rich(
          TextSpan(
            style: _headStyle.copyWith(fontSize: 28, height: 1.1),
            children: [
              TextSpan(text: '${l10n.introDailyPlanTitleLine1}\n'),
              TextSpan(
                text: l10n.introDailyPlanTitleHighlight,
                style: highlightStyle,
              ),
            ],
          ),
          textAlign: TextAlign.center,
        );
      case _IntroPageVariant.mishna:
        return Text.rich(
          TextSpan(
            style: _headStyle,
            children: [
              TextSpan(text: l10n.introMishnaTitlePrefix),
              TextSpan(text: mishnaLabel, style: highlightStyle),
            ],
          ),
          textAlign: TextAlign.center,
        );
      case _IntroPageVariant.rewards:
        return Text(
          l10n.introRewardsTitle,
          textAlign: TextAlign.center,
          style: _headStyle,
        );
    }
  }

  Widget _buildSubtitleBlock({
    required AppLocalizations l10n,
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
            l10n: l10n,
            talmidChochomLabel: talmidChochomLabel,
            isHebrewLocale:
                Localizations.localeOf(context).languageCode == 'he',
          ),
        );
      },
    );
  }

  Widget _subtitleRich({
    required AppLocalizations l10n,
    required bool isHebrewLocale,
    String talmidChochomLabel = 'Talmid Chochom',
  }) {
    const highlightStyle = TextStyle(
      color: AppTheme.brandInk,
      fontWeight: FontWeight.w700,
    );
    switch (data.variant) {
      case _IntroPageVariant.dailyPlan:
        return Text.rich(
          _interpolateHighlight(
            template: l10n.introDailyPlanSubtitle(_kHighlightPlaceholder),
            highlight: l10n.introDailyPlanSubtitleHighlight,
            highlightStyle: highlightStyle,
          ),
          textAlign: TextAlign.center,
          style: _subStyle.copyWith(fontSize: 14, height: 1.45),
        );
      case _IntroPageVariant.mishna:
        return Text.rich(
          _interpolateHighlight(
            template: l10n.introMishnaSubtitle(_kHighlightPlaceholder),
            highlight: l10n.introMishnaSubtitleHighlight,
            highlightStyle: highlightStyle,
          ),
          textAlign: TextAlign.center,
          style: _subStyle,
        );
      case _IntroPageVariant.rewards:
        // Force the subtitle's base direction to match the APP locale (not the
        // device locale): the English string ends with "…to a {tier}!" where
        // {tier} can be a Hebrew domain term; on a Hebrew-locale device the
        // ambient RTL base would flip the trailing "!" to the wrong side.
        return Directionality(
          textDirection: isHebrewLocale ? TextDirection.rtl : TextDirection.ltr,
          child: Text(
            l10n.introRewardsSubtitle(talmidChochomLabel),
            textAlign: TextAlign.center,
            style: _subStyle,
          ),
        );
    }
  }

  /// Splits a localized subtitle template (containing [_kHighlightPlaceholder])
  /// into plain + bold spans so the highlighted phrase keeps its emphasis in
  /// both English and Hebrew without losing the ICU placeholder.
  TextSpan _interpolateHighlight({
    required String template,
    required String highlight,
    required TextStyle highlightStyle,
  }) {
    final parts = template.split(_kHighlightPlaceholder);
    return TextSpan(
      children: [
        for (var i = 0; i < parts.length; i++) ...[
          if (i > 0) TextSpan(text: highlight, style: highlightStyle),
          TextSpan(text: parts[i]),
        ],
      ],
    );
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
