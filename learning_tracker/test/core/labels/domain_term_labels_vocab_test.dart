// Regression test for the B1 three-tier vocabulary added to
// `lib/core/labels/domain_term_labels.dart`.
//
// W2-A Task #13 — Vocabulary sweep + Hebrew Terms toggle wiring.
//
// For each new vocab field, this test asserts the Hebrew Terms toggle
// controls **script** (not concept) — the Latin form is returned when the
// toggle is OFF, the Hebrew script form is returned when it is ON. Each
// expectation is driven through a real `ProviderContainer` so the
// production `useHebrewTermsProvider` is exercised.
//
// Per repo guidance — never re-implement the logic under test and assert
// against its own copy. We pin the expected canonical strings to the
// design-doc table (`docs/planning/progress-ia-redesign.md`) explicitly.
library;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/labels/domain_term_labels.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pumps a [ProviderScope] + [Consumer] and yields a [DomainTermLabels]-shaped
/// callable that resolves a vocab field. We capture into a return slot so
/// the synchronous test can assert against the rendered value.
Future<T> _renderWithToggle<T>({
  required WidgetTester tester,
  required bool hebrewOn,
  required T Function(WidgetRef ref) extract,
}) async {
  SharedPreferences.setMockInitialValues({'hebrew_terms_script_p0': hebrewOn});
  T? captured;
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: Consumer(
            builder: (context, ref, _) {
              captured = extract(ref);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return captured as T;
}

void main() {
  // ── Concept vocabulary (singular + plural) ──────────────────────────────

  group('B1 vocab — concept terms swap script via toggle', () {
    final cases = <_VocabCase>[
      _VocabCase('limud', en: 'Limud', he: 'לימוד', read: (r) => domainTermLabels(r).limud),
      _VocabCase('chazara', en: 'Chazara', he: 'חזרה', read: (r) => domainTermLabels(r).chazara),
      _VocabCase('chazaros', en: 'Chazaros', he: 'חזרות', read: (r) => domainTermLabels(r).chazaros),
      _VocabCase('siyum', en: 'Siyum', he: 'סיום', read: (r) => domainTermLabels(r).siyum),
      _VocabCase('siyumim', en: 'Siyumim', he: 'סיומים', read: (r) => domainTermLabels(r).siyumim),
      _VocabCase('milestone', en: 'Milestone', he: 'הישג', read: (r) => domainTermLabels(r).milestone),
      _VocabCase('milestoneAggregate', en: 'Milestones', he: 'הישגים', read: (r) => domainTermLabels(r).milestoneAggregate),
      _VocabCase('streakLabel', en: 'Streak', he: 'רצף', read: (r) => domainTermLabels(r).streakLabel),
      _VocabCase('today', en: 'Today', he: 'היום', read: (r) => domainTermLabels(r).today),
      _VocabCase('trackProgress', en: 'Track progress', he: 'התקדמות מסלול', read: (r) => domainTermLabels(r).trackProgress),
      _VocabCase('lifetimeLabel', en: 'Lifetime', he: 'ידע כולל', read: (r) => domainTermLabels(r).lifetimeLabel),
    ];
    for (final c in cases) {
      testWidgets('${c.name} — Hebrew OFF returns Latin "${c.en}"', (
        tester,
      ) async {
        final got = await _renderWithToggle(
          tester: tester,
          hebrewOn: false,
          extract: c.read,
        );
        expect(got, c.en);
      });
      testWidgets('${c.name} — Hebrew ON returns Hebrew script "${c.he}"', (
        tester,
      ) async {
        final got = await _renderWithToggle(
          tester: tester,
          hebrewOn: true,
          extract: c.read,
        );
        expect(got, c.he);
      });
    }
  });

  // ── Three-lens labels + recent-activity-short ───────────────────────────

  group('B1 vocab — three-lens labels swap script via toggle', () {
    final cases = <_VocabCase>[
      _VocabCase(
        'tierLensRecentActivity',
        en: 'Recent Activity',
        he: 'פעילות אחרונה',
        read: (r) => domainTermLabels(r).tierLensRecentActivity,
      ),
      _VocabCase(
        'tierLensSiyumimMilestones',
        en: 'Siyumim & Milestones',
        he: 'סיומים והישגים',
        read: (r) => domainTermLabels(r).tierLensSiyumimMilestones,
      ),
      _VocabCase(
        'tierLensLifetimeKnowledge',
        en: 'Lifetime Knowledge',
        he: 'ידע כולל',
        read: (r) => domainTermLabels(r).tierLensLifetimeKnowledge,
      ),
      _VocabCase(
        'recentActivityShort',
        en: 'Recent Activity',
        he: 'פעילות אחרונה',
        read: (r) => domainTermLabels(r).recentActivityShort,
      ),
    ];
    for (final c in cases) {
      testWidgets('${c.name} — Hebrew OFF returns Latin "${c.en}"', (
        tester,
      ) async {
        final got = await _renderWithToggle(
          tester: tester,
          hebrewOn: false,
          extract: c.read,
        );
        expect(got, c.en);
      });
      testWidgets('${c.name} — Hebrew ON returns Hebrew script "${c.he}"', (
        tester,
      ) async {
        final got = await _renderWithToggle(
          tester: tester,
          hebrewOn: true,
          extract: c.read,
        );
        expect(got, c.he);
      });
    }
  });

  // ── Tier counters (parameterised) ───────────────────────────────────────

  group('B1 vocab — tier counters swap script via toggle', () {
    testWidgets('tierCounterStreakDays(6) — Hebrew OFF', (tester) async {
      final got = await _renderWithToggle(
        tester: tester,
        hebrewOn: false,
        extract: (r) => domainTermLabels(r).tierCounterStreakDays(6),
      );
      expect(got, '6-day streak');
    });
    testWidgets('tierCounterStreakDays(6) — Hebrew ON', (tester) async {
      final got = await _renderWithToggle(
        tester: tester,
        hebrewOn: true,
        extract: (r) => domainTermLabels(r).tierCounterStreakDays(6),
      );
      expect(got, 'רצף של 6 ימים');
    });

    testWidgets('tierCounterSiyumimEarned(4) — Hebrew OFF', (tester) async {
      final got = await _renderWithToggle(
        tester: tester,
        hebrewOn: false,
        extract: (r) => domainTermLabels(r).tierCounterSiyumimEarned(4),
      );
      expect(got, '4 siyumim earned');
    });
    testWidgets('tierCounterSiyumimEarned(4) — Hebrew ON', (tester) async {
      final got = await _renderWithToggle(
        tester: tester,
        hebrewOn: true,
        extract: (r) => domainTermLabels(r).tierCounterSiyumimEarned(4),
      );
      expect(got, '4 סיומים');
    });

    testWidgets('tierCounterLifetimeItems(1336) — Hebrew OFF', (tester) async {
      final got = await _renderWithToggle(
        tester: tester,
        hebrewOn: false,
        extract: (r) => domainTermLabels(r).tierCounterLifetimeItems(1336),
      );
      expect(got, '1336 items in lifetime');
    });
    testWidgets('tierCounterLifetimeItems(1336) — Hebrew ON', (tester) async {
      final got = await _renderWithToggle(
        tester: tester,
        hebrewOn: true,
        extract: (r) => domainTermLabels(r).tierCounterLifetimeItems(1336),
      );
      expect(got, '1336 פריטים בידע');
    });

    testWidgets('tierCounterPoints(1250) — Hebrew OFF', (tester) async {
      final got = await _renderWithToggle(
        tester: tester,
        hebrewOn: false,
        extract: (r) => domainTermLabels(r).tierCounterPoints(1250),
      );
      expect(got, '1250 pts');
    });
    testWidgets('tierCounterPoints(1250) — Hebrew ON', (tester) async {
      final got = await _renderWithToggle(
        tester: tester,
        hebrewOn: true,
        extract: (r) => domainTermLabels(r).tierCounterPoints(1250),
      );
      expect(got, '1250 נקודות');
    });

    testWidgets('itemsLearnedCount(1336) — Hebrew OFF', (tester) async {
      final got = await _renderWithToggle(
        tester: tester,
        hebrewOn: false,
        extract: (r) => domainTermLabels(r).itemsLearnedCount(1336),
      );
      expect(got, '1336 items learned');
    });
    testWidgets('itemsLearnedCount(1336) — Hebrew ON', (tester) async {
      final got = await _renderWithToggle(
        tester: tester,
        hebrewOn: true,
        extract: (r) => domainTermLabels(r).itemsLearnedCount(1336),
      );
      expect(got, '1336 פריטים נלמדו');
    });

    testWidgets('totalChazaros(2400) — Hebrew OFF', (tester) async {
      final got = await _renderWithToggle(
        tester: tester,
        hebrewOn: false,
        extract: (r) => domainTermLabels(r).totalChazaros(2400),
      );
      expect(got, '2400 total chazaros');
    });
    testWidgets('totalChazaros(2400) — Hebrew ON', (tester) async {
      final got = await _renderWithToggle(
        tester: tester,
        hebrewOn: true,
        extract: (r) => domainTermLabels(r).totalChazaros(2400),
      );
      expect(got, '2400 חזרות סה״כ');
    });
  });

  // ── Per-curriculum siyum labels (top + mid level, getters) ──────────────

  group('B1 vocab — per-curriculum siyum getters swap script via toggle', () {
    final cases = <_VocabCase>[
      _VocabCase('siyumHaShas', en: 'Siyum HaShas', he: 'סיום הש״ס', read: (r) => domainTermLabels(r).siyumHaShas),
      _VocabCase('siyumHaTorah', en: 'Siyum HaTorah', he: 'סיום התורה', read: (r) => domainTermLabels(r).siyumHaTorah),
      _VocabCase('siyumHaMishnayos', en: 'Siyum HaMishnayos', he: 'סיום המשניות', read: (r) => domainTermLabels(r).siyumHaMishnayos),
      _VocabCase('siyumHaYerushalmi', en: 'Siyum HaYerushalmi', he: 'סיום הירושלמי', read: (r) => domainTermLabels(r).siyumHaYerushalmi),
      _VocabCase('siyumMishnaBerurah', en: 'Siyum Mishna Berurah', he: 'סיום משנה ברורה', read: (r) => domainTermLabels(r).siyumMishnaBerurah),
      _VocabCase('siyumMishnehTorah', en: 'Siyum Mishneh Torah', he: 'סיום משנה תורה', read: (r) => domainTermLabels(r).siyumMishnehTorah),
      _VocabCase('siyumNach', en: 'Siyum Nach', he: 'סיום נ״ך', read: (r) => domainTermLabels(r).siyumNach),
      _VocabCase('siyumTanach', en: 'Siyum Tanach', he: 'סיום תנ״ך', read: (r) => domainTermLabels(r).siyumTanach),
      _VocabCase('siyumMussar', en: 'Siyum Mussar', he: 'סיום מוסר', read: (r) => domainTermLabels(r).siyumMussar),
      _VocabCase('siyumSeder', en: 'Siyum Seder', he: 'סיום סדר', read: (r) => domainTermLabels(r).siyumSeder),
      _VocabCase('siyumChelek', en: 'Siyum Chelek', he: 'סיום חלק', read: (r) => domainTermLabels(r).siyumChelek),
    ];
    for (final c in cases) {
      testWidgets('${c.name} — Hebrew OFF returns Latin "${c.en}"', (
        tester,
      ) async {
        final got = await _renderWithToggle(
          tester: tester,
          hebrewOn: false,
          extract: c.read,
        );
        expect(got, c.en);
      });
      testWidgets('${c.name} — Hebrew ON returns Hebrew script "${c.he}"', (
        tester,
      ) async {
        final got = await _renderWithToggle(
          tester: tester,
          hebrewOn: true,
          extract: c.read,
        );
        expect(got, c.he);
      });
    }
  });

  // ── Per-curriculum siyum labels (unit level, parameterised) ─────────────

  group('B1 vocab — unit-level siyum methods accept name + swap script', () {
    testWidgets('siyumMasechta(Berachos) — Hebrew OFF', (tester) async {
      final got = await _renderWithToggle(
        tester: tester,
        hebrewOn: false,
        extract: (r) => domainTermLabels(r).siyumMasechta('Berachos'),
      );
      expect(got, 'Siyum Masechta Berachos');
    });
    testWidgets('siyumMasechta(ברכות) — Hebrew ON', (tester) async {
      final got = await _renderWithToggle(
        tester: tester,
        hebrewOn: true,
        extract: (r) => domainTermLabels(r).siyumMasechta('ברכות'),
      );
      expect(got, 'סיום מסכת ברכות');
    });

    testWidgets('siyumSefer(Bereishis) — Hebrew OFF', (tester) async {
      final got = await _renderWithToggle(
        tester: tester,
        hebrewOn: false,
        extract: (r) => domainTermLabels(r).siyumSefer('Bereishis'),
      );
      expect(got, 'Siyum Sefer Bereishis');
    });
    testWidgets('siyumSefer(בראשית) — Hebrew ON', (tester) async {
      final got = await _renderWithToggle(
        tester: tester,
        hebrewOn: true,
        extract: (r) => domainTermLabels(r).siyumSefer('בראשית'),
      );
      expect(got, 'סיום ספר בראשית');
    });

    testWidgets('siyumSiman(242) — Hebrew OFF', (tester) async {
      final got = await _renderWithToggle(
        tester: tester,
        hebrewOn: false,
        extract: (r) => domainTermLabels(r).siyumSiman('242'),
      );
      expect(got, 'Siyum Siman 242');
    });
    testWidgets('siyumSiman(רמב) — Hebrew ON', (tester) async {
      final got = await _renderWithToggle(
        tester: tester,
        hebrewOn: true,
        extract: (r) => domainTermLabels(r).siyumSiman('רמב'),
      );
      expect(got, 'סיום סימן רמב');
    });

    testWidgets('siyumHilchos(Shabbos) — Hebrew OFF', (tester) async {
      final got = await _renderWithToggle(
        tester: tester,
        hebrewOn: false,
        extract: (r) => domainTermLabels(r).siyumHilchos('Shabbos'),
      );
      expect(got, 'Siyum Hilchos Shabbos');
    });
    testWidgets('siyumHilchos(שבת) — Hebrew ON', (tester) async {
      final got = await _renderWithToggle(
        tester: tester,
        hebrewOn: true,
        extract: (r) => domainTermLabels(r).siyumHilchos('שבת'),
      );
      expect(got, 'סיום הלכות שבת');
    });
  });
}

class _VocabCase {
  const _VocabCase(this.name, {required this.en, required this.he, required this.read});
  final String name;
  final String en;
  final String he;
  final String Function(WidgetRef ref) read;
}
