// Runtime-confidence layer for the Hebrew-terms enforcement.
//
// Proves Torah domain terms render in the correct script/nusach across all
// THREE modes, end-to-end at the widget level:
//
//   Mode A  Hebrew-terms ON                       → Hebrew script (משניות …)
//   Mode B  Hebrew-terms OFF + nusach Ashkenazi   → Mishnayos / Masechtos / Dafim
//   Mode C  Hebrew-terms OFF + nusach Sephardi     → Mishnayot / Masekhtot / Dapim
//
// Three layers of coverage:
//   1. Shared library, table-driven: CurriculumLabels.primaryUnitLabel /
//      .containerCountLabel pumped through a tiny ConsumerWidget reading the
//      live providers (the same path real screens use).
//   2. domainTermLabels(ref): .chazara and .shabbos(variant:) across 3 modes.
//   3. Two real fixed screens pumped in all 3 modes:
//        • CurriculumListScreen — the count labels (container + unit).
//        • ScopeSelectionScreen — the level WORD for chumash ("Sefer" / "חומש").
//
// Assertions are deliberately robust: find.textContaining the expected term
// form, and find.textContaining absence of the WRONG-nusach form, rather than
// brittle exact-layout matching.

@Tags(['labels', 'hebrew_terms'])
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/labels/domain_term_labels.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/content_browsing/presentation/screens/curriculum_list_screen.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/settings/presentation/screens/scope_selection_screen.dart';
import 'package:learning_tracker/features/sync/presentation/providers/sync_providers.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

// ── Mocks ────────────────────────────────────────────────────────────────────

class _MockContentRepository extends Mock implements ContentRepository {}

// ── Provider notifier overrides ──────────────────────────────────────────────

class _ProfileId1 extends ActiveProfileId {
  @override
  int build() => 1;
}

class _HebrewTermsOn extends UseHebrewTerms {
  @override
  bool build() => true;
}

class _HebrewTermsOff extends UseHebrewTerms {
  @override
  bool build() => false;
}

class _VariantAshkenazi extends CurrentTransliterationVariant {
  @override
  TransliterationVariant build() => TransliterationVariant.ashkenazi;
}

class _VariantSephardi extends CurrentTransliterationVariant {
  @override
  TransliterationVariant build() => TransliterationVariant.sephardi;
}

// ── The three modes ──────────────────────────────────────────────────────────

enum _Mode { hebrew, ashkenazi, sephardi }

extension on _Mode {
  String get label => switch (this) {
    _Mode.hebrew => 'Hebrew-terms ON',
    _Mode.ashkenazi => 'OFF + Ashkenazi',
    _Mode.sephardi => 'OFF + Sephardi',
  };

  List<Override> get providerOverrides => <Override>[
    if (this == _Mode.hebrew)
      useHebrewTermsProvider.overrideWith(() => _HebrewTermsOn())
    else
      useHebrewTermsProvider.overrideWith(() => _HebrewTermsOff()),
    if (this == _Mode.sephardi)
      currentTransliterationVariantProvider.overrideWith(
        () => _VariantSephardi(),
      )
    else
      currentTransliterationVariantProvider.overrideWith(
        () => _VariantAshkenazi(),
      ),
  ];

  Locale get locale =>
      this == _Mode.hebrew ? const Locale('he') : const Locale('en');
}

// ── Tiny harness for the shared-library layer ────────────────────────────────

/// Renders a label string produced by a [build] callback that reads the live
/// providers — exactly the path real screens use — so the assertion exercises
/// the toggle + nusach wiring end-to-end, not a bare function call.
class _LabelProbe extends ConsumerWidget {
  const _LabelProbe(this.resolve);

  final String Function(WidgetRef ref) resolve;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Text(resolve(ref)),
    );
  }
}

Future<void> _pumpProbe(
  WidgetTester tester,
  _Mode mode,
  String Function(WidgetRef ref) resolve,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: mode.providerOverrides,
      child: _LabelProbe(resolve),
    ),
  );
  await tester.pump();
}

// ── Content-repo factory (single Mishnayos container + leaf) ─────────────────

const _kMishnayosContainerLeaf = <ContentItem>[
  ContentItem(
    curriculumId: 'mishnayos',
    level1: 'Zeraim',
    displayNameHe: 'מסכת ברכות',
    displayNameEn: 'Berachos',
    sefariaRef: 'Mishnah Berakhot',
    sortOrder: 0,
    isLeaf: false,
  ),
  ContentItem(
    curriculumId: 'mishnayos',
    level1: 'Zeraim',
    level2: 'Berachos',
    displayNameHe: 'משנה א',
    displayNameEn: 'Mishnah 1',
    sefariaRef: 'Mishnah Berakhot 1:1',
    sortOrder: 1,
    isLeaf: true,
  ),
];

