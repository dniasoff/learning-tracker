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

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/progress/domain/models/journey_view_model.dart';
import 'package:learning_tracker/features/progress/presentation/providers/journey_providers.dart';
import 'package:learning_tracker/features/settings/presentation/providers/curriculum_activation_providers.dart';

import '../../../../helpers/drift_memory.dart';

const _profileId = 1;

/// Pins the Hebrew Terms toggle off so the milestone detector's call to
/// `curriculumLabelTextFromRef` (which reads [useHebrewTermsProvider])
/// doesn't try to hit a real SharedPreferences instance.
class _UseHebrewTermsOverride extends UseHebrewTerms {
  _UseHebrewTermsOverride();
  @override
  bool build() => false;
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

Future<int> _seedMasechtaLedger(
  UserDatabase db, {
  required CurriculumId curriculum,
  required String masechta,
  required DateTime at,
}) {
  return db.learningLedgerDao.insertEntry(
    LearningLedgerCompanion.insert(
      profileId: _profileId,
      curriculumId: curriculum.storageKey,
      entryScope: 'masechta',
      unitIdentifier: masechta,
      unitDisplayNameHe: masechta,
      unitDisplayNameEn: masechta,
      trackType: 'personal',
      completedAt: at,
      completionNumber: 1,
      markedBy: _profileId,
      isManual: const Value(false),
    ),
  );
}

/// Seed a ledger entry with an arbitrary [entryScope] and [unitIdentifier].
///
/// Required for F22 tests covering Chumash (scope='sefer') and
/// Mishna Berurah (scope='siman' / 'chelek').
Future<int> _seedLedgerEntry(
  UserDatabase db, {
  required CurriculumId curriculum,
  required String entryScope,
  required String unitIdentifier,
  required DateTime at,
}) {
  return db.learningLedgerDao.insertEntry(
    LearningLedgerCompanion.insert(
      profileId: _profileId,
      curriculumId: curriculum.storageKey,
      entryScope: entryScope,
      unitIdentifier: unitIdentifier,
      unitDisplayNameHe: unitIdentifier,
      unitDisplayNameEn: unitIdentifier,
      trackType: 'personal',
      completedAt: at,
      completionNumber: 1,
      markedBy: _profileId,
      isManual: const Value(false),
    ),
  );
}

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
/// All other providers (the actual milestone detector, the ledger DAO
/// query, the level tallies) run through their real implementations.
ProviderContainer _container({
  required UserDatabase db,
  required List<CurriculumId> activeCurricula,
  required Map<CurriculumId, List<ContentItem>> content,
}) {
  return ProviderContainer(
    overrides: [
      userDatabaseProvider.overrideWith((ref) => db),
      useHebrewTermsProvider.overrideWith(_UseHebrewTermsOverride.new),
      activeCurriculaProvider.overrideWith(
        (ref) => Future.value(activeCurricula),
      ),
      for (final entry in content.entries)
        curriculumContentProvider(
          entry.key,
        ).overrideWith((ref) => Future.value(entry.value)),
    ],
  );
}

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
    late UserDatabase db;

    setUp(() async {
      db = inMemoryDb();
      await seedProfile(db);
    });

