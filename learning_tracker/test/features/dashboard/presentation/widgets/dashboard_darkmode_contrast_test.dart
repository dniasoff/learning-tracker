// Dark-mode legibility sweep — dashboard feature area
// (`lib/features/dashboard/presentation/`).
//
// Modelled on `test/core/theme/darkmode_sweep_contrast_test.dart`'s WCAG
// helper + widget-pump style. Two real, on-device-class dark-mode bugs found
// in this area, both instances of the "ink/fill token used in the wrong
// role" class (goldTrophy/chartAmber precedent):
//
// Bug 1 — `kAllCaughtUpProgressFill` (`dashboard_helpers.dart`), consumed by
// `DashboardAllCaughtUpCard`'s lifetime-progress-bar FILL: read
// `context.colors.goldTrophy`, a token that correctly DARKENS in dark mode
// for its normal role (ink on a FIXED WHITE surface — see
// `child_points_rewards_tab_card.dart`'s trophy circle). Used instead as a
// fill on the card's own blue gradient (which STAYS deep/coloured in dark
// mode), the darkened near-brown measured ~1.29:1 against the card's dark
// navy track — effectively invisible (WCAG non-text needs ≥3:1). Fixed by
// switching to `goldOnColouredSurface`, the token already split out for
// exactly this role (used correctly by this card's sibling,
// `dashboard_level_points_card.dart`, for its own lifetime-progress fill).
//
// Bug 2 — Three call sites painted `Colors.white` text/icons directly onto a
// `brandBlue`-filled surface (`ActiveTrackFocusPill`'s prominent "Today"
// pill, `MainFocusMissionCard`'s count badge + "Start Learning" button, and
// `ActiveTrackCard`'s "Continue" button). `brandBlue` deliberately LIGHTENS
// in dark mode for its normal ink-on-card role (see its own doc comment in
// `app_palette.dart`) — used as a FILL instead, the lightened dark-mode blue
// dropped hardcoded white text/icons to ~2.52:1 (WCAG text needs ≥4.5:1).
// Fixed by reading `Theme.of(context).colorScheme.onPrimary` instead of the
// literal — `AppTheme`'s `_build` already computes this per-brightness
// specifically for content painted on `colorScheme.primary` (== brandBlue
// at the app root, see `onFill` in `app_theme.dart`): it resolves to the
// same white in light mode (no regression) and to a near-black ink in dark
// mode (~7.6:1), exactly like the several FilledButtons elsewhere
// (`error_display.dart`, `app_error_view.dart`, `text_display_screen.dart`)
// that already rely on it instead of hardcoding a colour.
@Tags(['dashboard'])
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/core/widgets/animated_progress_bar.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/active_track_card.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/active_track_focus_pill.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/dashboard_all_caught_up_card.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/main_focus_mission_card.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/progress/presentation/providers/lifetime_knowledge_providers.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';

import '../../../../helpers/pump_app.dart';

const _profileId = 11;
const _trackId = 99;

class _ProfileIdOverride extends ActiveProfileId {
  @override
  int build() => _profileId;
}

class _UseHebrewTermsOverride extends UseHebrewTerms {
  @override
  bool build() => false;
}

/// WCAG relative luminance (sRGB), per w3.org/TR/WCAG21/#dfn-relative-luminance.
double _relativeLuminance(Color c) {
  double channel(double v) {
    final s = v / 255.0;
    return s <= 0.03928
        ? s / 12.92
        : math.pow((s + 0.055) / 1.055, 2.4) as double;
  }

  return 0.2126 * channel((c.r * 255).roundToDouble()) +
      0.7152 * channel((c.g * 255).roundToDouble()) +
      0.0722 * channel((c.b * 255).roundToDouble());
}

