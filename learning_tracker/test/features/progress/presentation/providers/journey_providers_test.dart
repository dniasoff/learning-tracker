/// Provider tests for [journeyViewModelProvider] — drives the real
/// provider through a [ProviderContainer] over an in-memory Drift database.
///
/// Verifies the three-level milestone breakdown introduced as part of the
/// Siyumim & Milestones screen restructure:
///
/// * Unit-level siyumim — one per masechta/sefer/siman/hilchos ledger
///   entry.
/// * Aggregate-level siyumim — one per seder/chelek whose every contained
///   masechta is in the ledger.
/// * Curriculum-level siyumim — one when every masechta/sefer in the
///   curriculum is in the ledger.
///
/// Content is supplied via an override on [curriculumContentProvider] so
/// the tests pin a known hierarchy shape. The activation list is supplied
/// via an override on [activeCurriculaProvider]. Everything else — the
/// ledger DAO, the milestone detector, the level tallies — runs through
/// the real implementation.
@Tags(['progress', 'journey'])
library;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/time/ulid.dart';
import 'package:learning_tracker/data/firestore/account_firebase.dart';
import 'package:learning_tracker/data/firestore/active_account_providers.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart'
    show activeProfileDocIdProvider;
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/progress/domain/models/journey_view_model.dart';
import 'package:learning_tracker/features/progress/presentation/providers/journey_providers.dart';
import 'package:learning_tracker/features/settings/presentation/providers/curriculum_activation_providers.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/firestore_fake.dart';
import '../../../../helpers/firestore_fixtures.dart';

const _uid = 'journey-provider-suite-user';
const _profileId = '01ARZ3NDEKTSV4RRFFQ69G5FAV';

/// Pins the Hebrew Terms toggle off so the milestone detector's call to
/// `curriculumLabelTextFromRef` (which reads [useHebrewTermsProvider])
/// doesn't try to hit a real SharedPreferences instance.
class _UseHebrewTermsOverride extends UseHebrewTerms {
  _UseHebrewTermsOverride();
  @override
  bool build() => false;
}

/// Pin the nusach so curriculumLabelTextFromRef (now variant-aware) does not
/// reach the SharedPreferences-backed real provider in this binding-less
/// ProviderContainer unit test.
class _VariantOverride extends CurrentTransliterationVariant {
  _VariantOverride();
  @override
  TransliterationVariant build() => TransliterationVariant.ashkenazi;
}

/// Build a representative Mishnayos content list — six sederim, each with
/// its full masechta list (counts match the canonical hierarchy: 11/12/
/// 7/10/11/12 = 63 masechtos). Sufficient to exercise per-seder and
/// curriculum-level detection without loading the bundled JSON.
List<ContentItem> _mishnayosContent() {
  final sederim = <String, List<String>>{
    'Zeraim': [
      'Berakhot',
      'Peah',
      'Demai',
      'Kilayim',
      'Sheviit',
      'Terumot',
      'Maasrot',
      'Maaser Sheni',
      'Challah',
      'Orlah',
      'Bikkurim',
    ],
    'Moed': [
      'Shabbat',
      'Eruvin',
      'Pesachim',
      'Shekalim',
      'Yoma',
      'Sukkah',
      'Beitzah',
      'Rosh Hashanah',
      'Taanit',
      'Megillah',
      'Moed Katan',
      'Chagigah',
    ],
    'Nashim': [
      'Yevamot',
      'Ketubot',
      'Nedarim',
      'Nazir',
      'Sotah',
      'Gittin',
      'Kiddushin',
    ],
    'Nezikin': [
      'Bava Kamma',
      'Bava Metzia',
      'Bava Batra',
      'Sanhedrin',
      'Makkot',
      'Shevuot',
      'Eduyot',
      'Avodah Zarah',
      'Avot',
      'Horayot',
    ],
    'Kodashim': [
      'Zevachim',
      'Menachot',
      'Chullin',
      'Bekhorot',
      'Arakhin',
      'Temurah',
      'Keritot',
      'Meilah',
      'Tamid',
      'Middot',
      'Kinnim',
    ],
    'Tahorot': [
      'Kelim',
      'Oholot',
      'Negaim',
      'Parah',
      'Tahorot',
      'Mikvaot',
      'Niddah',
      'Makhshirin',
      'Zavim',
      'Tevul Yom',
      'Yadayim',
      'Uktzin',
    ],
  };
  final items = <ContentItem>[];
  var sortOrder = 0;
  for (final entry in sederim.entries) {
    for (final masechta in entry.value) {
      // A single leaf per masechta is enough — the detector keys off
      // (level1, level2) groupings, not leaf cardinality.
      items.add(
        ContentItem(
          curriculumId: CurriculumId.mishnayos.storageKey,
          level1: entry.key,
          level2: masechta,
          displayNameHe: masechta,
          displayNameEn: masechta,
          sefariaRef: 'Mishnah $masechta 1.1',
          sortOrder: sortOrder++,
          isLeaf: true,
        ),
      );
    }
  }
  return items;
}

