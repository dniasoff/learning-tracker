/// Regression coverage for the Layer-3 migration to the Firestore completion
/// tier and curriculum identity model.
@Tags(['progress', 'migration', 'layer3'])
library;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/data/firestore/account_firebase.dart';
import 'package:learning_tracker/data/firestore/active_account_providers.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart'
    show activeProfileDocIdProvider;
import 'package:learning_tracker/features/learning/domain/entities/completion_source.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_tier_filter.dart';
import 'package:learning_tracker/features/progress/data/repositories/firestore_chart_data_repository_adapter.dart';
import 'package:learning_tracker/features/tracks/domain/services/track_progress_service.dart';
import 'package:learning_tracker/features/tracks/stages/domain/models/stage_definition.dart';
import 'package:learning_tracker/features/tracks/stages/domain/repositories/stage_definition_repository.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/firestore_fake.dart';
import '../../../../helpers/firestore_fixtures.dart';

class _MockFirebaseApp extends Mock implements FirebaseApp {}

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

class _Stages extends Fake implements StageDefinitionRepository {
  @override
  Future<List<StageDefinition>> getStagesForCurriculum(
    CurriculumId curriculum,
  ) async => [
    const StageDefinition(
      curriculumId: CurriculumId.mishnayos,
      stageOrder: 1,
      stageName: 'Learn',
      delayDays: 0,
      isDefault: true,
    ),
  ];
}

const _uid = 'track-dual-migration-user';
const _profileId = '01ARZ3NDEKTSV4RRFFQ69G5FAV';
const _curriculum = CurriculumId.mishnayos;
final _activatedAt = DateTime.utc(2026, 3, 1);
final _beforeActivation = DateTime.utc(2026, 2, 1);
final _afterActivation = DateTime.utc(2026, 4, 1);

void main() {
  late FakeFirebaseFirestore firestore;
  late ProviderContainer container;
  late TrackProgressService service;

  setUp(() async {
    firestore = createFakeFirestore(authenticatedUid: _uid);
    final handles = AccountFirebaseHandles(
      app: _MockFirebaseApp(),
      firestore: firestore,
      auth: _MockFirebaseAuth(),
      uid: _uid,
    );
    container = ProviderContainer(
      overrides: [
        activeAccountFirebaseProvider.overrideWith((ref) async => handles),
      ],
    );
    container.read(activeProfileDocIdProvider.notifier).set(_profileId);
    final adapterProvider = Provider<FirestoreChartDataRepositoryAdapter>(
      (ref) => FirestoreChartDataRepositoryAdapter(ref: ref),
    );
    service = TrackProgressService(
      repository: container.read(adapterProvider),
      stageRepo: _Stages(),
    );
  });

  tearDown(() => container.dispose());

  Future<void> mark(
    String ref, {
    required DateTime at,
    CompletionSource source = CompletionSource.live,
  }) async {
    await seedCompletion(
      firestore,
      uid: _uid,
      profileId: _profileId,
      curriculumId: _curriculum,
      sefariaRef: ref,
      stageId: 1,
      source: source,
      completedAt: at,
    );
  }

  group('currentCyclePercentage migration consistency', () {
    test(
      'live-only, all after activation: migrated percentage is 2/10',
      () async {
        await mark('ref1', at: _afterActivation);
        await mark('ref2', at: _afterActivation);
        final migrated = await service.completionPercent(
          curriculumId: _curriculum,
          tier: CompletionTierFilter.trackAchievement,
          totalItems: 10,
          requireAllStages: false,
          since: _activatedAt,
        );
        expect(migrated, closeTo(0.2, 1e-9));
      },
    );

    test('since filter excludes live marks before activation', () async {
      await mark('old_ref', at: _beforeActivation);
      await mark('new_ref', at: _afterActivation);
      final migrated = await service.completionPercent(
        curriculumId: _curriculum,
        tier: CompletionTierFilter.trackAchievement,
        totalItems: 10,
        requireAllStages: false,
        since: _activatedAt,
      );
      expect(migrated, closeTo(0.1, 1e-9));
    });

    test(
      'bulkInTrack after activation is included in trackAchievement',
      () async {
        await mark(
          'bulk_new',
          at: _afterActivation,
          source: CompletionSource.bulkInTrack,
        );
        final migrated = await service.completionPercent(
          curriculumId: _curriculum,
          tier: CompletionTierFilter.trackAchievement,
          totalItems: 10,
          requireAllStages: false,
          since: _activatedAt,
        );
        expect(migrated, closeTo(0.1, 1e-9));
      },
    );
  });
}