/// WCAG contrast ratio between two opaque colours.
double _contrast(Color a, Color b) {
  final la = _relativeLuminance(a);
  final lb = _relativeLuminance(b);
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

CurriculumTrack _track() => CurriculumTrack(
  id: _trackId,
  profileId: _profileId,
  curriculumId: CurriculumId.bavli.storageKey,
  state: 'active',
  stateChangedAt: DateTime.utc(2026, 1, 1),
  activatedAt: DateTime.utc(2026, 1, 1),
);

DailyTask _todayTask() => const DailyTask(
  curriculumId: CurriculumId.bavli,
  contentItemSefariaRef: 'Chullin 25a',
  stageOrder: 1,
  stageDefinitionId: 1,
  priority: DailyTaskPriority.todayProgram,
  isOverdue: false,
  reason: 'test',
  stageName: 'Learn',
  trackId: _trackId,
  trackLabel: 'personal',
  estimatedEffortMinutes: 5,
  unitDisplayHe: 'חולין דף כ״ה',
  unitDisplayEn: 'Chullin 25',
);

Widget _activeTrackCardHarness({required ThemeData? theme}) {
  return pumpApp(
    theme: theme,
    overrides: [
      activeProfileIdProvider.overrideWith(_ProfileIdOverride.new),
      useHebrewTermsProvider.overrideWith(_UseHebrewTermsOverride.new),
      dashboardHasProgramEnrollmentProvider(
        CurriculumId.bavli,
      ).overrideWith((ref) async => true),
      trackHasChazaraProvider(_trackId).overrideWith((ref) async => false),
      trackDualProgressMetricsProvider(
        _profileId,
      ).overrideWith((ref) async => const <TrackDualProgressMetric>[]),
    ],
    child: Scaffold(
      body: SizedBox(
        width: 360,
        height: 400,
        child: ActiveTrackCard(track: _track(), allTasks: [_todayTask()]),
      ),
    ),
  );
}

void main() {
  group('Bug 1 — DashboardAllCaughtUpCard lifetime-progress-bar fill', () {
    test('goldOnColouredSurface clears WCAG 3:1 (non-text) against the card\'s '
        'dark navy track in dark mode (goldTrophy measured ~1.29:1 before the '
        'fix)', () {
      const palette = AppPalette.dark;
      final fixedRatio = _contrast(
        palette.goldOnColouredSurface,
        palette.blueNavy,
      );
      final preFixRatio = _contrast(palette.goldTrophy, palette.blueNavy);

      expect(
        fixedRatio,
        greaterThanOrEqualTo(3.0),
        reason:
            'goldOnColouredSurface is the token already split out for '
            '"fill on a surface that stays coloured in dark mode" — it '
            'must stay legible against the card\'s dark-navy track',
      );
      expect(
        preFixRatio,
        lessThan(3.0),
        reason:
            'red demo: goldTrophy darkens to a near-brown in dark mode '
            '(correct for ink on a FIXED WHITE circle elsewhere), which '
            'is why the old call site was invisible on this coloured card',
      );
    });

    test('light mode is unchanged — goldOnColouredSurface equals goldTrophy\'s '
        'exact pre-fix light-mode hex (0xFFFFC94A)', () {
      const light = AppPalette.light;

      expect(light.goldOnColouredSurface, const Color(0xFFFFC94A));
      expect(light.goldOnColouredSurface, light.goldTrophy);
      expect(
        _contrast(light.goldOnColouredSurface, light.blueNavy),
        greaterThanOrEqualTo(3.0),
      );
    });

    testWidgets(
      'the real card reads goldOnColouredSurface (not goldTrophy) for its '
      'lifetime-progress fill in dark mode',
      (tester) async {
        await tester.pumpWidget(
          pumpApp(
            theme: AppTheme.darkTheme(),
            child: const Scaffold(
              body: DashboardAllCaughtUpCard(
                doneDisplay: '42%',
                cumulativeLifetime: 0.42,
              ),
            ),
          ),
        );
        await tester.pump();

        final bar = tester.widget<AnimatedProgressBar>(
          find.byType(AnimatedProgressBar),
        );

        expect(bar.color, AppPalette.dark.goldOnColouredSurface);
        expect(bar.color, isNot(AppPalette.dark.goldTrophy));
      },
    );

    testWidgets(
      'the real card keeps the exact pre-fix 0xFFFFC94A fill in light mode '
      '(no regression)',
      (tester) async {
        await tester.pumpWidget(
          pumpApp(
            child: const Scaffold(
              body: DashboardAllCaughtUpCard(
                doneDisplay: '42%',
                cumulativeLifetime: 0.42,
              ),
            ),
          ),
        );
        await tester.pump();

        final bar = tester.widget<AnimatedProgressBar>(
          find.byType(AnimatedProgressBar),
        );
        expect(bar.color, const Color(0xFFFFC94A));
      },
    );
  });

  group('Bug 2 — white text/icons on the brandBlue fill '
      '(ActiveTrackFocusPill, MainFocusMissionCard, ActiveTrackCard)', () {
    test('colorScheme.onPrimary clears WCAG 4.5:1 against brandBlue in dark '
        'mode (Colors.white measured ~2.52:1 before the fix)', () {
      final darkScheme = AppTheme.darkTheme().colorScheme;
      final fixedRatio = _contrast(
        darkScheme.onPrimary,
        AppPalette.dark.brandBlue,
      );
      final preFixRatio = _contrast(Colors.white, AppPalette.dark.brandBlue);

      expect(
        fixedRatio,
        greaterThanOrEqualTo(4.5),
        reason:
            'brandBlue LIGHTENS in dark mode for its normal '
            'ink-on-card role; colorScheme.onPrimary is computed '
            'per-brightness specifically for content on '
            'colorScheme.primary (== brandBlue at the app root)',
      );
      expect(
        preFixRatio,
        lessThan(4.5),
        reason:
            'red demo: a hardcoded Colors.white measured ~2.52:1 '
            'against the lightened dark-mode brandBlue fill',
      );
    });

    test('light mode is unchanged — colorScheme.onPrimary is pure white, '
        'same as the old Colors.white literal', () {
      final lightScheme = AppTheme.lightTheme().colorScheme;

      expect(lightScheme.onPrimary, const Color(0xFFFFFFFF));
      expect(
        _contrast(lightScheme.onPrimary, AppPalette.light.brandBlue),
        greaterThanOrEqualTo(4.5),
      );
    });

    testWidgets(
      'ActiveTrackFocusPill (prominent) reads onPrimary — not Colors.white '
      '— for its label/value/icon in dark mode',
      (tester) async {
        await tester.pumpWidget(
          pumpApp(
            theme: AppTheme.darkTheme(),
            child: const Scaffold(
              body: ActiveTrackFocusPill(
                label: 'TODAY',
                value: 'Chullin 25',
                prominent: true,
                icon: Icons.today_rounded,
              ),
            ),
          ),
        );
        await tester.pump();

        final onPrimaryDark = AppTheme.darkTheme().colorScheme.onPrimary;

        final valueText = tester.widget<Text>(find.text('Chullin 25'));
        expect(valueText.style?.color, onPrimaryDark);
        expect(valueText.style?.color, isNot(Colors.white));

        final labelText = tester.widget<Text>(find.text('TODAY'));
        expect(labelText.style?.color, onPrimaryDark.withValues(alpha: 0.85));

        final icon = tester.widget<Icon>(find.byIcon(Icons.today_rounded));
        expect(icon.color, onPrimaryDark);
      },
    );

    testWidgets(
      'ActiveTrackFocusPill (prominent) keeps white label/value/icon in '
      'light mode (no regression)',
      (tester) async {
        await tester.pumpWidget(
          pumpApp(
            child: const Scaffold(
              body: ActiveTrackFocusPill(
                label: 'TODAY',
                value: 'Chullin 25',
                prominent: true,
                icon: Icons.today_rounded,
              ),
            ),
          ),
        );
        await tester.pump();

        final valueText = tester.widget<Text>(find.text('Chullin 25'));
        expect(valueText.style?.color, const Color(0xFFFFFFFF));

        final icon = tester.widget<Icon>(find.byIcon(Icons.today_rounded));
        expect(icon.color, const Color(0xFFFFFFFF));
      },
    );

    testWidgets(
      'MainFocusMissionCard reads onPrimary — not Colors.white — for the '
      'count badge and the Start Learning button in dark mode',
      (tester) async {
        await tester.pumpWidget(
          pumpApp(
            theme: AppTheme.darkTheme(),
            child: Scaffold(body: MainFocusMissionCard(count: 3, onTap: () {})),
          ),
        );
        await tester.pump();

        final onPrimaryDark = AppTheme.darkTheme().colorScheme.onPrimary;

        final badgeText = tester.widget<Text>(find.text('3'));
        expect(badgeText.style?.color, onPrimaryDark);
        expect(badgeText.style?.color, isNot(Colors.white));

        final button = tester.widget<FilledButton>(find.byType(FilledButton));
        expect(
          button.style?.foregroundColor?.resolve(<WidgetState>{}),
          onPrimaryDark,
        );
      },
    );

    testWidgets(
      'MainFocusMissionCard keeps white text in light mode (no regression)',
      (tester) async {
        await tester.pumpWidget(
          pumpApp(
            child: Scaffold(body: MainFocusMissionCard(count: 3, onTap: () {})),
          ),
        );
        await tester.pump();

        final badgeText = tester.widget<Text>(find.text('3'));
        expect(badgeText.style?.color, const Color(0xFFFFFFFF));
      },
    );

    testWidgets('ActiveTrackCard\'s Continue button reads onPrimary — not '
        'Colors.white — for its foreground in dark mode', (tester) async {
      await tester.pumpWidget(
        _activeTrackCardHarness(theme: AppTheme.darkTheme()),
      );
      await tester.pump();

      final onPrimaryDark = AppTheme.darkTheme().colorScheme.onPrimary;
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(
        button.style?.foregroundColor?.resolve(<WidgetState>{}),
        onPrimaryDark,
      );
      expect(
        button.style?.foregroundColor?.resolve(<WidgetState>{}),
        isNot(Colors.white),
      );
    });

    testWidgets(
      'ActiveTrackCard\'s Continue button keeps a white foreground in '
      'light mode (no regression)',
      (tester) async {
        await tester.pumpWidget(_activeTrackCardHarness(theme: null));
        await tester.pump();

        final button = tester.widget<FilledButton>(find.byType(FilledButton));
        expect(
          button.style?.foregroundColor?.resolve(<WidgetState>{}),
          const Color(0xFFFFFFFF),
        );
      },
    );
  });
}
