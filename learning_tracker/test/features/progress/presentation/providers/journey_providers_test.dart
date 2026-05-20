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

    test(
      'empty ledger → 0 milestones at every level',
      () async {
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
      },
    );
  });
}