    tearDown(() async => db.close());

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
            db,
            curriculum: CurriculumId.mishnayos,
            masechta: zeraimMasechtos[i],
            at: base.add(Duration(days: i)),
          );
        }

        final container = _container(
          db: db,
          activeCurricula: const [CurriculumId.mishnayos],
          content: {CurriculumId.mishnayos: _mishnayosContent()},
        );
        addTearDown(container.dispose);

        final vm = await container.read(
          journeyViewModelProvider(_profileId).future,
        );

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
              db,
              curriculum: CurriculumId.mishnayos,
              masechta: masechta,
              at: base.add(Duration(days: i++)),
            );
          }
        }

        final container = _container(
          db: db,
          activeCurricula: const [CurriculumId.mishnayos],
          content: {CurriculumId.mishnayos: content},
        );
        addTearDown(container.dispose);

        final vm = await container.read(
          journeyViewModelProvider(_profileId).future,
        );

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
          db,
          curriculum: CurriculumId.bavli,
          masechta: 'Berakhot',
          at: DateTime(2026, 5, 4),
        );

        final container = _container(
          db: db,
          activeCurricula: const [CurriculumId.bavli],
          content: {CurriculumId.bavli: _bavliMinimalContent()},
        );
        addTearDown(container.dispose);

        final vm = await container.read(
          journeyViewModelProvider(_profileId).future,
        );

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
        db: db,
        activeCurricula: const [CurriculumId.mishnayos],
        content: {CurriculumId.mishnayos: _mishnayosContent()},
      );
      addTearDown(container.dispose);

      final vm = await container.read(
        journeyViewModelProvider(_profileId).future,
      );

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
    late UserDatabase db;

    setUp(() async {
      db = inMemoryDb();
      await seedProfile(db);
    });

    tearDown(() async => db.close());

    test(
      'Chumash: one sefer in ledger → 1 unit · 0 aggregate · 0 curriculum',
      () async {
        // Seed Bereshit as scope='sefer' (the F2 fix outputs this for Chumash).
        await _seedLedgerEntry(
          db,
          curriculum: CurriculumId.chumash,
          entryScope: 'sefer',
          unitIdentifier: 'Bereshit',
          at: DateTime(2026, 5, 1),
        );

        final container = _container(
          db: db,
          activeCurricula: const [CurriculumId.chumash],
          content: {CurriculumId.chumash: _chumashContent()},
        );
        addTearDown(container.dispose);

        final vm = await container.read(
          journeyViewModelProvider(_profileId).future,
        );

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
            db,
            curriculum: CurriculumId.chumash,
            entryScope: 'sefer',
            unitIdentifier: sefarim[i],
            at: base.add(Duration(days: i)),
          );
        }

        final container = _container(
          db: db,
          activeCurricula: const [CurriculumId.chumash],
          content: {CurriculumId.chumash: _chumashContent()},
        );
        addTearDown(container.dispose);

        final vm = await container.read(
          journeyViewModelProvider(_profileId).future,
        );

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
          db,
          curriculum: CurriculumId.mishnaBerurah,
          entryScope: 'siman',
          unitIdentifier: 'Siman $i',
          at: base.add(Duration(days: i)),
        );
      }

      final container = _container(
        db: db,
        activeCurricula: const [CurriculumId.mishnaBerurah],
        content: {CurriculumId.mishnaBerurah: _mishnaBerurahContent()},
      );
      addTearDown(container.dispose);

      final vm = await container.read(
        journeyViewModelProvider(_profileId).future,
      );

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
          db,
          curriculum: CurriculumId.mishnaBerurah,
          entryScope: 'siman',
          unitIdentifier: 'Siman 1',
          at: DateTime(2026, 5, 1),
        );

        final container = _container(
          db: db,
          activeCurricula: const [CurriculumId.mishnaBerurah],
          content: {CurriculumId.mishnaBerurah: _mishnaBerurahContent()},
        );
        addTearDown(container.dispose);

        final vm = await container.read(
          journeyViewModelProvider(_profileId).future,
        );

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
    late UserDatabase db;

    setUp(() async {
      db = inMemoryDb();
      await seedProfile(db);
    });

    tearDown(() async => db.close());

    test(
      'two ledger entries for the same masechta yield exactly one unit milestone',
      () async {
        // Two entries — different timestamps, same unitIdentifier.
        await _seedMasechtaLedger(
          db,
          curriculum: CurriculumId.bavli,
          masechta: 'Berakhot',
          at: DateTime(2026, 5, 1),
        );
        await _seedMasechtaLedger(
          db,
          curriculum: CurriculumId.bavli,
          masechta: 'Berakhot',
          at: DateTime(2026, 5, 10),
        );

        final container = _container(
          db: db,
          activeCurricula: const [CurriculumId.bavli],
          content: {CurriculumId.bavli: _bavliMinimalContent()},
        );
        addTearDown(container.dispose);

        final vm = await container.read(
          journeyViewModelProvider(_profileId).future,
        );

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
        expect(unitMilestones.single.achievedAt, DateTime(2026, 5, 10));
      },
    );
  });
}
