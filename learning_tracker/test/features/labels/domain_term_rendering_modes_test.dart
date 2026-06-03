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
//   4. classB regression net — the surfaces the grep/lint enforcement CANNOT
//      see (a raw content VALUE in a variable/field flowed into Text()). These
//      had to be found by hand + on-device, so they are pinned here, each in
//      all three modes, asserting the term switches and the wrong-nusach form
//      is absent:
//        • HierarchyProgressCard          — seder name via level.levelName
//                                           (Taharos / Tahorot / טהרות).
//        • SiyumimGroupedView aggregate    — "Siyum Seder {name}" via
//                                           milestone.aggregateKey
//                                           (Siyum Seder Taharos / Tahorot).
//        • GoalSetupForm unit pills        — granularity pill via
//                                           CurriculumLabels (Dafim / Dapim /
//                                           דפים).
//        • SacredTimeLockOverlay           — Shabbos / Shabbat / שבת greeting.
//        • SacredTimeSettingsCard          — Shabbos / Shabbat / שבת header.
//        • track-order section header WORD — CurriculumLabels.containerSection
//                                           Header (Masechtos / Masekhtot /
//                                           מסכתות).
//        • curriculumLabelText surface     — CurriculumLabel.curriculum
//                                           (Mishnayos / Mishnayot / משניות).
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
import 'package:learning_tracker/core/labels/curriculum_label.dart';
import 'package:learning_tracker/core/labels/domain_term_labels.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/content_browsing/presentation/screens/curriculum_list_screen.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/progress/domain/models/curriculum_progress_data.dart';
import 'package:learning_tracker/features/progress/domain/models/journey_view_model.dart';
import 'package:learning_tracker/features/progress/presentation/widgets/hierarchy_progress_card.dart';
import 'package:learning_tracker/features/progress/presentation/widgets/siyumim_grouped_view.dart';
import 'package:learning_tracker/features/sacred_time/domain/models/sacred_window.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/sacred_windows_provider.dart';
import 'package:learning_tracker/features/sacred_time/presentation/widgets/sacred_time_lock_overlay.dart';
import 'package:learning_tracker/features/sacred_time/presentation/widgets/sacred_time_settings_card.dart';
import 'package:learning_tracker/features/scheduler/presentation/screens/goal_setup_screen.dart';
import 'package:learning_tracker/features/settings/presentation/screens/scope_selection_screen.dart';
import 'package:learning_tracker/features/sync/presentation/providers/sync_providers.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

/// Pins the Hebrew-date preference OFF so the goal-setup form's
/// `useHebrewDateProvider` read does not reach SharedPreferences / the active
/// profile in the lightweight Layer-4 pumps. The Hebrew-TERMS toggle (which is
/// what drives the domain-term script) is overridden separately per mode.
class _HebrewDateOff extends UseHebrewDate {
  @override
  bool build() => false;
}

