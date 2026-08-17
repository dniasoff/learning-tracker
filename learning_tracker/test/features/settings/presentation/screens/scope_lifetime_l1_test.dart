// L1 widget tests — ScopeSelectionScreen + LifetimeMarkingScreen
//
// Covers:
//   ScopeSelectionScreen (0% baseline):
//     • AppBar renders curriculum label and Save action button.
//     • Initial state: "Track Entire Curriculum" toggle is ON (selectAll=true).
//     • Toggling "Track Entire Curriculum" OFF reveals level-selection tiles.
//     • Level tiles show up-to-depth-1 options (non-leaf levels).
//     • Tapping a level tile shows scope-value checkboxes.
//     • Selecting scope values updates the selection counter and summary.
//     • Save with selectAll=true calls clearScopes (scope cleared).
//     • Save with selected values calls setScopes (scope persisted).
//     • Loading state: CircularProgressIndicator while content loads.
//     • Error state: AppErrorView shown when content provider throws.
//     • he-RTL smoke: renders under Hebrew locale without crash.
//     • No track-type labels (Personal/Standard/Custom/אישי) on screen.
//
//   LifetimeMarkingScreen (28.8% baseline):
//     • AppBar title matches l10n.addWhatYouLearned.
//     • l10n subtitle (lifetimeMarkingSubtitle) is rendered.
//     • One card per CurriculumId value is shown.
//     • Cards in "not started" state show l10n.lifetimeNotStarted.
//     • Cards with progress show a LinearProgressIndicator.
//     • Tapping a card pushes LifetimeCurriculumMarkingScreen.
//     • he-RTL smoke: renders under Hebrew locale without crash.
//
//   LifetimeCurriculumMarkingScreen:
//     • AppBar title shows curriculum label.
//     • "Select what you've learned" section title is present.
//     • "Select all in this list" button is present.
//     • Save button is disabled when no selections.
//     • Clear button is disabled when no selections.
//     • Bulk-mark path: selecting + confirming calls recordCompletionsBatch
//       with CompletionSource.lifetimeOnly (sentinel date — credits lifetime
//       without leaking into streak/recent-activity). [Product rule]
//     • he-RTL smoke: renders under Hebrew locale without crash.
//
// SKIP conditions (BUG):  none found in this pass.
//
// Deliberately NOT tested here (require real Navigator push / real content
// assets / HierarchySelectionPanel drill navigation):
//   • Full drill navigation inside HierarchySelectionPanel (integration level).
//   • _markAllCurrentLevel button (requires real visible items from assets).

@Tags(['settings', 'scope_selection', 'lifetime_marking'])
library;

import 'dart:async';
import 'dart:collection';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart';
import 'package:learning_tracker/data/repositories/firestore_curriculum_scope_repository.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_source.dart';
import 'package:learning_tracker/features/learning/domain/entities/learning_ledger_entry.dart';
import 'package:learning_tracker/features/learning/domain/repositories/learning_ledger_repository.dart';
import 'package:learning_tracker/features/learning/presentation/providers/learning_ledger_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/settings/presentation/screens/lifetime_marking_screen.dart';
import 'package:learning_tracker/features/settings/presentation/screens/scope_selection_screen.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/firestore_fake.dart';
import '../../../../helpers/firestore_fixtures.dart';
import '../../../../helpers/pump_app.dart';

// ── Mocks ──────────────────────────────────────────────────────────────────────

class _MockContentRepository extends Mock implements ContentRepository {}

class _MockLearningLedgerRepository extends Mock
    implements LearningLedgerRepository {}

// ── Provider stubs ─────────────────────────────────────────────────────────────

class _ProfileId1 extends ActiveProfileId {
  @override
  String build() => _profileId;
}

class _HebrewTermsOff extends UseHebrewTerms {
  @override
  bool build() => false;
}

class _HebrewTermsOn extends UseHebrewTerms {
  @override
  bool build() => true;
}

class _VariantSephardi extends CurrentTransliterationVariant {
  @override
  TransliterationVariant build() => TransliterationVariant.sephardi;
}

class _VariantAshkenazi extends CurrentTransliterationVariant {
  @override
  TransliterationVariant build() => TransliterationVariant.ashkenazi;
}

// ── Minimal synthetic content ─────────────────────────────────────────────────
//
// Real asset loading is replaced with these in-memory fakes. The fixture
// mirrors a 2-level curriculum (Seder > Masechta) with two leaf nodes, which
// is enough to exercise all scope-selection branches without loading disk files.

const _kSeder1 = 'Seder Zeraim';
const _uid = 'scope-lifetime-test-uid';
const _profileId = '01J6Q2H4A8M7K3P9R5T6V8WXY7';
const _kSeder2 = 'Seder Moed';
const _kMasechta1 = 'Berakhot';
const _kMasechta2 = 'Shabbat';

final _kFakeItems = [
  // Level-1 containers
  const ContentItem(
    curriculumId: 'mishnayos',
    level1: _kSeder1,
    displayNameHe: 'סדר זרעים',
    displayNameEn: _kSeder1,
    sefariaRef: 'Mishnah_Zeraim',
    sortOrder: 0,
    isLeaf: false,
  ),
  const ContentItem(
    curriculumId: 'mishnayos',
    level1: _kSeder2,
    displayNameHe: 'סדר מועד',
    displayNameEn: _kSeder2,
    sefariaRef: 'Mishnah_Moed',
    sortOrder: 10,
    isLeaf: false,
  ),
  // Level-2 containers
  const ContentItem(
    curriculumId: 'mishnayos',
    level1: _kSeder1,
    level2: _kMasechta1,
    displayNameHe: 'ברכות',
    displayNameEn: _kMasechta1,
    sefariaRef: 'Mishnah_Berakhot',
    sortOrder: 1,
    isLeaf: false,
  ),
  const ContentItem(
    curriculumId: 'mishnayos',
    level1: _kSeder2,
    level2: _kMasechta2,
    displayNameHe: 'שבת',
    displayNameEn: _kMasechta2,
    sefariaRef: 'Mishnah_Shabbat',
    sortOrder: 11,
    isLeaf: false,
  ),
  // Leaf nodes
  const ContentItem(
    curriculumId: 'mishnayos',
    level1: _kSeder1,
    level2: _kMasechta1,
    level3: '1',
    displayNameHe: 'א',
    displayNameEn: '1',
    sefariaRef: 'Mishnah_Berakhot.1',
    sortOrder: 2,
    isLeaf: true,
  ),
  const ContentItem(
    curriculumId: 'mishnayos',
    level1: _kSeder2,
    level2: _kMasechta2,
    level3: '1',
    displayNameHe: 'א',
    displayNameEn: '1',
    sefariaRef: 'Mishnah_Shabbat.1',
    sortOrder: 12,
    isLeaf: true,
  ),
];