/// Build a representative Bavli content list with two sederim — Zeraim has
/// two masechtos (Berakhot, Shabbat-as-placeholder isn't valid for Bavli
/// hierarchy, so use Berakhot + Peah within Zeraim) and Moed has one. This
/// way completing only Berakhot leaves Zeraim incomplete (Peah is still
/// missing) so no aggregate siyum fires.
List<ContentItem> _bavliMinimalContent() {
  return const [
    ContentItem(
      curriculumId: 'bavli',
      level1: 'Zeraim',
      level2: 'Berakhot',
      displayNameHe: 'ברכות',
      displayNameEn: 'Berakhot',
      sefariaRef: 'Berakhot 2a',
      sortOrder: 0,
      isLeaf: true,
    ),
    ContentItem(
      curriculumId: 'bavli',
      level1: 'Zeraim',
      level2: 'Peah',
      displayNameHe: 'פאה',
      displayNameEn: 'Peah',
      sefariaRef: 'Peah 2a',
      sortOrder: 1,
      isLeaf: true,
    ),
    ContentItem(
      curriculumId: 'bavli',
      level1: 'Moed',
      level2: 'Shabbat',
      displayNameHe: 'שבת',
      displayNameEn: 'Shabbat',
      sefariaRef: 'Shabbat 2a',
      sortOrder: 2,
      isLeaf: true,
    ),
  ];
}

Future<void> _seedMasechtaLedger(
  FakeFirebaseFirestore firestore, {
  required CurriculumId curriculum,
  required String masechta,
  required DateTime at,
}) => seedLedgerEntry(
  firestore,
  uid: _uid,
  profileId: _profileId,
  ulid: newUlid(),
  curriculumId: curriculum,
  entryScope: 'masechta',
  unitIdentifier: masechta,
  unitDisplayNameHe: masechta,
  unitDisplayNameEn: masechta,
  completedAt: at,
);

Future<void> _seedLedgerEntry(
  FakeFirebaseFirestore firestore, {
  required CurriculumId curriculum,
  required String entryScope,
  required String unitIdentifier,
  required DateTime at,
}) => seedLedgerEntry(
  firestore,
  uid: _uid,
  profileId: _profileId,
  ulid: newUlid(),
  curriculumId: curriculum,
  entryScope: entryScope,
  unitIdentifier: unitIdentifier,
  unitDisplayNameHe: unitIdentifier,
  unitDisplayNameEn: unitIdentifier,
  completedAt: at,
);

/// Build a minimal Chumash content list — three sefarim (Bereshit, Shemot,
/// Vayikra), level-1-only (no level2). This matches the actual Chumash
/// hierarchy where the sefer IS the unit and there is no aggregate tier.
List<ContentItem> _chumashContent() {
  const sefarim = ['Bereshit', 'Shemot', 'Vayikra'];
  return [
    for (var i = 0; i < sefarim.length; i++)
      ContentItem(
        curriculumId: CurriculumId.chumash.storageKey,
        level1: sefarim[i],
        displayNameHe: sefarim[i],
        displayNameEn: sefarim[i],
        sefariaRef: '${sefarim[i]} 1.1',
        sortOrder: i,
        isLeaf: true,
      ),
  ];
}

