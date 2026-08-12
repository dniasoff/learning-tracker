/// AUD-learning-01: detection failures must be logged without failing the
/// primary Firestore completion write.
@Tags(['epic_3', 'b1_credit_policy'])
library;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart';
import 'package:learning_tracker/data/repositories/firestore_completion_repository.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_request.dart';
import 'package:learning_tracker/features/learning/domain/repositories/completion_repository.dart';
import 'package:learning_tracker/features/learning/domain/repositories/learning_ledger_repository.dart';
import 'package:learning_tracker/features/learning/domain/services/completion_detection_service.dart';
import 'package:learning_tracker/features/learning/domain/services/completion_orchestrator.dart';
import 'package:learning_tracker/features/learning/presentation/providers/completion_providers.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/firestore_fake.dart';

class _MockContentRepository extends Mock implements ContentRepository {}

class _MockLearningLedgerRepository extends Mock
    implements LearningLedgerRepository {}

void main() {
  setUpAll(() {
    registerFallbackValue(CurriculumId.mishnayos);
  });

  const uid = 'siyum-failure-uid';
  const profileId = 'siyum-failure-profile-ulid';
  const leafRef = 'Mishnah_Berakhot_1';

  late FakeFirebaseFirestore firestore;
  late ProviderContainer container;
  late _MockContentRepository contentRepository;
  late CompletionRepository completionRepository;
  late CompletionOrchestrator orchestrator;

  setUp(() {
    AppLogger.init();
    firestore = createFakeFirestore(authenticatedUid: uid);
    final firestoreRepository = FirestoreCompletionRepository(
      firestore: firestore,
      uid: uid,
      profileId: profileId,
    );
    container = ProviderContainer(
      overrides: [
        firestoreCompletionRepositoryProvider.overrideWith(
          (ref) async => firestoreRepository,
        ),
      ],
    );
    addTearDown(container.dispose);

    contentRepository = _MockContentRepository();
    when(
      () => contentRepository.getContentByRef(
        curriculumId: any(named: 'curriculumId'),
        sefariaRef: any(named: 'sefariaRef'),
      ),
    ).thenThrow(Exception('simulated content lookup failure'));
    when(
      () => contentRepository.getContentForCurriculum(any()),
    ).thenAnswer((_) async => []);

    completionRepository = container.read(completionRepositoryProvider);
    final detectionService = CompletionDetectionService(
      completionRepository: completionRepository,
      contentRepository: contentRepository,
      ledgerRepository: _MockLearningLedgerRepository(),
    );
    orchestrator = CompletionOrchestrator(
      repository: completionRepository,
      contentRepository: contentRepository,
      activeProfileId: profileId,
      completionDetectionService: detectionService,
    );
  });

  group('AUD-learning-01 — siyum detection failure is not silently lost', () {
    test('markComplete returns successfully when detection throws', () async {
      final result = await orchestrator.markComplete(
        const CompletionRequest(
          curriculumId: 'mishnayos',
          sefariaRef: leafRef,
          stageId: 1,
          trackType: 'personal',
        ),
      );

      expect(result.completion.sefariaRef, leafRef);
    });

    test('detection failure is logged via AppLogger', () async {
      await orchestrator.markComplete(
        const CompletionRequest(
          curriculumId: 'mishnayos',
          sefariaRef: leafRef,
          stageId: 1,
          trackType: 'personal',
        ),
      );
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      final history = AppLogger.instance.talker.history
          .map((event) => event.generateTextMessage())
          .toList();
      expect(
        history.any(
          (message) => message.contains('completion_siyum_detection_failed'),
        ),
        isTrue,
        reason: 'Talker history: $history',
      );
    });
  });
}
