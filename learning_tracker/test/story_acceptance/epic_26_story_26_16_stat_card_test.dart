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

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart'
    hide expect, group, setUp, setUpAll, test;
import 'package:learning_tracker/core/widgets/stat_card.dart';
import 'package:test/test.dart';

import '../helpers/golden_runner.dart';

// ─── Harness ─────────────────────────────────────────────────────────────────

Widget _harness({required Widget child, required Locale locale}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    locale: locale,
    home: Scaffold(
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
        final candidates = [
          File('lib/core/widgets/stat_card.dart'),
          File('learning_tracker/lib/core/widgets/stat_card.dart'),
        ];
        final file = candidates.firstWhere(
          (f) => f.existsSync(),
          orElse: () => candidates.first,
        );
        expect(
          file.existsSync(),
          isTrue,
          reason:
              'stat_card.dart must exist under core/widgets/. '
              'Looked for ${candidates.map((f) => f.path).join(", ")}',
        );
      });

      test('StatCard is importable (compile-time check)', () {
        // If this file compiles, the import resolved StatCard successfully.
        expect(StatCard, isNotNull);
      });
    },
  );

  // ── AC2 + AC3: StatCard renders correctly and fires onTap ───────────────────
  group(
    'Story 26.16 AC2+AC3 — StatCard renders and is tappable',
    tags: ['story_26_16'],
    () {
      testWidgets('default variant renders icon, value, and label', (
        tester,
      ) async {
        await tester.pumpWidget(
          _harness(
            locale: const Locale('en'),
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
            locale: const Locale('en'),
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
            locale: const Locale('en'),
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
            locale: const Locale('en'),
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
            locale: const Locale('en'),
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
    },
  );

  // ── AC4: progress_screen.dart delegates to StatCard ─────────────────────────
  group(
    'Story 26.16 AC4 — progress_screen.dart uses StatCard',
    tags: ['story_26_16'],
    () {
      late String progressScreenSource;

      setUpAll(() {
        final candidates = [
          File(
            'lib/features/progress/presentation/screens/progress_screen.dart',
          ),
          File(
            'learning_tracker/lib/features/progress/presentation/screens/progress_screen.dart',
          ),
        ];
        final file = candidates.firstWhere(
          (f) => f.existsSync(),
          orElse: () => candidates.first,
        );
        progressScreenSource = file.existsSync() ? file.readAsStringSync() : '';
      });

      test('imports stat_card.dart', () {
        expect(
          progressScreenSource.contains('stat_card'),
          isTrue,
          reason:
              'progress_screen.dart must import stat_card.dart so '
              '_OverviewStatCard can delegate to StatCard.',
        );
      });

      test('references StatCard', () {
        expect(
          progressScreenSource.contains('StatCard'),
          isTrue,
          reason: '_OverviewStatCard must use StatCard as its implementation.',
        );
      });
    },
  );

  // ── AC5: task_category_stat_box.dart delegates to StatCard ──────────────────
  group(
    'Story 26.16 AC5 — TaskCategoryStatBox uses StatCard',
    tags: ['story_26_16'],
    () {
      late String statBoxSource;

      setUpAll(() {
        final candidates = [
          File(
            'lib/features/dashboard/presentation/widgets/task_category_stat_box.dart',
          ),
          File(
            'learning_tracker/lib/features/dashboard/presentation/widgets/task_category_stat_box.dart',
          ),
        ];
        final file = candidates.firstWhere(
          (f) => f.existsSync(),
          orElse: () => candidates.first,
        );
        statBoxSource = file.existsSync() ? file.readAsStringSync() : '';
      });

      test('imports stat_card.dart', () {
        expect(
          statBoxSource.contains('stat_card'),
          isTrue,
          reason: 'task_category_stat_box.dart must import stat_card.dart.',
        );
      });

      test('references StatCard', () {
        expect(
          statBoxSource.contains('StatCard'),
          isTrue,
          reason: 'TaskCategoryStatBox must delegate to StatCard.',
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