/// Build a minimal Mishna Berurah content list — chelek 1 (Orach Chaim)
/// with three simanim, plus chelek 2 with one siman. Sufficient to test
/// both `'siman'` (unit) and `'chelek'` (aggregate) scopes.
List<ContentItem> _mishnaBerurahContent() {
  return const [
    ContentItem(
      curriculumId: 'mishna_berurah',
      level1: 'Chelek 1',
      level2: 'Siman 1',
      displayNameHe: 'סימן א',
      displayNameEn: 'Siman 1',
      sefariaRef: 'MB 1.1',
      sortOrder: 0,
      isLeaf: true,
    ),
    ContentItem(
      curriculumId: 'mishna_berurah',
      level1: 'Chelek 1',
      level2: 'Siman 2',
      displayNameHe: 'סימן ב',
      displayNameEn: 'Siman 2',
      sefariaRef: 'MB 1.2',
      sortOrder: 1,
      isLeaf: true,
    ),
    ContentItem(
      curriculumId: 'mishna_berurah',
      level1: 'Chelek 1',
      level2: 'Siman 3',
      displayNameHe: 'סימן ג',
      displayNameEn: 'Siman 3',
      sefariaRef: 'MB 1.3',
      sortOrder: 2,
      isLeaf: true,
    ),
    ContentItem(
      curriculumId: 'mishna_berurah',
      level1: 'Chelek 2',
      level2: 'Siman 4',
      displayNameHe: 'סימן ד',
      displayNameEn: 'Siman 4',
      sefariaRef: 'MB 2.4',
      sortOrder: 3,
      isLeaf: true,
    ),
  ];
}

/// Build a [ProviderContainer] with overrides that pin the in-memory DB,
/// the active curricula list, and curriculum-specific content.
///
/// [granularity] pins the siyum-granularity gate for every active curriculum
/// (via `siyumGranularityProvider`). It defaults to [MilestoneLevel.unit] — the
/// finest tier — which is a pass-through filter, so the pre-gate assertions
/// throughout this file keep their original expected values. Overriding it is
/// also necessary to keep this binding-less container off SharedPreferences
/// (the real notifier reads it in `build`), mirroring the existing
/// useHebrewTerms / variant overrides.
///
/// All other providers (the actual milestone detector, the ledger DAO
/// query, the level tallies) run through their real implementations.
ProviderContainer _container({
  required FakeFirebaseFirestore firestore,
  required List<CurriculumId> activeCurricula,
  required Map<CurriculumId, List<ContentItem>> content,
  MilestoneLevel granularity = MilestoneLevel.unit,
}) {
  final handles = AccountFirebaseHandles(
    app: _MockFirebaseApp(),
    firestore: firestore,
    auth: _MockFirebaseAuth(),
    uid: _uid,
  );
  final container = ProviderContainer(
    overrides: [
      activeAccountFirebaseProvider.overrideWith((ref) async => handles),
      activeProfileIdProvider.overrideWith(() => _ActiveProfileOverride()),
      useHebrewTermsProvider.overrideWith(_UseHebrewTermsOverride.new),
      currentTransliterationVariantProvider.overrideWith(_VariantOverride.new),
      activeCurriculaProvider.overrideWith(
        (ref) => Future.value(activeCurricula),
      ),
      contentRepositoryProvider.overrideWithValue(_ContentRepository(content)),
      for (final entry in content.entries)
        curriculumContentProvider(
          entry.key,
        ).overrideWith((ref) => Future.value(entry.value)),
      for (final curriculum in activeCurricula)
        siyumGranularityProvider(curriculum).overrideWithValue(granularity),
    ],
  );
  container.read(activeProfileDocIdProvider.notifier).set(_profileId);
  return container;
}

class _MockFirebaseApp extends Mock implements FirebaseApp {}

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

class _ActiveProfileOverride extends ActiveProfileId {
  @override
  String? build() => _profileId;
}

class _ContentRepository extends Fake implements ContentRepository {
  _ContentRepository(this._content);
  final Map<CurriculumId, List<ContentItem>> _content;
  @override
  Future<List<ContentItem>> getContentForCurriculum(CurriculumId c) async =>
      _content[c] ?? const [];
}