/// Chumash fixture — level-1 Sefer is the named book "Genesis" (raw storage
/// key). The scope screen renders the level WORD "Sefer" (en) / "חומש" (he).
final _kChumashItems = <ContentItem>[
  const ContentItem(
    curriculumId: 'chumash',
    level1: 'Genesis',
    displayNameHe: 'בראשית',
    displayNameEn: 'Genesis',
    sefariaRef: 'Genesis',
    sortOrder: 0,
    isLeaf: false,
  ),
  const ContentItem(
    curriculumId: 'chumash',
    level1: 'Genesis',
    level2: '1',
    displayNameHe: 'א',
    displayNameEn: '1',
    sefariaRef: 'Genesis.1',
    sortOrder: 1,
    isLeaf: false,
  ),
  const ContentItem(
    curriculumId: 'chumash',
    level1: 'Genesis',
    level2: '1',
    level3: '1',
    displayNameHe: 'א',
    displayNameEn: '1',
    sefariaRef: 'Genesis.1.1',
    sortOrder: 2,
    isLeaf: true,
  ),
];

_MockContentRepository _makeRepoFor(
  CurriculumId target,
  List<ContentItem> items,
) {
  final repo = _MockContentRepository();
  for (final c in CurriculumId.values) {
    when(
      () => repo.getContentForCurriculum(c),
    ).thenAnswer((_) async => c == target ? items : <ContentItem>[]);
  }
  when(
    () => repo.getScopedContent(
      curriculumId: any<CurriculumId>(named: 'curriculumId'),
      scopeLevel: any<int>(named: 'scopeLevel'),
      scopeValues: any<List<String>>(named: 'scopeValues'),
    ),
  ).thenAnswer((_) async => items);
  when(
    () => repo.filterByLevel(
      curriculumId: any<CurriculumId>(named: 'curriculumId'),
      level1: any<String>(named: 'level1'),
      level2: any<String>(named: 'level2'),
      level3: any<String>(named: 'level3'),
      level4: any<String>(named: 'level4'),
    ),
  ).thenAnswer((_) async => items);
  when(
    () => repo.search(
      curriculumId: any<CurriculumId>(named: 'curriculumId'),
      query: any<String>(named: 'query'),
    ),
  ).thenAnswer((_) async => <ContentItem>[]);
  when(
    () => repo.getContentByRef(
      curriculumId: any<CurriculumId>(named: 'curriculumId'),
      sefariaRef: any<String>(named: 'sefariaRef'),
    ),
  ).thenAnswer((_) async => null);
  return repo;
}

// ── Real-screen widget factories ─────────────────────────────────────────────

Widget _buildCurriculumListApp(_Mode mode, ContentRepository repo) {
  return ProviderScope(
    overrides: [
      ...mode.providerOverrides,
      contentRepositoryProvider.overrideWithValue(repo),
      dashboardCompletionPercentageProvider.overrideWith(
        (ref, curriculum) async => 0.0,
      ),
    ],
    child: const MaterialApp(home: CurriculumListScreen()),
  );
}

Widget _buildScopeApp(
  _Mode mode,
  UserDatabase db,
  ContentRepository repo,
  CurriculumId curriculum,
) {
  return ProviderScope(
    overrides: [
      ...mode.providerOverrides,
      userDatabaseProvider.overrideWith((ref) => db),
      activeProfileIdProvider.overrideWith(() => _ProfileId1()),
      syncWriteFacadeProvider.overrideWithValue(null),
      outboxSyncWriteFacadeProvider.overrideWithValue(null),
      contentRepositoryProvider.overrideWithValue(repo),
    ],
    child: MaterialApp(
      locale: mode.locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: ScopeSelectionScreen(curriculumId: curriculum),
    ),
  );
}