/// A [CurrentSacredWindow] that always reports an active Shabbos lock window
/// and schedules NO timer — so the lock overlay renders its Shabbos greeting
/// deterministically without leaving a pending timer in the test.
class _FixedShabbosWindow extends CurrentSacredWindow {
  @override
  SacredWindow? build() => SacredWindow(
    startUtc: DateTime.utc(2026, 1, 1),
    endUtc: DateTime.utc(2026, 1, 2),
    kind: SacredWindowKind.shabbos,
  );
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

/// Mishnayos Seder-Tahoros fixture. Level-1 raw key is the Sefaria seder key
/// `'Tahorot'`; its Hebrew name `'טהרות'` lets the renderer show the Hebrew
/// form when Hebrew Terms is on, and `transliterateNamedValue` switches the
/// English form between "Taharos" (Ashkenazi) and "Tahorot" (Sephardi). Used
/// by the HierarchyProgressCard and SiyumimGroupedView aggregate surfaces,
/// which both flow a raw `levelName` / `aggregateKey` VARIABLE into Text() —
/// the classB bypass the grep gate cannot see.
const _kMishnayosTahorosItems = <ContentItem>[
  ContentItem(
    curriculumId: 'mishnayos',
    level1: 'Tahorot',
    displayNameHe: 'טהרות',
    displayNameEn: 'Taharos',
    sefariaRef: 'Mishnah Kelim',
    sortOrder: 0,
    isLeaf: false,
  ),
  ContentItem(
    curriculumId: 'mishnayos',
    level1: 'Tahorot',
    level2: 'Keilim',
    displayNameHe: 'כלים',
    displayNameEn: 'Keilim',
    sefariaRef: 'Mishnah Kelim',
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

/// Pumps an arbitrary [child] under a bare [MaterialApp] (no l10n delegates)
/// in the given [mode], optionally overriding the content repository. For
/// Layer-4 surfaces whose label resolution needs only the Hebrew-terms toggle +
/// nusach variant and (optionally) the content repo.
Widget _buildPlainApp(
  _Mode mode,
  ContentRepository? repo,
  Widget child, {
  List<Override> extraOverrides = const [],
}) {
  return ProviderScope(
    overrides: [
      ...mode.providerOverrides,
      if (repo != null) contentRepositoryProvider.overrideWithValue(repo),
      ...extraOverrides,
    ],
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

/// Like [_buildPlainApp] but wires the full localization delegates and the
/// mode's locale — required for surfaces that read `AppLocalizations` (the
/// sacred-time greeting/header templates, the siyumim subtitle, the goal-setup
/// per-day/per-week labels).
Widget _buildLocalizedApp(
  _Mode mode,
  ContentRepository? repo,
  Widget child, {
  List<Override> extraOverrides = const [],
}) {
  return ProviderScope(
    overrides: [
      ...mode.providerOverrides,
      if (repo != null) contentRepositoryProvider.overrideWithValue(repo),
      ...extraOverrides,
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
      home: Scaffold(body: child),
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

  // ═════════════════════════════════════════════════════════════════════════
  // Layer 4 — classB regression net: a raw content VALUE in a variable/field
  // flowed into Text(). These are the surfaces the grep/lint enforcement
  // CANNOT see — they had to be found by hand + on-device, so they are pinned
  // here in all three modes.
  // ═════════════════════════════════════════════════════════════════════════

  // ── 4a — HierarchyProgressCard ("Breakdown by Level" card) ──────────────────
  //
  // The card title is `renderCurriculumLevelName(ref, …, rawValue: level.level
  // Name)` — the seder name lives in a VARIABLE (HierarchyLevelProgress.level
  // Name). For Seder Tahoros that is "Taharos" (Ashkenazi) / "Tahorot"
  // (Sephardi) / "טהרות" (Hebrew). The renderer needs the curriculum content
  // (for the Hebrew name + transliteration), so the content repo is mocked.

  group('Layer 4a — HierarchyProgressCard seder name (level.levelName)', () {
    final expected = {
      _Mode.hebrew: 'טהרות',
      _Mode.ashkenazi: 'Taharos',
      _Mode.sephardi: 'Tahorot',
    };
    final wrong = {
      _Mode.hebrew: ['Taharos', 'Tahorot'],
      _Mode.ashkenazi: ['Tahorot', 'טהרות'],
      _Mode.sephardi: ['Taharos', 'טהרות'],
    };

    for (final mode in _Mode.values) {
      testWidgets('seder name switches — ${mode.label}', (tester) async {
        final repo = _makeRepoFor(
          CurriculumId.mishnayos,
          _kMishnayosTahorosItems,
        );
        const level = HierarchyLevelProgress(
          curriculumId: CurriculumId.mishnayos,
          level: 1,
          levelName: 'Tahorot',
          levelLabel: 'Seder',
          totalItems: 4,
          completedItems: 2,
          stageBreakdown: [StageBreakdownEntry(stageName: 'Learn', count: 2)],
          trackBreakdown: <String, int>{},
        );
        await tester.pumpWidget(
          _buildPlainApp(mode, repo, const HierarchyProgressCard(level: level)),
        );
        // Settle the async curriculumContent load that feeds the Hebrew name.
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(
          find.textContaining(expected[mode]!),
          findsWidgets,
          reason: 'seder name in ${mode.label} should show "${expected[mode]}"',
        );
        for (final w in wrong[mode]!) {
          expect(
            find.textContaining(w),
            findsNothing,
            reason: 'seder name in ${mode.label} must NOT leak "$w"',
          );
        }
      });
    }
  });

  // ── 4b — SiyumimGroupedView aggregate tile ──────────────────────────────────
  //
  // The aggregate row label is `"${terms.siyumSeder} $aggregateName"` where
  // aggregateName = renderCurriculumLevelName(…, rawValue: milestone.aggregate
  // Key) — again a raw VARIABLE. So the row reads "Siyum Seder Taharos" /
  // "Siyum Seder Tahorot" / "סיום סדר טהרות". This pins both the framing word
  // (siyumSeder) AND the variant-switched seder name together.

  group('Layer 4b — SiyumimGroupedView aggregate (milestone.aggregateKey)', () {
    final expected = {
      _Mode.hebrew: 'סדר טהרות',
      _Mode.ashkenazi: 'Siyum Seder Taharos',
      _Mode.sephardi: 'Siyum Seder Tahorot',
    };
    final wrong = {
      _Mode.hebrew: ['Taharos', 'Tahorot'],
      _Mode.ashkenazi: ['Tahorot', 'טהרות'],
      _Mode.sephardi: ['Taharos', 'טהרות'],
    };

    for (final mode in _Mode.values) {
      testWidgets('aggregate label switches — ${mode.label}', (tester) async {
        final repo = _makeRepoFor(
          CurriculumId.mishnayos,
          _kMishnayosTahorosItems,
        );
        final viewModel = JourneyViewModel(
          curricula: [
            CurriculumJourney(
              curriculumId: CurriculumId.mishnayos,
              completions: const [],
              uniqueUnitsCompleted: 1,
              totalUnitsAvailable: 1,
              milestones: [
                MilestoneAchievement(
                  type: 'seder_complete',
                  level: MilestoneLevel.aggregate,
                  curriculumId: CurriculumId.mishnayos,
                  displayName: 'Tahorot',
                  aggregateKey: 'Tahorot',
                  containedUnitKeys: const ['Keilim'],
                  achievedAt: DateTime.utc(2026, 1, 1),
                ),
              ],
            ),
          ],
          totalCompletions: 1,
          totalUniqueUnits: 1,
          unitLevelSiyumimCount: 0,
          aggregateLevelSiyumimCount: 1,
          curriculumLevelSiyumimCount: 0,
        );
        await tester.pumpWidget(
          _buildLocalizedApp(
            mode,
            repo,
            SiyumimGroupedView(viewModel: viewModel),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(
          find.textContaining(expected[mode]!),
          findsWidgets,
          reason:
              'aggregate label in ${mode.label} should contain '
              '"${expected[mode]}"',
        );
        for (final w in wrong[mode]!) {
          expect(
            find.textContaining(w),
            findsNothing,
            reason: 'aggregate label in ${mode.label} must NOT leak "$w"',
          );
        }
      });
    }
  });

  // ── 4c — GoalSetupForm unit-picker pills ────────────────────────────────────
  //
  // The Bavli unit picker renders Amud / Daf pills whose labels come from
  // `_granularityUnitLabel(…) → CurriculumLabels.level(…).inLanguage(plural)`,
  // a VARIABLE flowed into Text(). The daf pill reads "Dafim" (Ashkenazi) /
  // "Dapim" (Sephardi) / "דפים" (Hebrew).

  group('Layer 4c — GoalSetupForm daf unit pill', () {
    final expected = {
      _Mode.hebrew: 'דפים',
      _Mode.ashkenazi: 'Dafim',
      _Mode.sephardi: 'Dapim',
    };
    final wrong = {
      _Mode.hebrew: ['Dafim', 'Dapim'],
      _Mode.ashkenazi: ['Dapim', 'דפים'],
      _Mode.sephardi: ['Dafim', 'דפים'],
    };

    for (final mode in _Mode.values) {
      testWidgets('daf pill switches — ${mode.label}', (tester) async {
        await tester.pumpWidget(
          _buildLocalizedApp(
            mode,
            null,
            GoalSetupForm(
              curriculumId: CurriculumId.bavli,
              totalItems: 100,
              onComplete: (_) {},
            ),
            extraOverrides: [
              useHebrewDateProvider.overrideWith(() => _HebrewDateOff()),
            ],
          ),
        );
        await tester.pump();

        expect(
          find.textContaining(expected[mode]!),
          findsWidgets,
          reason: 'daf pill in ${mode.label} should show "${expected[mode]}"',
        );
        for (final w in wrong[mode]!) {
          expect(
            find.textContaining(w),
            findsNothing,
            reason: 'daf pill in ${mode.label} must NOT leak "$w"',
          );
        }
      });
    }
  });

  // ── 4d — SacredTimeLockOverlay greeting ─────────────────────────────────────
  //
  // The lock overlay resolves `terms.shabbos(variant:)` at the Consumer layer
  // and threads it into the localized greeting/subtitle. The greeting reads
  // "Good Shabbos" / "Good Shabbat" / a Hebrew greeting containing "שבת".

  group('Layer 4d — SacredTimeLockOverlay Shabbos greeting', () {
    final expectedTerm = {
      _Mode.hebrew: 'שבת',
      _Mode.ashkenazi: 'Shabbos',
      _Mode.sephardi: 'Shabbat',
    };
    final wrong = {
      _Mode.hebrew: ['Shabbos', 'Shabbat'],
      _Mode.ashkenazi: ['Shabbat', 'שבת'],
      _Mode.sephardi: ['Shabbos', 'שבת'],
    };

    for (final mode in _Mode.values) {
      testWidgets('greeting switches — ${mode.label}', (tester) async {
        await tester.pumpWidget(
          _buildLocalizedApp(
            mode,
            null,
            const SacredTimeLockOverlay(child: SizedBox.shrink()),
            extraOverrides: [
              currentSacredWindowProvider.overrideWith(
                () => _FixedShabbosWindow(),
              ),
            ],
          ),
        );
        await tester.pump();

        expect(
          find.textContaining(expectedTerm[mode]!),
          findsWidgets,
          reason:
              'lock greeting in ${mode.label} should contain '
              '"${expectedTerm[mode]}"',
        );
        for (final w in wrong[mode]!) {
          expect(
            find.textContaining(w),
            findsNothing,
            reason: 'lock greeting in ${mode.label} must NOT leak "$w"',
          );
        }
      });
    }
  });

  // ── 4e — SacredTimeSettingsCard header ──────────────────────────────────────
  //
  // The settings card resolves `terms.shabbos(variant:)` and threads it into
  // the header mode label (`{term} MODE`) and the card description. Pins the
  // same Shabbos / Shabbat / שבת switch on the settings surface.

  group('Layer 4e — SacredTimeSettingsCard Shabbos header', () {
    final expectedTerm = {
      _Mode.hebrew: 'שבת',
      _Mode.ashkenazi: 'Shabbos',
      _Mode.sephardi: 'Shabbat',
    };
    final wrong = {
      _Mode.hebrew: ['Shabbos', 'Shabbat'],
      _Mode.ashkenazi: ['Shabbat', 'שבת'],
      _Mode.sephardi: ['Shabbos', 'שבת'],
    };

    setUp(() => SharedPreferences.setMockInitialValues({}));

    for (final mode in _Mode.values) {
      testWidgets('header switches — ${mode.label}', (tester) async {
        await tester.pumpWidget(
          _buildLocalizedApp(mode, null, const SacredTimeSettingsCard()),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(
          find.textContaining(expectedTerm[mode]!),
          findsWidgets,
          reason:
              'settings header in ${mode.label} should contain '
              '"${expectedTerm[mode]}"',
        );
        for (final w in wrong[mode]!) {
          expect(
            find.textContaining(w),
            findsNothing,
            reason: 'settings header in ${mode.label} must NOT leak "$w"',
          );
        }
      });
    }
  });

  // ── 4f — track-order section-header WORD ────────────────────────────────────
  //
  // The track-learning-order screen's level-2 section header is
  // `CurriculumLabels.containerSectionHeader(id, useHebrew:, variant:)`. Pumping
  // the full screen needs the order repos + families; the header itself is a
  // pure shared-library call, so it is exercised through the same live-provider
  // probe as Layer 1. The word reads "Masechtos" / "Masekhtot" / "מסכתות".

  group('Layer 4f — track-order container section header word', () {
    final expected = {
      _Mode.hebrew: 'מסכתות',
      _Mode.ashkenazi: 'Masechtos',
      _Mode.sephardi: 'Masekhtot',
    };
    final wrong = {
      _Mode.hebrew: ['Masechtos', 'Masekhtot'],
      _Mode.ashkenazi: ['Masekhtot', 'מסכתות'],
      _Mode.sephardi: ['Masechtos', 'מסכתות'],
    };

    for (final mode in _Mode.values) {
      testWidgets('section header switches — ${mode.label}', (tester) async {
        await _pumpProbe(
          tester,
          mode,
          (ref) =>
              CurriculumLabels.containerSectionHeader(
                CurriculumId.mishnayos,
                useHebrew: domainTermLabels(ref).isHebrew,
                variant: ref.watch(currentTransliterationVariantProvider),
              ) ??
              '',
        );

        expect(find.textContaining(expected[mode]!), findsOneWidget);
        for (final w in wrong[mode]!) {
          expect(
            find.textContaining(w),
            findsNothing,
            reason: 'section header in ${mode.label} must NOT leak "$w"',
          );
        }
      });
    }
  });

  // ── 4g — curriculumLabelText surface (CurriculumLabel.curriculum) ───────────
  //
  // The curriculum NAME itself is nusach-sensitive: Mishnayos / Mishnayot /
  // משניות. `CurriculumLabel.curriculum` and `curriculumLabelText(ref)` share
  // one implementation; the widget is the rendered surface.

  group('Layer 4g — CurriculumLabel.curriculum (Mishnayos)', () {
    final expected = {
      _Mode.hebrew: 'משניות',
      _Mode.ashkenazi: 'Mishnayos',
      _Mode.sephardi: 'Mishnayot',
    };
    final wrong = {
      _Mode.hebrew: ['Mishnayos', 'Mishnayot'],
      _Mode.ashkenazi: ['Mishnayot', 'משניות'],
      _Mode.sephardi: ['Mishnayos', 'משניות'],
    };

    for (final mode in _Mode.values) {
      testWidgets('curriculum name switches — ${mode.label}', (tester) async {
        await tester.pumpWidget(
          _buildPlainApp(
            mode,
            null,
            const CurriculumLabel.curriculum(CurriculumId.mishnayos),
          ),
        );
        await tester.pump();

        expect(
          find.textContaining(expected[mode]!),
          findsOneWidget,
          reason:
              'curriculum name in ${mode.label} should be "${expected[mode]}"',
        );
        for (final w in wrong[mode]!) {
          expect(
            find.textContaining(w),
            findsNothing,
            reason: 'curriculum name in ${mode.label} must NOT leak "$w"',
          );
        }
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