/// Mishnayos content with a SINGLE seder (Zeraim) of two masechtos — the
/// minimal shape that emits ALL three milestone tiers when both masechtos are
/// in the ledger: 2 unit + 1 aggregate (Zeraim complete) + 1 curriculum (both
/// of the two total units complete). Used by the granularity-gate tests.
List<ContentItem> _oneSederContent() => const [
  ContentItem(
    curriculumId: 'mishnayos',
    level1: 'Zeraim',
    level2: 'Berakhot',
    displayNameHe: 'ברכות',
    displayNameEn: 'Berakhot',
    sefariaRef: 'Mishnah Berakhot 1.1',
    sortOrder: 0,
    isLeaf: true,
  ),
  ContentItem(
    curriculumId: 'mishnayos',
    level1: 'Zeraim',
    level2: 'Peah',
    displayNameHe: 'פאה',
    displayNameEn: 'Peah',
    sefariaRef: 'Mishnah Peah 1.1',
    sortOrder: 1,
    isLeaf: true,
  ),
];

void main() {
  group('JourneySortModeValue', () {
    test('toggle between grouped and chronological', () {
      var mode = JourneySortModeValue.grouped;
      mode = mode == JourneySortModeValue.grouped
          ? JourneySortModeValue.chronological
          : JourneySortModeValue.grouped;
      expect(mode, JourneySortModeValue.chronological);
      mode = mode == JourneySortModeValue.grouped
          ? JourneySortModeValue.chronological
          : JourneySortModeValue.grouped;
      expect(mode, JourneySortModeValue.grouped);
    });
  });

  group('journeyViewModelProvider — three-level milestone breakdown', () {
    late FakeFirebaseFirestore firestore;

    setUp(() async {
      firestore = createFakeFirestore(authenticatedUid: _uid);
    });

    test(
      'Zeraim fully complete → 11 unit · 1 aggregate · 0 curriculum',
      () async {
        // Seed exactly the 11 masechtos in Seder Zeraim into the ledger.
        const zeraimMasechtos = [
          'Berakhot',
          'Peah',
          'Demai',
          'Kilayim',
          'Sheviit',
          'Terumot',
          'Maasrot',
          'Maaser Sheni',
          'Challah',
          'Orlah',
          'Bikkurim',
        ];
        final base = DateTime(2026, 1, 1);
        for (var i = 0; i < zeraimMasechtos.length; i++) {
          await _seedMasechtaLedger(
            firestore,
            curriculum: CurriculumId.mishnayos,
            masechta: zeraimMasechtos[i],
            at: base.add(Duration(days: i)),
          );
        }

        final container = _container(
          firestore: firestore,
          activeCurricula: const [CurriculumId.mishnayos],
          content: {CurriculumId.mishnayos: _mishnayosContent()},
        );
        addTearDown(container.dispose);

        final vm = await container.read(journeyViewModelProvider.future);

        expect(
          vm.unitLevelSiyumimCount,
          11,
          reason: 'one unit-level siyum per masechta in the ledger',
        );
        expect(
          vm.aggregateLevelSiyumimCount,
          1,
          reason: 'all 11 Zeraim masechtos complete → Siyum Seder Zeraim',
        );
        expect(
          vm.curriculumLevelSiyumimCount,
          0,
          reason: 'only one of six sederim complete → no curriculum siyum',
        );

        // The single CurriculumJourney for Mishnayos must carry all 12
        // milestone records (11 unit + 1 aggregate).
        final mishJourney = vm.curricula.firstWhere(
          (c) => c.curriculumId == CurriculumId.mishnayos,
        );
        expect(mishJourney.milestones, hasLength(12));
        expect(
          mishJourney.milestones
              .where((m) => m.level == MilestoneLevel.aggregate)
              .single
              .aggregateKey,
          'Zeraim',
        );
        expect(
          mishJourney.milestones
              .where((m) => m.level == MilestoneLevel.aggregate)
              .single
              .containedUnitKeys,
          containsAll(zeraimMasechtos),
        );
      },
    );

    test(
      'all Mishnayos complete → 63 unit · 6 aggregate · 1 curriculum',
      () async {
        // Seed every masechta from every seder.
        final content = _mishnayosContent();
        final sederim = <String, List<String>>{};
        for (final item in content) {
          if (item.level2 != null) {
            sederim.putIfAbsent(item.level1, () => []).add(item.level2!);
          }
        }
        final base = DateTime(2026, 1, 1);
        var i = 0;
        for (final entry in sederim.entries) {
          for (final masechta in entry.value) {
            await _seedMasechtaLedger(
              firestore,
              curriculum: CurriculumId.mishnayos,
              masechta: masechta,
              at: base.add(Duration(days: i++)),
            );
          }
        }

        final container = _container(
          firestore: firestore,
          activeCurricula: const [CurriculumId.mishnayos],
          content: {CurriculumId.mishnayos: content},
        );
        addTearDown(container.dispose);

        final vm = await container.read(journeyViewModelProvider.future);

        expect(
          vm.unitLevelSiyumimCount,
          63,
          reason: 'one unit-level siyum per masechta — Mishnayos has 63',
        );
        expect(
          vm.aggregateLevelSiyumimCount,
          6,
          reason: 'six sederim → six aggregate siyumim',
        );
        expect(
          vm.curriculumLevelSiyumimCount,
          1,
          reason: 'every masechta in the ledger → Siyum HaMishnayos',
        );
      },
    );

    test(
      'single Berakhot in Bavli → 1 unit · 0 aggregate · 0 curriculum',
      () async {
        // Seed exactly one masechta (Berakhot, Zeraim) into the ledger.
        await _seedMasechtaLedger(
          firestore,
          curriculum: CurriculumId.bavli,
          masechta: 'Berakhot',
          at: DateTime(2026, 5, 4),
        );

        final container = _container(
          firestore: firestore,
          activeCurricula: const [CurriculumId.bavli],
          content: {CurriculumId.bavli: _bavliMinimalContent()},
        );
        addTearDown(container.dispose);

        final vm = await container.read(journeyViewModelProvider.future);

        expect(
          vm.unitLevelSiyumimCount,
          1,
          reason: 'one masechta in the ledger → one unit siyum',
        );
        expect(
          vm.aggregateLevelSiyumimCount,
          0,
          reason: 'Berakhot is one of many in Zeraim → no aggregate siyum',
        );
        expect(
          vm.curriculumLevelSiyumimCount,
          0,
          reason: 'only one masechta of the whole Bavli curriculum',
        );

        // The single milestone must carry the unit metadata the screen
        // needs to render "Siyum Masechta Berakhot".
        final bavliJourney = vm.curricula.firstWhere(
          (c) => c.curriculumId == CurriculumId.bavli,
        );
        final unit = bavliJourney.milestones.single;
        expect(unit.level, MilestoneLevel.unit);
        expect(unit.unitKey, 'Berakhot');
        expect(unit.unitScope, 'masechta');
        expect(unit.parentAggregateKey, 'Zeraim');
      },
    );

    test('empty ledger → 0 milestones at every level', () async {
      final container = _container(
        firestore: firestore,
        activeCurricula: const [CurriculumId.mishnayos],
        content: {CurriculumId.mishnayos: _mishnayosContent()},
      );
      addTearDown(container.dispose);

      final vm = await container.read(journeyViewModelProvider.future);

      expect(vm.unitLevelSiyumimCount, 0);
      expect(vm.aggregateLevelSiyumimCount, 0);
      expect(vm.curriculumLevelSiyumimCount, 0);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // F22 (W7-A) — Coverage for non-Mishnayos/non-Bavli curricula.
  //
  // The original journey-provider tests only exercised Mishnayos / Bavli, both
  // of which use 'masechta' as the unit-level scope. The redesign brief
  // additionally covers Chumash (sefer-only) and Mishna Berurah (siman + chelek).
  // These tests would FAIL today before the F2 fix landed because the
  // hardcoded 'masechta'/'seder' scope strings never matched the journey
  // whitelist for these curricula.
  // ─────────────────────────────────────────────────────────────────────────

  group('F22 — non-Mishnayos curricula end-to-end', () {
    late FakeFirebaseFirestore firestore;

    setUp(() async {
      firestore = createFakeFirestore(authenticatedUid: _uid);
    });

    test(
      'Chumash: one sefer in ledger → 1 unit · 0 aggregate · 0 curriculum',
      () async {
        // Seed Bereshit as scope='sefer' (the F2 fix outputs this for Chumash).
        await _seedLedgerEntry(
          firestore,
          curriculum: CurriculumId.chumash,
          entryScope: 'sefer',
          unitIdentifier: 'Bereshit',
          at: DateTime.utc(2026, 5, 1),
        );

        final container = _container(
          firestore: firestore,
          activeCurricula: const [CurriculumId.chumash],
          content: {CurriculumId.chumash: _chumashContent()},
        );
        addTearDown(container.dispose);

        final vm = await container.read(journeyViewModelProvider.future);

        expect(
          vm.unitLevelSiyumimCount,
          1,
          reason:
              'Chumash sefer ledger entry (scope=sefer) counts as a '
              'unit-level siyum per the whitelist.',
        );
        expect(
          vm.aggregateLevelSiyumimCount,
          0,
          reason:
              'Chumash has no aggregate tier — content has no level2 so '
              '_hasAggregateLevel returns false.',
        );
        expect(
          vm.curriculumLevelSiyumimCount,
          0,
          reason: 'only 1 of 3 Chumash sefarim is complete',
        );

        final chumashJourney = vm.curricula.firstWhere(
          (c) => c.curriculumId == CurriculumId.chumash,
        );
        final unit = chumashJourney.milestones.single;
        expect(unit.level, MilestoneLevel.unit);
        expect(unit.unitKey, 'Bereshit');
        expect(unit.unitScope, 'sefer');
      },
    );

    test(
      'Chumash: all 3 sefarim → 3 unit · 0 aggregate · 1 curriculum',
      () async {
        const sefarim = ['Bereshit', 'Shemot', 'Vayikra'];
        final base = DateTime(2026, 5, 1);
        for (var i = 0; i < sefarim.length; i++) {
          await _seedLedgerEntry(
            firestore,
            curriculum: CurriculumId.chumash,
            entryScope: 'sefer',
            unitIdentifier: sefarim[i],
            at: base.add(Duration(days: i)),
          );
        }

        final container = _container(
          firestore: firestore,
          activeCurricula: const [CurriculumId.chumash],
          content: {CurriculumId.chumash: _chumashContent()},
        );
        addTearDown(container.dispose);

        final vm = await container.read(journeyViewModelProvider.future);

        expect(vm.unitLevelSiyumimCount, 3);
        expect(vm.aggregateLevelSiyumimCount, 0);
        expect(
          vm.curriculumLevelSiyumimCount,
          1,
          reason:
              'all sefarim complete → Siyum Chumash curriculum-level '
              'milestone fires',
        );
      },
    );

    test('Mishna Berurah: siman + chelek scopes in ledger', () async {
      // Seed all 3 simanim within Chelek 1 plus the chelek-level entry.
      // The provider's milestone detection should:
      //   - emit 3 unit-level siyumim (one per siman)
      //   - emit 1 aggregate-level siyum (Chelek 1 — all simanim complete)
      //   - emit 0 curriculum-level (Chelek 2's siman 4 is missing)
      final base = DateTime(2026, 5, 1);
      for (var i = 1; i <= 3; i++) {
        await _seedLedgerEntry(
          firestore,
          curriculum: CurriculumId.mishnaBerurah,
          entryScope: 'siman',
          unitIdentifier: 'Siman $i',
          at: base.add(Duration(days: i)),
        );
      }

      final container = _container(
        firestore: firestore,
        activeCurricula: const [CurriculumId.mishnaBerurah],
        content: {CurriculumId.mishnaBerurah: _mishnaBerurahContent()},
      );
      addTearDown(container.dispose);

      final vm = await container.read(journeyViewModelProvider.future);

      expect(
        vm.unitLevelSiyumimCount,
        3,
        reason:
            'three simanim in the ledger → three unit-level siyumim. '
            "Pre-F2 fix, the scope was hardcoded to 'masechta' but the "
            "whitelist accepts 'siman' too — counter still correct, but "
            "the scope on the row was wrong (broke the screen's label "
            'lookup).',
      );
      expect(
        vm.aggregateLevelSiyumimCount,
        1,
        reason:
            'Chelek 1 contains simanim 1, 2, 3 — all complete, so the '
            'aggregate siyum fires for Chelek 1.',
      );
      expect(
        vm.curriculumLevelSiyumimCount,
        0,
        reason: "Chelek 2's Siman 4 is missing",
      );
    });

    test(
      'Mishna Berurah: only 1 siman complete → 1 unit · 0 aggregate',
      () async {
        await _seedLedgerEntry(
          firestore,
          curriculum: CurriculumId.mishnaBerurah,
          entryScope: 'siman',
          unitIdentifier: 'Siman 1',
          at: DateTime(2026, 5, 1),
        );

        final container = _container(
          firestore: firestore,
          activeCurricula: const [CurriculumId.mishnaBerurah],
          content: {CurriculumId.mishnaBerurah: _mishnaBerurahContent()},
        );
        addTearDown(container.dispose);

        final vm = await container.read(journeyViewModelProvider.future);

        expect(vm.unitLevelSiyumimCount, 1);
        expect(
          vm.aggregateLevelSiyumimCount,
          0,
          reason:
              'Chelek 1 contains 3 simanim but only 1 is complete → no '
              'aggregate siyum',
        );
      },
    );
  });

  // ─────────────────────────────────────────────────────────────────────────
  // F24 (W7-A) — Dedupe unit-level entries by [unitIdentifier].
  //
  // If a user completes a masechta, unticks it, then re-completes, the ledger
  // ends up with two entries for the same `unitIdentifier`. Pre-fix, the
  // milestone detector emitted two rows → the counter advertised 2 unit-level
  // siyumim for ONE masechta. The fix dedupes by unitIdentifier (latest wins).
  // ─────────────────────────────────────────────────────────────────────────

  group('F24 — unit-level dedup by unitIdentifier', () {
    late FakeFirebaseFirestore firestore;

    setUp(() async {
      firestore = createFakeFirestore(authenticatedUid: _uid);
    });

    test(
      'two ledger entries for the same masechta yield exactly one unit milestone',
      () async {
        // Two entries — different timestamps, same unitIdentifier.
        await _seedMasechtaLedger(
          firestore,
          curriculum: CurriculumId.bavli,
          masechta: 'Berakhot',
          at: DateTime(2026, 5, 1),
        );
        await _seedMasechtaLedger(
          firestore,
          curriculum: CurriculumId.bavli,
          masechta: 'Berakhot',
          at: DateTime.utc(2026, 5, 10),
        );

        final container = _container(
          firestore: firestore,
          activeCurricula: const [CurriculumId.bavli],
          content: {CurriculumId.bavli: _bavliMinimalContent()},
        );
        addTearDown(container.dispose);

        final vm = await container.read(journeyViewModelProvider.future);

        expect(
          vm.unitLevelSiyumimCount,
          1,
          reason:
              'F24: two ledger rows for the same masechta must collapse to '
              'one unit-level siyum. Pre-fix this read as 2.',
        );

        final bavliJourney = vm.curricula.firstWhere(
          (c) => c.curriculumId == CurriculumId.bavli,
        );
        final unitMilestones = bavliJourney.milestones
            .where((m) => m.level == MilestoneLevel.unit)
            .toList();
        expect(unitMilestones, hasLength(1));
        // Latest-wins: the milestone's date matches the later entry.
        expect(unitMilestones.single.achievedAt, DateTime.utc(2026, 5, 10));
      },
    );
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Configurable siyum granularity — the gate applied INSIDE journeyViewModel
  // after `_detectMilestones`. A single-seder Mishnayos ledger emits all three
  // tiers (2 unit + 1 aggregate + 1 curriculum); the chosen tier suppresses
  // anything finer than itself. `_detectMilestones` output is identical across
  // the three cases — only the gate differs.
  // ─────────────────────────────────────────────────────────────────────────

  group('siyum granularity gate — journeyViewModel filtering', () {
    // TQ-6: each test owns its in-memory DB via the sanctioned
    // `final firestore = createFakeFirestore(authenticatedUid: _uid); addTearDown(firestore.close);` form (not a group-level
    // setUp/tearDown), so the native handle is always closed.
    Future<FakeFirebaseFirestore> freshDb() async {
      final firestore = createFakeFirestore(authenticatedUid: _uid);
      final base = DateTime(2026, 1, 1);
      for (final (i, masechta) in ['Berakhot', 'Peah'].indexed) {
        await _seedMasechtaLedger(
          firestore,
          curriculum: CurriculumId.mishnayos,
          masechta: masechta,
          at: base.add(Duration(days: i)),
        );
      }
      return firestore;
    }

    Future<JourneyViewModel> readVm(
      FakeFirebaseFirestore firestore,
      MilestoneLevel granularity,
    ) async {
      final container = _container(
        firestore: firestore,
        activeCurricula: const [CurriculumId.mishnayos],
        content: {CurriculumId.mishnayos: _oneSederContent()},
        granularity: granularity,
      );
      addTearDown(container.dispose);
      return container.read(journeyViewModelProvider.future);
    }

    List<MilestoneLevel> levelsFor(JourneyViewModel vm) => vm.curricula
        .firstWhere((c) => c.curriculumId == CurriculumId.mishnayos)
        .milestones
        .map((m) => m.level)
        .toList();

    test(
      'chosen = unit → all three tiers fire (2 unit · 1 agg · 1 curr)',
      () async {
        final firestore = await freshDb();
        final vm = await readVm(firestore, MilestoneLevel.unit);

        expect(vm.unitLevelSiyumimCount, 2);
        expect(vm.aggregateLevelSiyumimCount, 1);
        expect(vm.curriculumLevelSiyumimCount, 1);
        expect(levelsFor(vm), hasLength(4));
      },
    );

    test(
      'chosen = aggregate → unit suppressed (0 unit · 1 agg · 1 curr)',
      () async {
        final firestore = await freshDb();
        final vm = await readVm(firestore, MilestoneLevel.aggregate);

        expect(
          vm.unitLevelSiyumimCount,
          0,
          reason: 'per-masechta siyumim suppressed at aggregate granularity',
        );
        expect(vm.aggregateLevelSiyumimCount, 1);
        expect(vm.curriculumLevelSiyumimCount, 1);
        final levels = levelsFor(vm);
        expect(levels, isNot(contains(MilestoneLevel.unit)));
        expect(levels, hasLength(2));
      },
    );

    test('chosen = curriculum → only the whole siyum fires (0·0·1)', () async {
      final firestore = await freshDb();
      final vm = await readVm(firestore, MilestoneLevel.curriculum);

      expect(vm.unitLevelSiyumimCount, 0);
      expect(
        vm.aggregateLevelSiyumimCount,
        0,
        reason: 'seder siyum suppressed at curriculum granularity',
      );
      expect(vm.curriculumLevelSiyumimCount, 1);
      expect(levelsFor(vm), [MilestoneLevel.curriculum]);
    });

    test(
      'DEFAULT-BEHAVIOUR EQUIVALENCE — default (unit) === unfiltered emission',
      () async {
        final firestore = await freshDb();
        // `_container` defaults granularity to unit (what an unset preference
        // resolves to). The result must be the full three-tier emission,
        // identical to pre-gate behaviour.
        final container = _container(
          firestore: firestore,
          activeCurricula: const [CurriculumId.mishnayos],
          content: {CurriculumId.mishnayos: _oneSederContent()},
        );
        addTearDown(container.dispose);
        final vm = await container.read(journeyViewModelProvider.future);

        expect(vm.unitLevelSiyumimCount, 2);
        expect(vm.aggregateLevelSiyumimCount, 1);
        expect(vm.curriculumLevelSiyumimCount, 1);
        expect(
          levelsFor(vm),
          hasLength(4),
          reason: 'no preference set (default unit) must emit every tier',
        );
      },
    );
  });
}
