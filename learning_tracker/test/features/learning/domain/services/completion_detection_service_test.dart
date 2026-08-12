import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart';
import 'package:learning_tracker/data/repositories/firestore_completion_repository.dart';
import 'package:learning_tracker/data/repositories/firestore_learning_ledger_repository.dart';
import 'package:learning_tracker/data/repositories/firestore_stage_definition_repository.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/learning/data/repositories/completion_repository_impl.dart';
import 'package:learning_tracker/features/learning/data/repositories/learning_ledger_repository_impl.dart';
import 'package:learning_tracker/features/learning/domain/repositories/completion_repository.dart';
import 'package:learning_tracker/features/learning/domain/repositories/learning_ledger_repository.dart';
import 'package:learning_tracker/features/learning/domain/services/completion_detection_service.dart';
import 'package:learning_tracker/features/tracks/stages/data/repositories/stage_definition_repository_impl.dart';
import 'package:learning_tracker/features/tracks/stages/domain/models/schedule_type.dart';
import 'package:learning_tracker/features/tracks/stages/domain/models/stage_definition.dart';
import 'package:learning_tracker/features/tracks/stages/domain/repositories/stage_definition_repository.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/firestore_fake.dart';
import '../../../../helpers/firestore_fixtures.dart';

class _MockContentRepository extends Mock implements ContentRepository {}

class _CountingCompletionRepository extends Mock
    implements CompletionRepository {
  int curriculumReads = 0;
}

const _uid = 'detection-uid';
const _profileId = 'detection-profile-ulid';