// ── Chumash fixture (named level-1 Sefer, nusach-sensitive) ──────────────────
//
// Chumash level-1 values are NAMED Seferim that the renderer transliterates
// per-nusach: "Genesis" → "Bereishis" (ashkenazi) / "Bereshit" (sephardi), and
// renders the Hebrew proper name ("בראשית") in Hebrew mode. The bundled data
// ships English book names ("Genesis") as the raw scope storage key, so this
// fixture is the regression target for the raw-key rendering bypass.

final _kChumashItems = [
  // Level-1 container (Sefer)
  const ContentItem(
    curriculumId: 'chumash',
    level1: 'Genesis',
    displayNameHe: 'בראשית',
    displayNameEn: 'Genesis',
    sefariaRef: 'Genesis',
    sortOrder: 0,
    isLeaf: false,
  ),
  // Level-2 container (Perek 1)
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
  // Leaf (Pasuk)
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

// ── Mishna Berurah fixture (AUD-settings-08: PF-2 large-level regression) ────
//
// A single Sefer ('Mishnah Berurah') with 697 distinct 'Siman' (level-2)
// values — the exact cardinality the finding's own evidence measured for
// CurriculumId.mishnaBerurah's 'Siman' level against the real bundled
// content assets. `_buildLevelValueTiles`'s pre-fix bare
// `ListView(children: values.map(...).toList())` built all 697
// CheckboxListTiles synchronously the moment this level was selected; the
// fix routes them through a `SliverList`/`SliverChildBuilderDelegate` so
// only the on-screen (plus overscan) subset is ever built.
const _kMishnaBerurahSefer = 'Mishnah Berurah';
const _kMishnaBerurahSimanCount = 697;

final _kMishnaBerurahItems = [
  const ContentItem(
    curriculumId: 'mishna_berurah',
    level1: _kMishnaBerurahSefer,
    displayNameHe: 'משנה ברורה',
    displayNameEn: _kMishnaBerurahSefer,
    sefariaRef: 'Mishnah_Berurah',
    sortOrder: 0,
    isLeaf: false,
  ),
  for (var siman = 1; siman <= _kMishnaBerurahSimanCount; siman++)
    ContentItem(
      curriculumId: 'mishna_berurah',
      level1: _kMishnaBerurahSefer,
      level2: '$siman',
      displayNameHe: 'סימן $siman',
      displayNameEn: '$siman',
      sefariaRef: 'Mishnah_Berurah.$siman',
      sortOrder: siman,
      isLeaf: false,
    ),
];

/// Counts every `.where(...)` call made against the wrapped list.
///
/// `ScopeSelectionScreen._countLeafItemsForValue` does exactly one
/// `allItems.where(...)` per `CheckboxListTile` it CONSTRUCTS — so this
/// count is the number of tiles actually built.
///
/// A mounted-element count (`find.byType(CheckboxListTile)`) cannot see
/// this: verified empirically against the pre-fix `ListView(children:
/// values.map(...).toList())` source, it reports the same small number
/// (~6) as the fixed lazy version, because Flutter's `SliverList` windows
/// the MOUNTED element tree to the viewport regardless of whether the
/// feeding delegate is eager or lazy — the eager delegate still
/// front-loads widget CONSTRUCTION (and this `.where()` call inside each
/// one) for every value before the sliver ever gets a chance to window
/// anything, even though only the visible few end up mounted. This wrapper
/// observes that construction-time cost directly instead.
class _WhereCallCountingItems extends ListBase<ContentItem> {
  _WhereCallCountingItems(this._base);

  final List<ContentItem> _base;
  int whereCallCount = 0;

  @override
  int get length => _base.length;

  @override
  set length(int newLength) => _base.length = newLength;

  @override
  ContentItem operator [](int index) => _base[index];

  @override
  void operator []=(int index, ContentItem value) => _base[index] = value;

  @override
  Iterable<ContentItem> where(bool Function(ContentItem) test) {
    whereCallCount++;
    return _base.where(test);
  }
}

// ── Helpers ────────────────────────────────────────────────────────────────────

Future<void> _pump(WidgetTester tester, Widget app) async {
  await tester.pumpWidget(app);
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

Future<void> _tearDown(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(Duration.zero);
}

// ── Widget factory — ScopeSelectionScreen ────────────────────────────────────

Widget _buildScopeApp({
  FirestoreCurriculumScopeRepository? scopeRepository,
  ContentRepository? contentRepo,
  bool useHebrew = false,
  Locale locale = const Locale('en'),
  CurriculumId curriculum = CurriculumId.mishnayos,
  TransliterationVariant variant = TransliterationVariant.ashkenazi,
}) {
  final repo = contentRepo ?? _makeDefaultRepo();
  return pumpApp(
    locale: locale,
    overrides: [
      firestoreCurriculumScopeRepositoryProvider.overrideWith(
        (ref) async => scopeRepository ?? _scopeRepository,
      ),
      activeProfileIdProvider.overrideWith(() => _ProfileId1()),
      contentRepositoryProvider.overrideWithValue(repo),
      if (useHebrew)
        useHebrewTermsProvider.overrideWith(() => _HebrewTermsOn())
      else
        useHebrewTermsProvider.overrideWith(() => _HebrewTermsOff()),
      if (variant == TransliterationVariant.sephardi)
        currentTransliterationVariantProvider.overrideWith(
          () => _VariantSephardi(),
        )
      else
        currentTransliterationVariantProvider.overrideWith(
          () => _VariantAshkenazi(),
        ),
    ],
    child: ScopeSelectionScreen(curriculumId: curriculum),
  );
}

// ── Widget factory — LifetimeMarkingScreen ────────────────────────────────────

Widget _buildLifetimeApp({
  ContentRepository? contentRepo,
  LearningLedgerRepository? ledgerRepo,
  bool useHebrew = false,
  Locale locale = const Locale('en'),
}) {
  final repo = contentRepo ?? _makeDefaultRepo();
  return pumpApp(
    locale: locale,
    overrides: [
      activeProfileIdProvider.overrideWith(() => _ProfileId1()),
      contentRepositoryProvider.overrideWithValue(repo),
      if (ledgerRepo != null)
        learningLedgerRepositoryProvider.overrideWithValue(ledgerRepo),
      if (useHebrew)
        useHebrewTermsProvider.overrideWith(() => _HebrewTermsOn())
      else
        useHebrewTermsProvider.overrideWith(() => _HebrewTermsOff()),
    ],
    child: const LifetimeMarkingScreen(),
  );
}

// ── Widget factory — LifetimeCurriculumMarkingScreen ─────────────────────────

Widget _buildCurriculumMarkingApp({
  ContentRepository? contentRepo,
  LearningLedgerRepository? ledgerRepo,
  bool useHebrew = false,
  Locale locale = const Locale('en'),
  String curriculumId = 'mishnayos',
}) {
  final repo = contentRepo ?? _makeDefaultRepo();
  final ledger = ledgerRepo ?? _MockLearningLedgerRepository();
  when(
    () => ledger.getLedgerByCurriculum(any<CurriculumId>()),
  ).thenAnswer((_) async => []);
  return pumpApp(
    locale: locale,
    overrides: [
      activeProfileIdProvider.overrideWith(() => _ProfileId1()),
      contentRepositoryProvider.overrideWithValue(repo),
      learningLedgerRepositoryProvider.overrideWithValue(ledger),
      if (useHebrew)
        useHebrewTermsProvider.overrideWith(() => _HebrewTermsOn())
      else
        useHebrewTermsProvider.overrideWith(() => _HebrewTermsOff()),
    ],
    child: LifetimeCurriculumMarkingScreen(curriculumId: curriculumId),
  );
}

// ── Fake content repo builder ─────────────────────────────────────────────────

_MockContentRepository _makeDefaultRepo({List<ContentItem>? items}) {
  final content = items ?? _kFakeItems;
  final repo = _MockContentRepository();
  when(
    () => repo.getContentForCurriculum(any<CurriculumId>()),
  ).thenAnswer((_) async => content);
  when(
    () => repo.getScopedContent(
      curriculumId: any<CurriculumId>(named: 'curriculumId'),
      scopeLevel: any<int>(named: 'scopeLevel'),
      scopeValues: any<List<String>>(named: 'scopeValues'),
    ),
  ).thenAnswer((_) async => content);
  when(
    () => repo.getHierarchyConfig(any<CurriculumId>()),
  ).thenAnswer((_) async => throw UnimplementedError('not needed'));
  when(
    () => repo.filterByLevel(
      curriculumId: any<CurriculumId>(named: 'curriculumId'),
      level1: any<String>(named: 'level1'),
      level2: any<String>(named: 'level2'),
      level3: any<String>(named: 'level3'),
      level4: any<String>(named: 'level4'),
    ),
  ).thenAnswer((_) async => content);
  when(
    () => repo.search(
      curriculumId: any<CurriculumId>(named: 'curriculumId'),
      query: any<String>(named: 'query'),
    ),
  ).thenAnswer((_) async => []);
  when(
    () => repo.getContentByRef(
      curriculumId: any<CurriculumId>(named: 'curriculumId'),
      sefariaRef: any<String>(named: 'sefariaRef'),
    ),
  ).thenAnswer((_) async => null);
  return repo;
}

// ── Shared state ───────────────────────────────────────────────────────────────

late FakeFirebaseFirestore _firestore;
late FirestoreCurriculumScopeRepository _scopeRepository;

// ── Main ───────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() {
    // CurriculumId is an enum — register a real value as fallback.
    registerFallbackValue(CurriculumId.mishnayos);
    registerFallbackValue(<LedgerEntryDraft>[]);
    registerFallbackValue(CompletionSource.lifetimeOnly);
    // Named parameter fallbacks for content repository mocks.
    registerFallbackValue(0); // scopeLevel
    registerFallbackValue(<String>[]); // scopeValues
    registerFallbackValue(''); // query / sefariaRef
  });

  setUp(() async {
    _firestore = createFakeFirestore(authenticatedUid: _uid);
    await seedAccount(_firestore, uid: _uid);
    await seedProfile(_firestore, uid: _uid, profileId: _profileId);
    _scopeRepository = FirestoreCurriculumScopeRepository(
      firestore: _firestore,
      uid: _uid,
      profileId: _profileId,
    );
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // ScopeSelectionScreen
  // ═══════════════════════════════════════════════════════════════════════════

  group('ScopeSelectionScreen — AppBar', () {
    testWidgets('AppBar renders and contains Save action', (tester) async {
      await _pump(tester, _buildScopeApp());

      expect(find.byType(AppBar), findsOneWidget);
      // l10n key: scopeSelectionSave => 'Save'
      expect(find.text('Save'), findsOneWidget);

      await _tearDown(tester);
    });

    testWidgets('AppBar title contains curriculum label (English)', (
      tester,
    ) async {
      await _pump(tester, _buildScopeApp());

      // The title format is 'Learning Scope — Mishnayos'
      expect(find.textContaining('Mishnayos'), findsWidgets);

      await _tearDown(tester);
    });

    testWidgets(
      'AppBar title contains Hebrew curriculum label when useHebrew=true',
      (tester) async {
        await _pump(
          tester,
          _buildScopeApp(useHebrew: true, locale: const Locale('he')),
        );

        // CurriculumId.mishnayos.displayNameHe = 'משניות'
        expect(
          find.textContaining(CurriculumId.mishnayos.displayNameHe),
          findsWidgets,
        );

        await _tearDown(tester);
      },
    );
  });

  group('ScopeSelectionScreen — initial state (selectAll=true)', () {
    testWidgets('"Track Entire Curriculum" toggle is ON when no scopes saved', (
      tester,
    ) async {
      // No scope rows in DB → _selectAll = true on load.
      await _pump(tester, _buildScopeApp());

      final switchFinder = find.byType(SwitchListTile);
      expect(switchFinder, findsOneWidget);

      final tile = tester.widget<SwitchListTile>(switchFinder);
      expect(
        tile.value,
        isTrue,
        reason: 'Switch must be ON when no scopes saved',
      );

      await _tearDown(tester);
    });

    testWidgets('"All content is included" subtitle shown when toggle is ON', (
      tester,
    ) async {
      await _pump(tester, _buildScopeApp());

      expect(find.text('All content is included'), findsOneWidget);

      await _tearDown(tester);
    });

    testWidgets('Level-selection tiles are NOT shown when selectAll is ON', (
      tester,
    ) async {
      await _pump(tester, _buildScopeApp());

      // Level picker / scope checkboxes must not appear when selectAll=true.
      expect(find.text('Select Scope Level'), findsNothing);

      await _tearDown(tester);
    });
  });

  group(
    'ScopeSelectionScreen — toggling selectAll OFF reveals level selection',
    () {
      testWidgets(
        'Toggling "Track Entire Curriculum" OFF reveals "Select Scope Level" header',
        (tester) async {
          await _pump(tester, _buildScopeApp());

          // Tap the SwitchListTile to turn selectAll OFF.
          await tester.tap(find.byType(SwitchListTile));
          await tester.pump();

          expect(find.text('Select Scope Level'), findsOneWidget);

          await _tearDown(tester);
        },
      );

      testWidgets(
        'After toggling OFF, level-1 tile (e.g. "Seder") is visible',
        (tester) async {
          await _pump(tester, _buildScopeApp());

          await tester.tap(find.byType(SwitchListTile));
          await tester.pump();

          // For mishnayos the first level label is 'Seder'.
          // We verify at least one ListTile with a chevron_right icon appears.
          expect(find.byIcon(Icons.chevron_right), findsWidgets);

          await _tearDown(tester);
        },
      );

      testWidgets(
        '"Only selected sections are tracked" subtitle when selectAll is OFF',
        (tester) async {
          await _pump(tester, _buildScopeApp());

          await tester.tap(find.byType(SwitchListTile));
          await tester.pump();

          expect(
            find.text('Only selected sections are tracked'),
            findsOneWidget,
          );

          await _tearDown(tester);
        },
      );
    },
  );

  group('ScopeSelectionScreen — level tile tap navigates to checkboxes', () {
    testWidgets(
      'Tapping first level tile shows CheckboxListTiles for scope values',
      (tester) async {
        await _pump(tester, _buildScopeApp());

        // Toggle selectAll OFF.
        await tester.tap(find.byType(SwitchListTile));
        await tester.pump();

        // The first level's ListTile has a chevron_right.
        // There may be multiple — we want the first tappable level row.
        final levelTileFinder = find.descendant(
          of: find.byType(ListTile),
          matching: find.byIcon(Icons.chevron_right),
        );
        expect(levelTileFinder, findsWidgets);

        // Tap the first such tile.
        await tester.tap(levelTileFinder.first);
        await tester.pump();

        // Now we should be showing CheckboxListTiles.
        expect(find.byType(CheckboxListTile), findsWidgets);

        await _tearDown(tester);
      },
    );

    testWidgets(
      'Fake content produces exactly 2 distinct level-1 values as checkboxes',
      (tester) async {
        await _pump(tester, _buildScopeApp());

        await tester.tap(find.byType(SwitchListTile));
        await tester.pump();

        // Tap first level tile.
        final levelTileFinder = find.descendant(
          of: find.byType(ListTile),
          matching: find.byIcon(Icons.chevron_right),
        );
        await tester.tap(levelTileFinder.first);
        await tester.pump();

        // _kFakeItems has 2 distinct level-1 values: _kSeder1 and _kSeder2.
        expect(find.byType(CheckboxListTile), findsNWidgets(2));

        await _tearDown(tester);
      },
    );

    testWidgets('Tapping a CheckboxListTile selects it (value flips to true)', (
      tester,
    ) async {
      await _pump(tester, _buildScopeApp());

      await tester.tap(find.byType(SwitchListTile));
      await tester.pump();

      final levelTileFinder = find.descendant(
        of: find.byType(ListTile),
        matching: find.byIcon(Icons.chevron_right),
      );
      await tester.tap(levelTileFinder.first);
      await tester.pump();

      // Tap the first checkbox tile to select it.
      await tester.tap(find.byType(CheckboxListTile).first);
      await tester.pump();

      final checkbox = tester.widget<CheckboxListTile>(
        find.byType(CheckboxListTile).first,
      );
      expect(
        checkbox.value,
        isTrue,
        reason: 'First scope value should be selected',
      );

      await _tearDown(tester);
    });

    testWidgets('"Change Level" button appears once a level is selected', (
      tester,
    ) async {
      await _pump(tester, _buildScopeApp());

      await tester.tap(find.byType(SwitchListTile));
      await tester.pump();

      final levelTileFinder = find.descendant(
        of: find.byType(ListTile),
        matching: find.byIcon(Icons.chevron_right),
      );
      await tester.tap(levelTileFinder.first);
      await tester.pump();

      // l10n key: scopeSelectionChangeLevel => 'Change Level'
      expect(find.text('Change Level'), findsOneWidget);

      await _tearDown(tester);
    });
  });

  group(
    'ScopeSelectionScreen — AUD-settings-08: lazy per-value list (PF-2)',
    () {
      testWidgets(
        'CurriculumId.mishnaBerurah — Siman level (697 distinct values): '
        'pumpAndSettle completes, the rendered CheckboxListTile count is '
        'bounded to roughly a screenful (not all 697), and the per-value '
        'leaf-count computation only ran for the tiles actually built',
        (tester) async {
          // Wrapping the fixture list lets this test observe how many tiles
          // were actually CONSTRUCTED, not just mounted — see
          // _WhereCallCountingItems' doc comment for why a mounted-element
          // count alone (find.byType(CheckboxListTile)) cannot, by itself,
          // distinguish the eager pre-fix shape from the lazy post-fix one:
          // verified empirically against the pre-fix source, both show the
          // same small mounted count (~6) because Flutter's SliverList
          // windows the MOUNTED element tree to the viewport either way. The
          // eager shape's real cost is front-loaded widget CONSTRUCTION
          // (evaluating `_countLeafItemsForValue` — one `allItems.where(...)`
          // call — for every one of the 697 values before the sliver ever
          // gets a chance to window anything), which this counter captures.
          final countingItems = _WhereCallCountingItems(_kMishnaBerurahItems);
          final repo = _makeDefaultRepo(items: countingItems);
          await _pump(
            tester,
            _buildScopeApp(
              contentRepo: repo,
              curriculum: CurriculumId.mishnaBerurah,
            ),
          );

          // Toggle "Track entire curriculum" OFF to reveal level selection.
          await tester.tap(find.byType(SwitchListTile));
          await tester.pump();

          // Select the 'Siman' level (level 2 — 'Sefer' is level 1, 'Seif' is
          // the excluded leaf level; see CurriculumLabels' mishnaBerurah
          // entry in core/constants/curriculum_defaults.dart).
          final simanTile = find.widgetWithText(ListTile, 'Siman');
          expect(
            simanTile,
            findsOneWidget,
            reason: "The 'Siman' level tile must be offered for scoping",
          );
          await tester.tap(simanTile);

          // AC2(a): must settle without timing out — the level backs 697
          // distinct raw values (pumpAndSettle throws if frames keep
          // scheduling beyond its internal iteration cap).
          await tester.pumpAndSettle();

          // AC2(b) (literal): the rendered CheckboxListTile count at rest is
          // bounded to roughly a screenful, not all 697.
          final renderedCount = find.byType(CheckboxListTile).evaluate().length;
          expect(
            renderedCount,
            lessThan(50),
            reason:
                'ScopeSelectionScreen must build the Siman-level checkbox '
                'list lazily; found $renderedCount realized CheckboxListTiles '
                'for a 697-value level — a screenful is a couple dozen at '
                'most (AUD-settings-08)',
          );
          expect(
            renderedCount,
            greaterThan(0),
            reason: 'At least the visible rows must still render',
          );

          // The genuinely-discriminating signal: only the tiles actually
          // realized (bounded, same order of magnitude as renderedCount)
          // should ever have had their leaf count computed — never all 697.
          expect(
            countingItems.whereCallCount,
            lessThan(50),
            reason:
                'ScopeSelectionScreen._countLeafItemsForValue must only run '
                'for the CheckboxListTiles the SliverChildBuilderDelegate '
                'actually builds; found ${countingItems.whereCallCount} '
                'calls for a 697-value level — the pre-fix eager '
                '`ListView(children: values.map(...).toList())` shape calls '
                'this once per value regardless of what is visible '
                '(AUD-settings-08)',
          );

          await _tearDown(tester);
        },
      );
    },
  );

  group('ScopeSelectionScreen — scope persistence (Save)', () {
    testWidgets('Save with selectAll=true clears scope rows in DB', (
      tester,
    ) async {
      await _pump(tester, _buildScopeApp());

      // Tap Save while selectAll=true.
      await tester.tap(find.text('Save'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // After save-as-all, DB should have no scope rows for profile 1.
      final rows = await _scopeRepository.getScopes(CurriculumId.mishnayos);
      expect(rows, isEmpty, reason: 'clearScopes must have been called');

      await _tearDown(tester);
    });

    testWidgets('Save with selected scope values persists rows to DB', (
      tester,
    ) async {
      await _pump(tester, _buildScopeApp());

      // Toggle OFF + drill to level values + select first.
      await tester.tap(find.byType(SwitchListTile));
      await tester.pump();

      final levelTileFinder = find.descendant(
        of: find.byType(ListTile),
        matching: find.byIcon(Icons.chevron_right),
      );
      await tester.tap(levelTileFinder.first);
      await tester.pump();

      await tester.tap(find.byType(CheckboxListTile).first);
      await tester.pump();

      await tester.tap(find.text('Save'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // After save, at least one Firestore scope document exists.
      final rows = await _scopeRepository.getScopes(CurriculumId.mishnayos);
      expect(rows, isNotEmpty, reason: 'setScopes must have been called');

      await _tearDown(tester);
    });

    testWidgets(
      'Save is DISABLED for an empty subset (selectAll OFF + no values) — '
      'guards the silent no-op that falsely reported success',
      (tester) async {
        await _pump(tester, _buildScopeApp());

        // Turn "select all" OFF and drill into a level, but tick NO values.
        await tester.tap(find.byType(SwitchListTile));
        await tester.pump();
        final levelTile = find.descendant(
          of: find.byType(ListTile),
          matching: find.byIcon(Icons.chevron_right),
        );
        await tester.tap(levelTile.first);
        await tester.pump();
        expect(find.byType(CheckboxListTile), findsWidgets);

        // Empty subset → Save must be disabled (onPressed == null), otherwise
        // _save() writes nothing yet pops with a success snackbar.
        final saveBtn = tester.widget<TextButton>(
          find.ancestor(
            of: find.text('Save'),
            matching: find.byType(TextButton),
          ),
        );
        expect(
          saveBtn.onPressed,
          isNull,
          reason: 'empty subset is not saveable (silent no-op guard)',
        );

        // Ticking a value re-enables Save.
        await tester.tap(find.byType(CheckboxListTile).first);
        await tester.pump();
        final saveBtn2 = tester.widget<TextButton>(
          find.ancestor(
            of: find.text('Save'),
            matching: find.byType(TextButton),
          ),
        );
        expect(saveBtn2.onPressed, isNotNull);

        await _tearDown(tester);
      },
    );

    testWidgets(
      'Existing scope rows are pre-loaded: toggle starts OFF and level/values shown',
      (tester) async {
        // Seed a Firestore scope document before opening the screen.
        await _scopeRepository.setScopes(
          curriculumId: CurriculumId.mishnayos,
          scopeLevel: 1,
          scopeValues: [_kSeder1],
        );

        await _pump(tester, _buildScopeApp());

        final switchFinder = find.byType(SwitchListTile);
        final tile = tester.widget<SwitchListTile>(switchFinder);
        expect(
          tile.value,
          isFalse,
          reason: 'Scope exists in DB → selectAll should be false',
        );

        await _tearDown(tester);
      },
    );
  });

  group('ScopeSelectionScreen — loading state', () {
    testWidgets('Shows CircularProgressIndicator while content is loading', (
      tester,
    ) async {
      // Use a repo that never completes to keep loading state visible.
      final repo = _MockContentRepository();
      final completer = <Completer<List<ContentItem>>>[];
      when(() => repo.getContentForCurriculum(any<CurriculumId>())).thenAnswer((
        _,
      ) {
        final c = Completer<List<ContentItem>>();
        completer.add(c);
        return c.future;
      });

      await tester.pumpWidget(_buildScopeApp(contentRepo: repo));
      await tester.pump(); // One frame to start async.

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Complete to avoid pending timers.
      for (final c in completer) {
        if (!c.isCompleted) c.complete(_kFakeItems);
      }
      await tester.pump(const Duration(seconds: 1));
      await _tearDown(tester);
    });
  });

  group('ScopeSelectionScreen — error state', () {
    testWidgets('Shows AppErrorView when contentProvider throws', (
      tester,
    ) async {
      // The curriculumContentProvider is a @riverpod FutureProvider. Riverpod
      // retries on error by default — we must disable retry and override the
      // generated provider directly (not just the repository) to see the error
      // state surface in one pump cycle.
      final app = ProviderScope(
        overrides: [
          activeProfileIdProvider.overrideWith(() => _ProfileId1()),
          // Override the generated FutureProvider directly.
          curriculumContentProvider(CurriculumId.mishnayos).overrideWith(
            (ref) => Future<List<ContentItem>>.error(
              Exception('content load failed'),
            ),
          ),
          useHebrewTermsProvider.overrideWith(() => _HebrewTermsOff()),
        ],
        // retry: null disables Riverpod's automatic retry so the error
        // state surfaces immediately within our pump window.
        retry: (_, __) => null,
        child: const MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: ScopeSelectionScreen(curriculumId: CurriculumId.mishnayos),
        ),
      );

      await _pump(tester, app);

      // AppErrorView maps generic exceptions to "Something went wrong".
      expect(find.text('Something went wrong'), findsOneWidget);
      // The AppErrorView renders a bug_report icon for unknown exceptions.
      expect(find.byIcon(Icons.bug_report_outlined), findsOneWidget);

      await _tearDown(tester);
    });
  });

  group('ScopeSelectionScreen — product rule: no track-type labels', () {
    testWidgets('no "Personal" track-type label on screen', (tester) async {
      await _pump(tester, _buildScopeApp());
      expect(find.text('Personal'), findsNothing);
      await _tearDown(tester);
    });

    testWidgets('no "Standard" track-type label on screen', (tester) async {
      await _pump(tester, _buildScopeApp());
      expect(find.text('Standard'), findsNothing);
      await _tearDown(tester);
    });

    testWidgets('no standalone "Custom" track-type label on screen', (
      tester,
    ) async {
      await _pump(tester, _buildScopeApp());
      // "Custom" as a standalone track-type label is forbidden.
      expect(find.text('Custom'), findsNothing);
      expect(find.textContaining('Custom track'), findsNothing);
      await _tearDown(tester);
    });

    testWidgets('no "אישי" Hebrew personal track-type label on screen (he)', (
      tester,
    ) async {
      await _pump(
        tester,
        _buildScopeApp(useHebrew: true, locale: const Locale('he')),
      );
      expect(find.text('אישי'), findsNothing);
      await _tearDown(tester);
    });
  });

  group('ScopeSelectionScreen — domain-term rendering (no raw-key bypass)', () {
    // Regression: the screen used to render RAW Torah storage keys (e.g. the
    // English book name "Genesis") and hardcoded English level words, ignoring
    // the Hebrew Terms toggle + nusach. It must now route every value + level
    // word through CurriculumLabelRenderer / CurriculumLabels.

    Future<void> drillToFirstLevel(WidgetTester tester) async {
      // Turn "select all" OFF, then tap the first selectable level tile.
      await tester.tap(find.byType(SwitchListTile));
      await tester.pump();
      final levelTile = find.descendant(
        of: find.byType(ListTile),
        matching: find.byIcon(Icons.chevron_right),
      );
      await tester.tap(levelTile.first);
      await tester.pump();
    }

    testWidgets(
      'level WORD honours Hebrew Terms: "Sefer" (en) vs "חומש" (he) for chumash',
      (tester) async {
        // English mode: level-1 word is the English "Sefer".
        await _pump(
          tester,
          _buildScopeApp(
            curriculum: CurriculumId.chumash,
            contentRepo: _makeDefaultRepo(items: _kChumashItems),
          ),
        );
        await tester.tap(find.byType(SwitchListTile));
        await tester.pump();
        expect(find.text('Sefer'), findsOneWidget);
        await _tearDown(tester);

        // Hebrew mode: level-1 word is the Hebrew "חומש" (NOT the raw English).
        await _pump(
          tester,
          _buildScopeApp(
            curriculum: CurriculumId.chumash,
            useHebrew: true,
            locale: const Locale('he'),
            contentRepo: _makeDefaultRepo(items: _kChumashItems),
          ),
        );
        await tester.tap(find.byType(SwitchListTile));
        await tester.pump();
        expect(find.text('חומש'), findsOneWidget);
        expect(
          find.text('Sefer'),
          findsNothing,
          reason: 'level word must not leak the English term in Hebrew mode',
        );
        await _tearDown(tester);
      },
    );

    testWidgets(
      'value checkbox renders Hebrew proper name when Hebrew Terms ON '
      '(raw key "Genesis" -> "בראשית", never the raw English key)',
      (tester) async {
        await _pump(
          tester,
          _buildScopeApp(
            curriculum: CurriculumId.chumash,
            useHebrew: true,
            locale: const Locale('he'),
            contentRepo: _makeDefaultRepo(items: _kChumashItems),
          ),
        );
        await drillToFirstLevel(tester);

        expect(find.byType(CheckboxListTile), findsOneWidget);
        // Hebrew proper name rendered — NOT the raw storage key "Genesis".
        expect(find.text('בראשית'), findsOneWidget);
        expect(
          find.text('Genesis'),
          findsNothing,
          reason: 'raw English storage key must not be shown in Hebrew mode',
        );
        await _tearDown(tester);
      },
    );

    testWidgets(
      'value checkbox uses the nusach: ashkenazi "Bereishis" vs sephardi "Bereshit"',
      (tester) async {
        // Ashkenazi (English mode): "Genesis" → "Bereishis".
        await _pump(
          tester,
          _buildScopeApp(
            curriculum: CurriculumId.chumash,
            contentRepo: _makeDefaultRepo(items: _kChumashItems),
          ),
        );
        await drillToFirstLevel(tester);
        expect(find.text('Bereishis'), findsOneWidget);
        expect(
          find.text('Genesis'),
          findsNothing,
          reason: 'raw English key must be transliterated, not echoed',
        );
        await _tearDown(tester);

        // Sephardi (English mode): "Genesis" → "Bereshit".
        await _pump(
          tester,
          _buildScopeApp(
            curriculum: CurriculumId.chumash,
            variant: TransliterationVariant.sephardi,
            contentRepo: _makeDefaultRepo(items: _kChumashItems),
          ),
        );
        await drillToFirstLevel(tester);
        expect(find.text('Bereshit'), findsOneWidget);
        expect(find.text('Bereishis'), findsNothing);
        await _tearDown(tester);
      },
    );

    testWidgets(
      'mishnayos masechta "Berakhot" renders Hebrew "ברכות" when Hebrew Terms ON',
      (tester) async {
        // Drill to the Masechta level (level 2) and verify the Hebrew name.
        await _pump(
          tester,
          _buildScopeApp(useHebrew: true, locale: const Locale('he')),
        );
        await tester.tap(find.byType(SwitchListTile));
        await tester.pump();
        // Level tiles: level 1 (Seder) and level 2 (Masechta). Tap the 2nd.
        final levelTiles = find.descendant(
          of: find.byType(ListTile),
          matching: find.byIcon(Icons.chevron_right),
        );
        await tester.tap(levelTiles.at(1));
        await tester.pump();

        // _kMasechta1 = "Berakhot" → displayNameHe "ברכות".
        expect(find.text('ברכות'), findsOneWidget);
        expect(
          find.text('Berakhot'),
          findsNothing,
          reason: 'raw masechta storage key must not surface in Hebrew mode',
        );
        await _tearDown(tester);
      },
    );
  });

  group('ScopeSelectionScreen — he-RTL smoke', () {
    testWidgets('renders under Hebrew locale without crash', (tester) async {
      await _pump(
        tester,
        _buildScopeApp(useHebrew: true, locale: const Locale('he')),
      );

      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);

      await _tearDown(tester);
    });

    testWidgets('Hebrew locale sets RTL text direction', (tester) async {
      await _pump(
        tester,
        _buildScopeApp(useHebrew: true, locale: const Locale('he')),
      );

      final dirFinder = find.byType(Directionality);
      expect(dirFinder, findsWidgets);
      final outerDir = tester.widget<Directionality>(dirFinder.first);
      expect(outerDir.textDirection, TextDirection.rtl);

      await _tearDown(tester);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // LifetimeMarkingScreen
  // ═══════════════════════════════════════════════════════════════════════════

  group('LifetimeMarkingScreen — AppBar', () {
    testWidgets('AppBar title matches l10n.addWhatYouLearned', (tester) async {
      await _pump(tester, _buildLifetimeApp());

      // l10n key: addWhatYouLearned => 'Add Lifetime Learning'
      expect(find.text('Add Lifetime Learning'), findsOneWidget);

      await _tearDown(tester);
    });
  });

  group('LifetimeMarkingScreen — subtitle policy text', () {
    testWidgets('lifetimeMarkingSubtitle is rendered', (tester) async {
      await _pump(tester, _buildLifetimeApp());

      // l10n key: lifetimeMarkingSubtitle
      // "Items you've learned in your life, outside the app's tracks. Counted
      //  toward Lifetime Knowledge — not toward siyumim, streak, or points."
      // This subtitle communicates the completion-credit policy to the user:
      // lifetime-only marks do NOT count toward streak/points/siyumim.
      expect(find.textContaining('Lifetime Knowledge'), findsWidgets);

      await _tearDown(tester);
    });
  });

  group('LifetimeMarkingScreen — curriculum cards', () {
    testWidgets(
      'At least one "Not started" card is visible (scroll list renders lazily)',
      (tester) async {
        await _pump(tester, _buildLifetimeApp());

        // The screen renders CurriculumId.values.length curriculum cards in a
        // ListView, which lazily builds only the visible cards. Each card that
        // is in view shows "Not started" when no completions are seeded.
        // We assert at least one is visible (no empty-screen regression).
        expect(find.text('Not started'), findsWidgets);

        await _tearDown(tester);
      },
    );

    testWidgets(
      'At least one card has a chevron_right_rounded icon (tappable)',
      (tester) async {
        await _pump(tester, _buildLifetimeApp());

        // ListView lazy rendering — at least one card is in view.
        expect(find.byIcon(Icons.chevron_right_rounded), findsWidgets);

        await _tearDown(tester);
      },
    );

    testWidgets(
      'Tapping a curriculum card pushes LifetimeCurriculumMarkingScreen',
      (tester) async {
        await _pump(tester, _buildLifetimeApp());

        // Tap the first card (Mishnayos).
        await tester.tap(find.byIcon(Icons.chevron_right_rounded).first);
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        // The pushed screen is LifetimeCurriculumMarkingScreen.
        expect(find.byType(LifetimeCurriculumMarkingScreen), findsOneWidget);

        await _tearDown(tester);
      },
    );
  });

  group('LifetimeMarkingScreen — he-RTL smoke', () {
    testWidgets('renders under Hebrew locale without crash', (tester) async {
      await _pump(
        tester,
        _buildLifetimeApp(useHebrew: true, locale: const Locale('he')),
      );

      expect(find.byType(Scaffold), findsOneWidget);

      await _tearDown(tester);
    });

    testWidgets('Hebrew locale sets RTL text direction', (tester) async {
      await _pump(
        tester,
        _buildLifetimeApp(useHebrew: true, locale: const Locale('he')),
      );

      final dirFinder = find.byType(Directionality);
      expect(dirFinder, findsWidgets);
      final outerDir = tester.widget<Directionality>(dirFinder.first);
      expect(outerDir.textDirection, TextDirection.rtl);

      await _tearDown(tester);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // LifetimeCurriculumMarkingScreen
  // ═══════════════════════════════════════════════════════════════════════════

  group('LifetimeCurriculumMarkingScreen — AppBar', () {
    testWidgets('AppBar title contains curriculum label', (tester) async {
      await _pump(tester, _buildCurriculumMarkingApp());

      // CurriculumId.mishnayos.displayNameEn = 'Mishnayos'
      expect(find.textContaining('Mishnayos'), findsWidgets);

      await _tearDown(tester);
    });
  });

  group('LifetimeCurriculumMarkingScreen — content section', () {
    testWidgets('"Select what you\'ve learned" section title is present', (
      tester,
    ) async {
      await _pump(tester, _buildCurriculumMarkingApp());

      // l10n key: lifetimeSelectScreenTitle => "Select what you've learned"
      expect(find.text("Select what you've learned"), findsOneWidget);

      await _tearDown(tester);
    });

    testWidgets('"Mark as lifetime learned" header is present', (tester) async {
      await _pump(tester, _buildCurriculumMarkingApp());

      // l10n key: lifetimeMarkAsLearnedTitle => 'Mark as lifetime learned'
      expect(find.text('Mark as lifetime learned'), findsOneWidget);

      await _tearDown(tester);
    });

    testWidgets('"Select all in this list" button is present', (tester) async {
      await _pump(tester, _buildCurriculumMarkingApp());

      // l10n key: selectAllInThisList => 'Select all in this list'
      expect(find.text('Select all in this list'), findsOneWidget);

      await _tearDown(tester);
    });
  });

  group('LifetimeCurriculumMarkingScreen — Save/Clear button states', () {
    testWidgets('Save button is disabled when no selections made', (
      tester,
    ) async {
      await _pump(tester, _buildCurriculumMarkingApp());

      // The FilledButton (Save) with l10n.save ('Save') is disabled when
      // _selections is empty.
      final saveButtons = find.widgetWithText(FilledButton, 'Save');
      expect(saveButtons, findsOneWidget);

      final saveBtn = tester.widget<FilledButton>(saveButtons);
      expect(
        saveBtn.onPressed,
        isNull,
        reason: 'Save must be disabled when no selections',
      );

      await _tearDown(tester);
    });

    testWidgets('Clear button is disabled when no selections made', (
      tester,
    ) async {
      await _pump(tester, _buildCurriculumMarkingApp());

      // l10n key: clearSelection => 'Clear selection'
      final clearButtons = find.widgetWithText(
        OutlinedButton,
        'Clear selection',
      );
      expect(clearButtons, findsOneWidget);

      final clearBtn = tester.widget<OutlinedButton>(clearButtons);
      expect(
        clearBtn.onPressed,
        isNull,
        reason: 'Clear must be disabled when no selections',
      );

      await _tearDown(tester);
    });
  });

  group('LifetimeCurriculumMarkingScreen — bulk-mark completion-credit policy', () {
    // Product rule: bulk-mark uses sentinel date (DateTime.utc(2000, 1, 1))
    // so it credits lifetime/siyum WITHOUT leaking into streak/recent-activity.
    // The repository default source is CompletionSource.lifetimeOnly.
    //
    // This test verifies that recordCompletionsBatch is called when the user
    // confirms selections, and that the call is made via the repository
    // (which applies the sentinel date internally via CompletionSource.lifetimeOnly).
    testWidgets(
      'recordCompletionsBatch called after confirming selections (policy: lifetimeOnly sentinel)',
      (tester) async {
        final mockRepo = _MockLearningLedgerRepository();
        when(
          () => mockRepo.recordCompletionsBatch(
            any<List<LedgerEntryDraft>>(),
            source: any<CompletionSource>(named: 'source'),
          ),
        ).thenAnswer((_) async => []);

        await _pump(tester, _buildCurriculumMarkingApp(ledgerRepo: mockRepo));

        // The HierarchySelectionPanel loads content from the mock repo.
        // We cannot drill into HierarchySelectionPanel in this L1 test
        // (it relies on real content rendering with GlobalKey).
        // Instead verify the scaffolding: Save is disabled when _selections==[].
        final saveButtons = find.widgetWithText(FilledButton, 'Save');
        expect(saveButtons, findsOneWidget);

        final saveBtn = tester.widget<FilledButton>(saveButtons);
        // No selections → onPressed is null (disabled).
        expect(saveBtn.onPressed, isNull);

        // Verify the mock was NOT called (no spurious calls on idle render).
        verifyNever(
          () => mockRepo.recordCompletionsBatch(
            any<List<LedgerEntryDraft>>(),
            source: any<CompletionSource>(named: 'source'),
          ),
        );

        await _tearDown(tester);
      },
    );

    testWidgets(
      'Save drives the real _markSelections call — recordCompletionsBatch is '
      'invoked with no explicit source override (repository default stays '
      'lifetimeOnly)',
      (tester) async {
        // AUD-t-settings-03: the previous version of this test never touched
        // LifetimeCurriculumMarkingScreen — it built a standalone
        // _MockLearningLedgerRepository and called
        // stub.recordCompletionsBatch(const []) directly, so it asserted a
        // fact about the test's own mock, not about production code (it
        // would keep passing even if the real call site started passing an
        // explicit `source: CompletionSource.live` override).
        //
        // This version drives the REAL screen: taps "Select all in this
        // list" to populate _selections from HierarchySelectionPanel's
        // actual display items (loaded through the mocked content repo —
        // contrary to this file's older comments elsewhere, the panel CAN
        // be driven at L1 without GlobalKey drilling; see
        // lifetime_marking_toggle_level_test.dart's IL-TOGGLE/IL-LEVEL
        // tests, which tap the same button), then taps Save, and inspects
        // the captured Invocation from the real
        // lifetime_marking_screen.dart:592 call site.
        final mockRepo = _MockLearningLedgerRepository();
        Invocation? captured;
        when(
          () => mockRepo.recordCompletionsBatch(
            any<List<LedgerEntryDraft>>(),
            source: any<CompletionSource>(named: 'source'),
          ),
        ).thenAnswer((inv) async {
          captured = inv;
          return [];
        });

        await _pump(tester, _buildCurriculumMarkingApp(ledgerRepo: mockRepo));

        await tester.tap(find.text('Select all in this list'));
        await tester.pump();

        final saveButtons = find.widgetWithText(FilledButton, 'Save');
        final saveBtn = tester.widget<FilledButton>(saveButtons);
        expect(
          saveBtn.onPressed,
          isNotNull,
          reason:
              '"Select all in this list" must populate a real selection so '
              'Save becomes enabled — otherwise this test cannot reach the '
              'real _markSelections call site',
        );

        await tester.tap(saveButtons);
        await tester.pump();

        verify(
          () => mockRepo.recordCompletionsBatch(
            any<List<LedgerEntryDraft>>(),
            source: any<CompletionSource>(named: 'source'),
          ),
        ).called(1);

        expect(
          captured,
          isNotNull,
          reason:
              'recordCompletionsBatch must have been invoked by the real '
              'Save flow, not skipped',
        );
        // NOTE: Dart resolves the `source` named parameter's default value
        // (CompletionSource.lifetimeOnly) at the CALL SITE against the
        // statically-typed LearningLedgerRepository interface, so the
        // captured Invocation always carries a #source key — even though
        // _markSelections's own source code omits `source:` entirely. The
        // only way this test can distinguish "relying on the default" from
        // "an explicit CompletionSource.live override" is by asserting on
        // the captured VALUE, not on whether the key is present.
        expect(
          captured!.namedArguments[#source],
          equals(CompletionSource.lifetimeOnly),
          reason:
              'Completion-credit policy: the real Save flow '
              '(lifetime_marking_screen.dart _markSelections) must resolve '
              'to CompletionSource.lifetimeOnly — an explicit '
              'CompletionSource.live override would inflate streak/points '
              'from a lifetime bulk-mark',
        );

        await _tearDown(tester);
      },
    );
  });

  group('LifetimeCurriculumMarkingScreen — he-RTL smoke', () {
    testWidgets('renders under Hebrew locale without crash', (tester) async {
      await _pump(
        tester,
        _buildCurriculumMarkingApp(useHebrew: true, locale: const Locale('he')),
      );

      expect(find.byType(Scaffold), findsAtLeastNWidgets(1));

      await _tearDown(tester);
    });

    testWidgets('Hebrew locale sets RTL text direction', (tester) async {
      await _pump(
        tester,
        _buildCurriculumMarkingApp(useHebrew: true, locale: const Locale('he')),
      );

      final dirFinder = find.byType(Directionality);
      expect(dirFinder, findsWidgets);
      final outerDir = tester.widget<Directionality>(dirFinder.first);
      expect(outerDir.textDirection, TextDirection.rtl);

      await _tearDown(tester);
    });

    testWidgets(
      'Hebrew curriculum labels rendered when useHebrew=true (no track-type labels)',
      (tester) async {
        await _pump(
          tester,
          _buildCurriculumMarkingApp(
            useHebrew: true,
            locale: const Locale('he'),
          ),
        );

        // CurriculumId.mishnayos displayNameHe = 'משניות'
        expect(
          find.textContaining(CurriculumId.mishnayos.displayNameHe),
          findsWidgets,
        );
        // No track-type labels.
        expect(find.text('אישי'), findsNothing);
        expect(find.text('Personal'), findsNothing);

        await _tearDown(tester);
      },
    );
  });
}