// ── Main ───────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() {
    registerFallbackValue(CurriculumId.mishnayos);
    registerFallbackValue(0);
    registerFallbackValue(<String>[]);
    registerFallbackValue('');
  });

  // ═════════════════════════════════════════════════════════════════════════
  // Layer 1 — shared library: CurriculumLabels via the live-provider path.
  // ═════════════════════════════════════════════════════════════════════════
  //
  // Matrix: { Mishnayos unit, Mishnayos container, Bavli unit } × 3 modes.
  // Expected forms are the canonical drift-free forms from hebrew-terms.md.

  group('Layer 1 — CurriculumLabels (shared path, table-driven)', () {
    // (curriculum, isContainer, {mode -> expected}, {mode -> wrongForms})
    final cases = <_LabelCase>[
      // Mishnayos primary unit: Mishnayos / Mishnayot / משניות.
      _LabelCase(
        name: 'Mishnayos primary unit',
        build: (ref) => CurriculumLabels.primaryUnitLabel(
          CurriculumId.mishnayos,
          useHebrew: domainTermLabels(ref).isHebrew,
          variant: ref.watch(currentTransliterationVariantProvider),
        ),
        expected: {
          _Mode.hebrew: 'משניות',
          _Mode.ashkenazi: 'Mishnayos',
          _Mode.sephardi: 'Mishnayot',
        },
        absent: {
          _Mode.hebrew: ['Mishnayos', 'Mishnayot'],
          _Mode.ashkenazi: ['Mishnayot', 'משניות'],
          _Mode.sephardi: ['Mishnayos', 'משניות'],
        },
      ),
      // Mishnayos container count: Masechtos / Masekhtot / מסכתות.
      _LabelCase(
        name: 'Mishnayos container',
        build: (ref) => CurriculumLabels.containerCountLabel(
          CurriculumId.mishnayos,
          useHebrew: domainTermLabels(ref).isHebrew,
          variant: ref.watch(currentTransliterationVariantProvider),
        ),
        expected: {
          _Mode.hebrew: 'מסכתות',
          _Mode.ashkenazi: 'Masechtos',
          _Mode.sephardi: 'Masekhtot',
        },
        absent: {
          _Mode.hebrew: ['Masechtos', 'Masekhtot'],
          _Mode.ashkenazi: ['Masekhtot', 'מסכתות'],
          _Mode.sephardi: ['Masechtos', 'מסכתות'],
        },
      ),
      // Bavli primary unit: Dafim / Dapim / דפים.
      _LabelCase(
        name: 'Bavli primary unit (Daf)',
        build: (ref) => CurriculumLabels.primaryUnitLabel(
          CurriculumId.bavli,
          useHebrew: domainTermLabels(ref).isHebrew,
          variant: ref.watch(currentTransliterationVariantProvider),
        ),
        expected: {
          _Mode.hebrew: 'דפים',
          _Mode.ashkenazi: 'Dafim',
          _Mode.sephardi: 'Dapim',
        },
        absent: {
          _Mode.hebrew: ['Dafim', 'Dapim'],
          _Mode.ashkenazi: ['Dapim', 'דפים'],
          _Mode.sephardi: ['Dafim', 'דפים'],
        },
      ),
    ];

    for (final c in cases) {
      for (final mode in _Mode.values) {
        testWidgets('${c.name} — ${mode.label}', (tester) async {
          await _pumpProbe(tester, mode, c.build);

          expect(
            find.textContaining(c.expected[mode]!),
            findsOneWidget,
            reason:
                '${c.name} in ${mode.label} should show '
                '"${c.expected[mode]}"',
          );
          for (final wrong in c.absent[mode]!) {
            expect(
              find.textContaining(wrong),
              findsNothing,
              reason: '${c.name} in ${mode.label} must NOT leak "$wrong"',
            );
          }
        });
      }
    }
  });

  // ═════════════════════════════════════════════════════════════════════════
  // Layer 2 — domainTermLabels(ref): chazara + shabbos across 3 modes.
  // ═════════════════════════════════════════════════════════════════════════

  group('Layer 2 — domainTermLabels(ref)', () {
    const chazaraExpected = {
      _Mode.hebrew: 'חזרה',
      _Mode.ashkenazi: 'Chazara',
      _Mode.sephardi: 'Chazara',
    };
    // chazara is nusach-independent in English — both nuschaot read "Chazara".
    for (final mode in _Mode.values) {
      testWidgets('chazara — ${mode.label}', (tester) async {
        await _pumpProbe(tester, mode, (ref) => domainTermLabels(ref).chazara);

        expect(find.text(chazaraExpected[mode]!), findsOneWidget);
        if (mode != _Mode.hebrew) {
          expect(find.textContaining('חזרה'), findsNothing);
        }
      });
    }

    // shabbos(variant:) — Hebrew "שבת", Ashkenazi "Shabbos", Sephardi "Shabbat".
    // domainTermLabels holds only the toggle, so the nusach is passed in — the
    // probe forwards the live currentTransliterationVariantProvider.
    const shabbosExpected = {
      _Mode.hebrew: 'שבת',
      _Mode.ashkenazi: 'Shabbos',
      _Mode.sephardi: 'Shabbat',
    };
    const shabbosAbsent = {
      _Mode.hebrew: ['Shabbos', 'Shabbat'],
      _Mode.ashkenazi: ['Shabbat', 'שבת'],
      _Mode.sephardi: ['Shabbos', 'שבת'],
    };
    for (final mode in _Mode.values) {
      testWidgets('shabbos(variant:) — ${mode.label}', (tester) async {
        await _pumpProbe(
          tester,
          mode,
          (ref) => domainTermLabels(
            ref,
          ).shabbos(variant: ref.watch(currentTransliterationVariantProvider)),
        );

        expect(find.text(shabbosExpected[mode]!), findsOneWidget);
        for (final wrong in shabbosAbsent[mode]!) {
          expect(
            find.textContaining(wrong),
            findsNothing,
            reason: 'shabbos in ${mode.label} must NOT leak "$wrong"',
          );
        }
      });
    }
  });

  // ═════════════════════════════════════════════════════════════════════════
  // Layer 3a — real screen: CurriculumListScreen count labels in all 3 modes.
  // ═════════════════════════════════════════════════════════════════════════
  //
  // The Mishnayos card renders "<n> <containerLabel>" and "<n> <unitLabel>".
  // We assert the COUNT-PREFIXED label so the card title ("Mishnayos") is not
  // mistaken for the unit-count label.

  group('Layer 3a — CurriculumListScreen count labels', () {
    final expected = {
      _Mode.hebrew: ('1 מסכתות', '1 משניות'),
      _Mode.ashkenazi: ('1 Masechtos', '1 Mishnayos'),
      _Mode.sephardi: ('1 Masekhtot', '1 Mishnayot'),
    };
    final wrongUnit = {
      _Mode.hebrew: '1 Mishnayos',
      _Mode.ashkenazi: '1 Mishnayot',
      _Mode.sephardi: '1 Mishnayos',
    };

    for (final mode in _Mode.values) {
      testWidgets('count labels switch — ${mode.label}', (tester) async {
        final repo = _makeRepoFor(
          CurriculumId.mishnayos,
          _kMishnayosContainerLeaf,
        );
        await tester.pumpWidget(_buildCurriculumListApp(mode, repo));
        await tester.pumpAndSettle();

        final (container, unit) = expected[mode]!;
        expect(
          find.textContaining(container),
          findsWidgets,
          reason: 'container count in ${mode.label} should read "$container"',
        );
        expect(
          find.textContaining(unit),
          findsWidgets,
          reason: 'unit count in ${mode.label} should read "$unit"',
        );
        expect(
          find.textContaining(wrongUnit[mode]!),
          findsNothing,
          reason: 'wrong-nusach unit count must not leak in ${mode.label}',
        );
      });
    }
  });

  // ═════════════════════════════════════════════════════════════════════════
  // Layer 3b — real screen: ScopeSelectionScreen level WORD in all 3 modes.
  // ═════════════════════════════════════════════════════════════════════════
  //
  // For chumash the level-1 WORD is "Sefer" (en, nusach-independent) / "חומש"
  // (he). The English-mode word is the same for both nuschaot, so we assert
  // Hebrew vs English switching across the three modes and confirm the raw
  // storage path is not echoed.

  group('Layer 3b — ScopeSelectionScreen level word (chumash)', () {
    late UserDatabase db;

    setUp(() => db = UserDatabase(NativeDatabase.memory()));
    tearDown(() async => db.close());

    final expectedWord = {
      _Mode.hebrew: 'חומש',
      _Mode.ashkenazi: 'Sefer',
      _Mode.sephardi: 'Sefer',
    };

    for (final mode in _Mode.values) {
      testWidgets('level word switches — ${mode.label}', (tester) async {
        final repo = _makeRepoFor(CurriculumId.chumash, _kChumashItems);
        await tester.pumpWidget(
          _buildScopeApp(mode, db, repo, CurriculumId.chumash),
        );
        // Settle the async content load.
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        // Reveal the level-selection tiles.
        await tester.tap(find.byType(SwitchListTile));
        await tester.pump();

        expect(
          find.text(expectedWord[mode]!),
          findsOneWidget,
          reason:
              'chumash level word in ${mode.label} should be '
              '"${expectedWord[mode]}"',
        );
        if (mode == _Mode.hebrew) {
          // Hebrew mode must not echo the English level word.
          expect(find.text('Sefer'), findsNothing);
        } else {
          // English modes must not show the Hebrew word.
          expect(find.text('חומש'), findsNothing);
        }

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(Duration.zero);
      });
    }
  });
}

// ── Table-driven case record ─────────────────────────────────────────────────

class _LabelCase {
  _LabelCase({
    required this.name,
    required this.build,
    required this.expected,
    required this.absent,
  });

  final String name;
  final String Function(WidgetRef ref) build;
  final Map<_Mode, String> expected;
  final Map<_Mode, List<String>> absent;
}