void main() {
  setUpAll(() {
    registerFallbackValue(CurriculumId.mishnayos);
  });

  late FakeFirebaseFirestore firestore;
  late ProviderContainer container;
  late FirestoreCompletionRepository completionStore;
  late FirestoreLearningLedgerRepository ledgerStore;
  late _MockContentRepository contentRepository;

  setUp(() {
    firestore = createFakeFirestore(authenticatedUid: _uid);
    completionStore = FirestoreCompletionRepository(
      firestore: firestore,
      uid: _uid,
      profileId: _profileId,
    );
    ledgerStore = FirestoreLearningLedgerRepository(
      firestore: firestore,
      uid: _uid,
      profileId: _profileId,
    );
    final stageStore = FirestoreStageDefinitionRepository(
      firestore: firestore,
      uid: _uid,
      profileId: _profileId,
    );
    container = ProviderContainer(
      overrides: [
        firestoreCompletionRepositoryProvider.overrideWith(
          (ref) async => completionStore,
        ),
        firestoreLearningLedgerRepositoryProvider.overrideWith(
          (ref) async => ledgerStore,
        ),
        firestoreStageDefinitionRepositoryProvider.overrideWith(
          (ref) async => stageStore,
        ),
      ],
    );
    container.read(activeProfileDocIdProvider.notifier).set(_profileId);
    addTearDown(container.dispose);
    contentRepository = _MockContentRepository();
  });

  Future<void> insertStages(CurriculumId curriculum, {int count = 1}) async {
    await seedStageDefinitions(
      firestore,
      uid: _uid,
      profileId: _profileId,
      curriculumId: curriculum,
      stages: [
        for (var order = 1; order <= count; order++)
          StageDefinition(
            id: kFirestoreUnmappedStageId,
            curriculumId: curriculum,
            stageOrder: order,
            stageName: 'Stage $order',
            delayDays: 0,
            isDefault: true,
            scheduleType: ScheduleType.delay,
          ),
      ],
    );
  }

  Future<void> insertCompletion(
    String sefariaRef,
    CurriculumId curriculum, {
    int stageId = 1,
    String trackType = 'personal',
  }) => seedCompletion(
    firestore,
    uid: _uid,
    profileId: _profileId,
    curriculumId: curriculum,
    sefariaRef: sefariaRef,
    stageId: stageId,
    trackType: trackType,
  );

  CompletionDetectionService createService({
    CompletionRepository? completionRepository,
  }) {
    final completionProvider = Provider<CompletionRepository>(
      (ref) => FirestoreCompletionRepositoryAdapter(ref: ref),
    );
    final ledgerProvider = Provider<LearningLedgerRepository>(
      (ref) => FirestoreLearningLedgerRepositoryAdapter(
        ref: ref,
        activeProfileMode: ProfileMode.adult,
      ),
    );
    final stageProvider = Provider<StageDefinitionRepository>(
      (ref) => FirestoreStageDefinitionRepositoryAdapter(ref: ref),
    );
    return CompletionDetectionService(
      completionRepository:
          completionRepository ?? container.read(completionProvider),
      contentRepository: contentRepository,
      ledgerRepository: container.read(ledgerProvider),
      stageRepository: container.read(stageProvider),
    );
  }

  List<ContentItem> createLeafItems(String seder, String masechta, int count) =>
      List.generate(
        count,
        (i) => ContentItem(
          curriculumId: CurriculumId.mishnayos.storageKey,
          level1: seder,
          level2: masechta,
          level3: 'Perek ${i + 1}',
          displayNameHe: 'משנה ${i + 1}',
          displayNameEn: 'Mishna ${i + 1}',
          sefariaRef: 'Mishnah_${masechta}_${i + 1}',
          sortOrder: i,
          isLeaf: true,
        ),
      );

  void stubUnit(ContentItem first, List<ContentItem> leaves) {
    when(
      () => contentRepository.getContentByRef(
        curriculumId: any(named: 'curriculumId'),
        sefariaRef: any(named: 'sefariaRef'),
      ),
    ).thenAnswer((_) async => first);
    when(
      () => contentRepository.filterByLevel(
        curriculumId: any(named: 'curriculumId'),
        level1: any(named: 'level1'),
        level2: any(named: 'level2'),
      ),
    ).thenAnswer((_) async => leaves);
  }

  group('CompletionDetectionService', () {
    test(
      'creates ledger entry when all leaves complete for masechta',
      () async {
        final leaves = createLeafItems('Zeraim', 'Berakhot', 2);
        stubUnit(leaves.first, leaves);
        await insertStages(CurriculumId.mishnayos);
        for (final leaf in leaves) {
          await insertCompletion(leaf.sefariaRef, CurriculumId.mishnayos);
        }

        await createService().checkAndRecordCompletions(
          curriculumId: CurriculumId.mishnayos.storageKey,
          sefariaRef: leaves.first.sefariaRef,
          trackType: 'personal',
        );

        final entries = await ledgerStore.getLifetimeLedger();
        expect(
          entries.any(
            (entry) =>
                entry.entryScope == 'masechta' &&
                entry.unitIdentifier == 'Berakhot',
          ),
          isTrue,
        );
      },
    );

    test('does NOT create entry when some leaves are incomplete', () async {
      final leaves = createLeafItems('Zeraim', 'Berakhot', 3);
      stubUnit(leaves.first, leaves);
      await insertStages(CurriculumId.mishnayos);
      for (final leaf in leaves.take(2)) {
        await insertCompletion(leaf.sefariaRef, CurriculumId.mishnayos);
      }

      await createService().checkAndRecordCompletions(
        curriculumId: CurriculumId.mishnayos.storageKey,
        sefariaRef: leaves.first.sefariaRef,
        trackType: 'personal',
      );

      expect(await ledgerStore.getLifetimeLedger(), isEmpty);
    });

    test(
      'issues constant-bounded queries regardless of leaf count (N+1 regression)',
      () async {
        final leaves = createLeafItems('Zeraim', 'Berakhot', 10);
        stubUnit(leaves.first, leaves);
        await insertStages(CurriculumId.mishnayos);
        for (final leaf in leaves) {
          await insertCompletion(leaf.sefariaRef, CurriculumId.mishnayos);
        }

        final countingRepository = _CountingCompletionRepository();
        when(
          () => countingRepository.getCompletionsByCurriculum(any()),
        ).thenAnswer((_) async {
          countingRepository.curriculumReads++;
          return completionStore.getCompletionsForCurriculum(
            CurriculumId.mishnayos,
          );
        });

        await createService(
          completionRepository: countingRepository,
        ).checkAndRecordCompletions(
          curriculumId: CurriculumId.mishnayos.storageKey,
          sefariaRef: leaves.first.sefariaRef,
          trackType: 'personal',
        );

        // Mishnayos checks both level 2 and level 1, one bulk read each.
        expect(countingRepository.curriculumReads, 2);

        final smallerLeaves = createLeafItems('Zeraim', 'Berakhot', 2);
        stubUnit(smallerLeaves.first, smallerLeaves);
        countingRepository.curriculumReads = 0;
        await createService(
          completionRepository: countingRepository,
        ).checkAndRecordCompletions(
          curriculumId: CurriculumId.mishnayos.storageKey,
          sefariaRef: smallerLeaves.first.sefariaRef,
          trackType: 'personal',
        );
        expect(countingRepository.curriculumReads, 2);
        expect(await ledgerStore.getLifetimeLedger(), isNotEmpty);
      },
    );

    test(
      'fires siyum on limud completion alone — chazara not required',
      () async {
        final leaves = createLeafItems('Zeraim', 'Berakhot', 2);
        stubUnit(leaves.first, leaves);
        await insertStages(CurriculumId.mishnayos, count: 2);
        for (final leaf in leaves) {
          await insertCompletion(leaf.sefariaRef, CurriculumId.mishnayos);
        }

        await createService().checkAndRecordCompletions(
          curriculumId: CurriculumId.mishnayos.storageKey,
          sefariaRef: leaves.first.sefariaRef,
          trackType: 'personal',
        );

        expect(await ledgerStore.getLifetimeLedger(), isNotEmpty);
      },
    );

    test(
      'does NOT fire siyum when some leaves miss limud completion',
      () async {
        final leaves = createLeafItems('Zeraim', 'Berakhot', 3);
        stubUnit(leaves.first, leaves);
        await insertStages(CurriculumId.mishnayos);
        for (final leaf in leaves.take(2)) {
          await insertCompletion(leaf.sefariaRef, CurriculumId.mishnayos);
        }

        await createService().checkAndRecordCompletions(
          curriculumId: CurriculumId.mishnayos.storageKey,
          sefariaRef: leaves.first.sefariaRef,
          trackType: 'personal',
        );

        expect(await ledgerStore.getLifetimeLedger(), isEmpty);
      },
    );
  });

  group('F2 — per-curriculum entry-scope strings', () {
    test(
      'Chumash level-1-only curriculum writes scope=sefer at level 1',
      () async {
        const curriculum = CurriculumId.chumash;
        const leaves = [
          ContentItem(
            curriculumId: 'chumash',
            level1: 'Bereshit',
            displayNameHe: 'בראשית',
            displayNameEn: 'Bereshit',
            sefariaRef: 'Genesis_1_1',
            sortOrder: 0,
            isLeaf: true,
          ),
          ContentItem(
            curriculumId: 'chumash',
            level1: 'Bereshit',
            displayNameHe: 'בראשית',
            displayNameEn: 'Bereshit',
            sefariaRef: 'Genesis_1_2',
            sortOrder: 1,
            isLeaf: true,
          ),
        ];
        stubUnit(leaves.first, leaves);
        await insertStages(curriculum);
        for (final leaf in leaves) {
          await insertCompletion(leaf.sefariaRef, curriculum);
        }

        await createService().checkAndRecordCompletions(
          curriculumId: curriculum.storageKey,
          sefariaRef: leaves.first.sefariaRef,
          trackType: 'personal',
        );

        final entries = await ledgerStore.getLifetimeLedger();
        expect(
          entries.where(
            (entry) =>
                entry.curriculumId == curriculum &&
                entry.entryScope == 'sefer' &&
                entry.unitIdentifier == 'Bereshit',
          ),
          hasLength(1),
        );
      },
    );

    test('Mishna Berurah level-2 detection writes scope=siman', () async {
      const curriculum = CurriculumId.mishnaBerurah;
      final leaves = [
        const ContentItem(
          curriculumId: 'mishna_berurah',
          level1: 'Chelek 1',
          level2: 'Siman 1',
          displayNameHe: 'סעיף א',
          displayNameEn: 'Seif 1',
          sefariaRef: 'MB_1_1_1',
          sortOrder: 0,
          isLeaf: true,
        ),
        const ContentItem(
          curriculumId: 'mishna_berurah',
          level1: 'Chelek 1',
          level2: 'Siman 1',
          displayNameHe: 'סעיף ב',
          displayNameEn: 'Seif 2',
          sefariaRef: 'MB_1_1_2',
          sortOrder: 1,
          isLeaf: true,
        ),
      ];
      stubUnit(leaves.first, leaves);
      await insertStages(curriculum);
      for (final leaf in leaves) {
        await insertCompletion(leaf.sefariaRef, curriculum);
      }

      await createService().checkAndRecordCompletions(
        curriculumId: curriculum.storageKey,
        sefariaRef: leaves.first.sefariaRef,
        trackType: 'personal',
      );

      final entries = await ledgerStore.getLifetimeLedger();
      expect(
        entries.where(
          (entry) =>
              entry.curriculumId == curriculum &&
              entry.entryScope == 'siman' &&
              entry.unitIdentifier == 'Siman 1',
        ),
        hasLength(1),
      );
      expect(
        entries.where(
          (entry) =>
              entry.curriculumId == curriculum &&
              entry.entryScope == 'chelek' &&
              entry.unitIdentifier == 'Chelek 1',
        ),
        hasLength(1),
      );
    });

    group('unitScopeFor helper', () {
      test('level 2', () {
        expect(unitScopeFor(CurriculumId.mishnayos, level: 2), 'masechta');
        expect(unitScopeFor(CurriculumId.bavli, level: 2), 'masechta');
        expect(unitScopeFor(CurriculumId.yerushalmi, level: 2), 'masechta');
        expect(unitScopeFor(CurriculumId.mishnaBerurah, level: 2), 'siman');
        expect(unitScopeFor(CurriculumId.mishnehTorah, level: 2), 'hilchos');
      });

      test('level 1', () {
        expect(unitScopeFor(CurriculumId.mishnayos, level: 1), 'seder');
        expect(unitScopeFor(CurriculumId.bavli, level: 1), 'seder');
        expect(unitScopeFor(CurriculumId.yerushalmi, level: 1), 'seder');
        expect(unitScopeFor(CurriculumId.mishnaBerurah, level: 1), 'chelek');
        expect(unitScopeFor(CurriculumId.chumash, level: 1), 'sefer');
        expect(unitScopeFor(CurriculumId.nach, level: 1), 'sefer');
        expect(unitScopeFor(CurriculumId.tanach, level: 1), 'sefer');
        expect(unitScopeFor(CurriculumId.mussar, level: 1), 'sefer');
        expect(unitScopeFor(CurriculumId.mishnehTorah, level: 1), 'sefer');
      });
    });
  });
}
