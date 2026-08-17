// Widget-level guardrails for the run-9 on-device audit's dark-mode
// legibility findings (docs/test-artifacts/device-audit-run9/_REPORT.md).
//
// The palette-level contrast math already lives in app_palette_test.dart
// (WCAG ratios for every token, including the new hero-fill entries added
// alongside this fix). These tests instead pump the REAL fixed widgets under
// `AppTheme.darkTheme()` and assert they actually read the brightness-aware
// token at runtime — not just that the token itself has good contrast in
// isolation, but that nothing along the way still hardcodes `Colors.white`
// or a fixed hex literal that silently bypasses it.
//
// Per TQ-3, every pump goes through the shared `pumpApp()` helper; the dark
// theme is injected by wrapping `child` in an extra `Theme(data:
// AppTheme.darkTheme())` node (the same technique app_shell.dart itself uses
// to pin its top switcher bar to a FORCED theme — see "Bug 7" — just used
// here for the opposite purpose: forcing dark for a test pump instead of
// forcing light for a permanently-light bar).
@Tags(['core_widgets', 'tracks', 'settings'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/core/widgets/stat_card.dart';
import 'package:learning_tracker/features/account/domain/models/auth_state.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_state_provider.dart';
import 'package:learning_tracker/features/tracks/setup/domain/entities/curriculum_track.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/widgets/learning_track_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/pump_app.dart';

/// Minimal Firestore-shaped [CurriculumTrackEntity] — these tests only care
/// about the fields that drive [LearningTrackCard]'s rendering.
CurriculumTrackEntity _track({required String curriculumId}) {
  final now = DateTime.utc(2026, 1, 1);
  return CurriculumTrackEntity(
    curriculumId: CurriculumId.fromStorageKey(curriculumId)!,
    state: 'active',
    stateChangedAt: now,
    activatedAt: now,
  );
}

void main() {
  setUpAll(() {
    // LearningTrackCard reads ProfileScopedPreference-backed providers
    // (Hebrew-terms toggle) — without a mock, the platform channel throws
    // MissingPluginException before the pump completes.
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('StatCard — card surface (AUD run-9: stat_card.dart:75)', () {
    testWidgets('non-highlighted card reads brandCreamCard in dark, '
        'not a hardcoded white', (tester) async {
      await tester.pumpWidget(
        pumpApp(
          child: Theme(
            data: AppTheme.darkTheme(),
            child: const Scaffold(
              body: SizedBox(
                width: 160,
                height: 120,
                child: StatCard(value: '42', label: 'Completions'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final material = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(StatCard),
              matching: find.byType(Material),
            )
            .first,
      );

      expect(
        material.color,
        AppPalette.dark.brandCreamCard,
        reason:
            'StatCard must resolve its card colour through '
            'context.colors.brandCreamCard so it goes dark in dark mode — '
            'a hardcoded Colors.white here renders a light card (and its '
            'theme-aware ink) invisible on a dark screen (run-9, 5564).',
      );
      expect(material.color, isNot(Colors.white));
    });

    testWidgets('non-highlighted card stays white in light mode (no '
        'regression)', (tester) async {
      await tester.pumpWidget(
        pumpApp(
          child: const Scaffold(
            body: SizedBox(
              width: 160,
              height: 120,
              child: StatCard(value: '42', label: 'Completions'),
            ),
          ),
        ),
      );
      await tester.pump();

      final material = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(StatCard),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(material.color, AppPalette.light.brandCreamCard);
    });
  });

  group('LearningTrackCard — card surface + hero-fill accent '
      '(AUD run-9: learning_track_card.dart:93, blueMedium)', () {
    testWidgets('card reads brandCreamCard and the accent icon square '
        'stays deep (not a washed-out pastel) in dark', (tester) async {
      await tester.pumpWidget(
        pumpApp(
          child: Theme(
            data: AppTheme.darkTheme(),
            child: Scaffold(
              body: LearningTrackCard(track: _track(curriculumId: 'mishnayos')),
            ),
          ),
          // Short-circuits the dashboard-providers -> sync -> auth chain
          // before it reaches a real FirebaseAuthGatewayImpl (uninitialised
          // in widget tests).
          overrides: [
            authStateProvider.overrideWithValue(const AuthState.signedOut()),
          ],
        ),
      );
      await tester.pump();

      final ink = tester.widget<Ink>(
        find.descendant(
          of: find.byType(LearningTrackCard),
          matching: find.byType(Ink),
        ),
      );
      final inkDecoration = ink.decoration! as BoxDecoration;
      expect(
        inkDecoration.color,
        AppPalette.dark.brandCreamCard,
        reason:
            'LearningTrackCard must resolve its card colour through '
            'context.colors.brandCreamCard, not a hardcoded Colors.white '
            '(run-9, 5564).',
      );

      final accentSquares = tester
          .widgetList<Container>(
            find.descendant(
              of: find.byType(LearningTrackCard),
              matching: find.byType(Container),
            ),
          )
          .where((c) => c.decoration is BoxDecoration)
          .map((c) => (c.decoration! as BoxDecoration).color)
          .whereType<Color>();

      expect(
        accentSquares,
        contains(AppPalette.dark.blueMedium),
        reason: 'The icon-square fill must be the pinned-deep dark blueMedium.',
      );
      // The pre-fix dark value (a washed-out pastel) must never appear —
      // it is what put a white icon at ~1.6:1 on this exact square.
      expect(accentSquares, isNot(contains(const Color(0xFFAFBEE8))));

      // LearningTrackCard's provider tree schedules a debounce/stream timer
      // that outlives a bare pump — swap in an empty tree before the test
      // ends so the binding doesn't flag it as still pending.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });
  });
}
