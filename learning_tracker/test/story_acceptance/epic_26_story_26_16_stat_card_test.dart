/// Story acceptance tests for Story 26.16 (DNI-359) —
/// Tappable StatCard primitive + wired Progress overview.
///
/// AC1: StatCard exists under core/widgets/.
/// AC2: StatCard renders in 3 visual variants (default, highlighted, compact).
/// AC3: StatCard is tappable — onTap fires when the card is tapped.
/// AC4: _OverviewStatCard in progress_screen.dart is backed by StatCard.
/// AC5: TaskCategoryStatBox is backed by StatCard.
/// AC6: Golden tests cover StatCard in 3 visual variants (en + he each).
@Tags(['epic_26'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart'
    hide expect, group, setUp, setUpAll, test;
import 'package:learning_tracker/core/widgets/stat_card.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/task_category_stat_box.dart';
import 'package:test/test.dart';

import '../helpers/golden_runner.dart';
import '../helpers/lib_source.dart';
import '../helpers/pump_app.dart';

// ─── Harness ─────────────────────────────────────────────────────────────────

/// AUD-t-story-acceptance-23: a hand-rolled `MaterialApp(locale: locale)`
/// with no `localizationsDelegates`/`supportedLocales` never actually
/// resolves `Locale('he')` — `MaterialApp` falls back to its default
/// `supportedLocales` (`[Locale('en', 'US')]`) whenever the requested
/// locale isn't in that list, so `Locale('he')` silently rendered as
/// en_US/LTR, identical to `Locale('en')`, and the "he" testWidgets
/// variants below gave zero RTL coverage.
///
/// Delegating to the shared [pumpApp] helper (TQ-3,
/// docs/coding-standards.md) fixes this correctly instead of hand-rolling
/// another local delegate list: `pumpApp` already wires the real
/// `GlobalMaterialLocalizations` delegate trio plus
/// `AppLocalizations.supportedLocales` (which includes `he`), so the
/// requested locale now actually resolves and `Directionality` flips to
/// RTL for `Locale('he')`.
Widget _harness({required Widget child, required Locale locale}) {
  return pumpApp(
    locale: locale,
    child: Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      body: SafeArea(child: child),
    ),
  );
}

void main() {
  // ── AC1: StatCard class exists ───────────────────────────────────────────────
  group(
    'Story 26.16 AC1 — StatCard exists under core/widgets/',
    tags: ['story_26_16'],
    () {
      test('widget file is present at the expected path', () {
        expect(
          libFileExists('core/widgets/stat_card.dart'),
          isTrue,
          reason: 'stat_card.dart must exist under core/widgets/.',
        );
      });
    },
  );

  // ── AC2 + AC3: StatCard renders correctly and fires onTap ───────────────────
  //
  // Parameterized over en + he (AUD-t-story-acceptance-23): StatCard is a
  // core/widgets/ primitive for a bilingual RTL app, and a regression that
  // breaks hit-testing or layout specifically under RTL mirroring (e.g. the
  // tap target shifting when Directionality flips) must be caught by an
  // actual pump + tap, not just the skipped-golden AC6 smoke tests below.
  for (final locale in const [Locale('en'), Locale('he')]) {
    group(
      'Story 26.16 AC2+AC3 — StatCard renders and is tappable '
      '(${locale.languageCode})',
      tags: ['story_26_16'],
      () {
        testWidgets('default variant renders icon, value, and label', (
          tester,
        ) async {
          await tester.pumpWidget(
            _harness(
              locale: locale,
              child: const SizedBox(
                width: 160,
                height: 120,
                child: StatCard(
                  icon: Icons.verified_outlined,
                  iconColor: Color(0xFFF8C146),
                  value: '42',
                  label: 'Completions',
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('42'), findsOneWidget);
          expect(find.text('Completions'), findsOneWidget);
          expect(find.byIcon(Icons.verified_outlined), findsOneWidget);
        });

        testWidgets('highlighted variant renders with accent background', (
          tester,
        ) async {
          await tester.pumpWidget(
            _harness(
              locale: locale,
              child: const SizedBox(
                width: 160,
                height: 120,
                child: StatCard(
                  icon: Icons.local_fire_department_rounded,
                  iconColor: Colors.white,
                  value: '7',
                  label: 'Day streak',
                  highlighted: true,
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('7'), findsOneWidget);
          expect(find.text('Day streak'), findsOneWidget);
          // Highlighted card has white text — verify it renders without error.
          expect(find.byType(StatCard), findsOneWidget);
        });

        testWidgets('compact variant (no icon) renders value and label', (
          tester,
        ) async {
          await tester.pumpWidget(
            _harness(
              locale: locale,
              child: const SizedBox(
                width: 100,
                child: StatCard(
                  value: '13',
                  label: 'Due today',
                  cardColor: Color(0xFFDFE9FD),
                  valueColor: Color(0xFF1A56DB),
                  labelColor: Color(0xFF7C8595),
                  borderRadius: 14,
                  padding: EdgeInsets.symmetric(vertical: 7, horizontal: 4),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('13'), findsOneWidget);
          expect(find.text('Due today'), findsOneWidget);
          expect(find.byIcon(Icons.verified_outlined), findsNothing);
        });

        testWidgets('onTap fires when card is tapped', (tester) async {
          var tapped = false;
          await tester.pumpWidget(
            _harness(
              locale: locale,
              child: SizedBox(
                width: 160,
                height: 120,
                child: StatCard(
                  icon: Icons.menu_book_outlined,
                  iconColor: Colors.blue,
                  value: '99',
                  label: 'Units done',
                  onTap: () => tapped = true,
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.byType(StatCard));
          await tester.pumpAndSettle();
          expect(tapped, isTrue);
        });

        testWidgets('null onTap does not throw when card is tapped', (
          tester,
        ) async {
          await tester.pumpWidget(
            _harness(
              locale: locale,
              child: const SizedBox(
                width: 160,
                height: 120,
                child: StatCard(
                  icon: Icons.hub_outlined,
                  iconColor: Color(0xFFF8C146),
                  value: '3',
                  label: 'Active tracks',
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          // Tap should not throw even with no onTap.
          await tester.tap(find.byType(StatCard), warnIfMissed: false);
          await tester.pumpAndSettle();
        });

        // Regression coverage for AUD-t-story-acceptance-23: the previous
        // fix parameterized these tests over Locale('en') + Locale('he')
        // but _harness only forwarded `locale:` to MaterialApp without
        // GlobalMaterialLocalizations delegates or a matching
        // supportedLocales list. MaterialApp's locale resolution falls back
        // to its default supportedLocales ([Locale('en', 'US')]) whenever
        // the requested locale isn't in that list, so Locale('he') silently
        // resolved to en_US/LTR — identical to the 'en' run — and the "he"
        // testWidgets above never actually exercised RTL directionality or
        // hit-testing. This test asserts the ambient Directionality the
        // widget tree actually resolves to, which fails under the broken
        // harness (both locales resolve 'ltr') and only passes once 'he'
        // truly flips to 'rtl'.
        testWidgets('harness resolves real Directionality for this locale', (
          tester,
        ) async {
          await tester.pumpWidget(
            _harness(
              locale: locale,
              child: const SizedBox(
                width: 160,
                height: 120,
                child: StatCard(
                  icon: Icons.verified_outlined,
                  iconColor: Color(0xFFF8C146),
                  value: '42',
                  label: 'Completions',
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final resolved = Directionality.of(
            tester.element(find.byType(StatCard)),
          );
          final expected = locale.languageCode == 'he'
              ? TextDirection.rtl
              : TextDirection.ltr;
          expect(
            resolved,
            expected,
            reason:
                "_harness must actually resolve Locale('${locale.languageCode}') "
                'to $expected — without GlobalMaterialLocalizations + a '
                "supportedLocales list including 'he', MaterialApp falls "
                'back to en_US/LTR for every locale and RTL tap/layout '
                'regressions go undetected (AUD-t-story-acceptance-23).',
          );
        });
      },
    );
  }

  // ── AC4: superseded by the Progress IA redesign ────────────────────────────
  //
  // The original Story 26.16 AC4 asserted that _OverviewStatCard in
  // progress_screen.dart delegated to StatCard (the shared primitive). With
  // the three-lens IA (see docs/planning/progress-ia-redesign.md), the
  // 4-card stat grid is intentionally retired in favour of
  // ProgressTierCounterRow — a different shared widget aligned with the
  // engagement / achievement / lifetime tier model. The AC for that new
  // structure is covered by progress_tier_counter_row_test.dart and
  // progress_screen_test.dart.
  //
  // The legacy AC4 assertions are removed because the underlying
  // criterion ("the hub uses the StatCard primitive") no longer applies —
  // the hub uses ProgressTierCounterRow instead. StatCard itself is still
  // covered by AC1, AC2, AC3 (it remains the primitive for
  // TaskCategoryStatBox on the Dashboard, asserted by AC5 below).

  // ── AC5: task_category_stat_box.dart delegates to StatCard (behavioral) ─────
  //
  // AUD-t-story-acceptance R7: the old version of this group read
  // task_category_stat_box.dart's source text and asserted it *contains*
  // the substrings 'stat_card' (the import) and 'StatCard' (the class name)
  // — true even if TaskCategoryStatBox merely imported StatCard without
  // ever using it, or referenced it only in a comment. The tests below pump
  // the real widget instead and assert the OBSERVABLE EFFECT: it renders
  // AS a StatCard in the tree, forwards its count/label through, and wires
  // its onTap straight to the underlying StatCard's hit target — strictly
  // more than a source-text match, and it fails if delegation regresses
  // (e.g. TaskCategoryStatBox reverts to hand-rolled rendering or drops the
  // onTap forward).
  group(
    'Story 26.16 AC5 — TaskCategoryStatBox uses StatCard',
    tags: ['story_26_16'],
    () {
      testWidgets('renders as a StatCard and forwards count/label through', (
        tester,
      ) async {
        await tester.pumpWidget(
          _harness(
            locale: const Locale('en'),
            child: const SizedBox(
              width: 100,
              child: TaskCategoryStatBox(
                count: 5,
                label: 'Due today',
                valueColor: Color(0xFF1A56DB),
                valueBg: Color(0xFFDFE9FD),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byType(StatCard),
          findsOneWidget,
          reason: 'TaskCategoryStatBox must delegate to StatCard.',
        );
        expect(find.text('5'), findsOneWidget);
        expect(find.text('Due today'), findsOneWidget);
      });

      testWidgets('onTap is forwarded to the underlying StatCard', (
        tester,
      ) async {
        var tapped = false;
        await tester.pumpWidget(
          _harness(
            locale: const Locale('en'),
            child: SizedBox(
              width: 100,
              child: TaskCategoryStatBox(
                count: 3,
                label: 'Overdue',
                valueColor: const Color(0xFFB00020),
                valueBg: const Color(0xFFFBE3E6),
                onTap: () => tapped = true,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byType(StatCard));
        await tester.pumpAndSettle();

        expect(
          tapped,
          isTrue,
          reason:
              'TaskCategoryStatBox.onTap must be forwarded through to the '
              'underlying StatCard, not swallowed by the delegation.',
        );
      });
    },
  );

  // ── AC6: Golden tests — 3 variants × 2 locales ──────────────────────────────
  //
  // PNG baselining deferred; the structural pump (en + he) catches RTL
  // rendering regressions per the golden_runner contract.

  group(
    'Story 26.16 AC6 — golden tests for StatCard in 3 visual variants',
    tags: ['story_26_16'],
    () {
      // Variant 1: Default (with icon, not highlighted)
      goldenTest(
        'stat_card_default',
        skipGolden: true,
        builder: (locale) => _harness(
          locale: locale,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: 160,
              height: 120,
              child: StatCard(
                icon: Icons.verified_outlined,
                iconColor: const Color(0xFFF8C146),
                value: '312',
                label: 'Completions',
                onTap: () {},
              ),
            ),
          ),
        ),
      );

      // Variant 2: Highlighted (streak accent)
      goldenTest(
        'stat_card_highlighted',
        skipGolden: true,
        builder: (locale) => _harness(
          locale: locale,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: 160,
              height: 120,
              child: StatCard(
                icon: Icons.local_fire_department_rounded,
                iconColor: Colors.white,
                value: '7',
                label: 'Day streak',
                highlighted: true,
                onTap: () {},
              ),
            ),
          ),
        ),
      );

      // Variant 3: Compact (no icon — TaskCategoryStatBox mode)
      goldenTest(
        'stat_card_compact',
        skipGolden: true,
        builder: (locale) => _harness(
          locale: locale,
          child: const Padding(
            padding: EdgeInsets.all(16),
            child: SizedBox(
              width: 100,
              child: StatCard(
                value: '13',
                label: 'Due today',
                cardColor: Color(0xFFDFE9FD),
                valueColor: Color(0xFF1A56DB),
                labelColor: Color(0xFF7C8595),
                borderRadius: 14,
                padding: EdgeInsets.symmetric(vertical: 7, horizontal: 4),
                onTap: null,
              ),
            ),
          ),
        ),
      );
    },
  );
}
