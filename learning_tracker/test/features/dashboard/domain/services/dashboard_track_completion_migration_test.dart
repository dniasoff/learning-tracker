/// Regression tests for the Layer 3 migration of
/// [dashboardTrackCompletionPercentageProvider] → [TrackProgressService].
///
/// Verifies the contract of the migrated provider:
/// 1. For live-only profiles, the result is identical to the old
///    TrackCompletionService.computeTrackPercentage path.
/// 2. For bulk-only profiles, trackAchievement counts bulkInTrack items.
/// 3. For mixed profiles containing lifetimeOnly rows, the migrated result
///    is correctly lower than the old all-tiers result (lifetimeOnly excluded).
@Tags(['dashboard', 'migration', 'layer3'])
library;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart';
import 'package:learning_tracker/data/repositories/firestore_completion_repository.dart';
import 'package:learning_tracker/data/repositories/firestore_learning_ledger_repository.dart';
import 'package:learning_tracker/data/repositories/firestore_stage_definition_repository.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_source.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_tier_filter.dart';
import 'package:learning_tracker/features/progress/data/repositories/firestore_chart_data_repository_adapter.dart';
import 'package:learning_tracker/features/tracks/domain/services/track_progress_service.dart';
import 'package:learning_tracker/features/tracks/stages/data/repositories/stage_definition_repository_impl.dart';
import 'package:learning_tracker/features/tracks/stages/domain/models/schedule_type.dart';
import 'package:learning_tracker/features/tracks/stages/domain/models/stage_definition.dart';

import '../../../../helpers/firestore_fake.dart';
import '../../../../helpers/firestore_fixtures.dart';

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const _uid = 'dashboard-migration-uid';
const _profileId = 'dashboard-migration-profile-ulid';
const _curriculum = CurriculumId.mishnayos;
final _liveAt = DateTime.utc(2026, 5, 1, 12);
final _bulkAt = DateTime.utc(2000, 1, 1);

final _trackProgressServiceProvider = Provider<TrackProgressService>(
  (ref) => TrackProgressService(
    repository: FirestoreChartDataRepositoryAdapter(ref: ref),
    stageRepo: FirestoreStageDefinitionRepositoryAdapter(ref: ref),
  ),
);

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Future<void> _seedLive(
  FakeFirebaseFirestore firestore, {
  required String ref,
}) => seedCompletion(
  firestore,
  uid: _uid,
  profileId: _profileId,
  curriculumId: _curriculum,
  sefariaRef: ref,
  completedAt: _liveAt,
  source: CompletionSource.live,
);

Future<void> _seedBulkInTrack(
  FakeFirebaseFirestore firestore, {
  required String ref,
}) => seedCompletion(
  firestore,
  uid: _uid,
  profileId: _profileId,
  curriculumId: _curriculum,
  sefariaRef: ref,
  completedAt: _bulkAt,
  source: CompletionSource.bulkInTrack,
);

Future<void> _seedLifetimeOnly(
  FakeFirebaseFirestore firestore, {
  required String ref,
}) => seedLedgerEntry(
  firestore,
  uid: _uid,
  profileId: _profileId,
  ulid: 'dashboard-lifetime-$ref',
  curriculumId: _curriculum,
  unitIdentifier: ref,
  completedAt: _bulkAt,
  source: CompletionSource.lifetimeOnly,
);

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late FakeFirebaseFirestore firestore;
  late ProviderContainer container;
  late FirestoreCompletionRepository completionRepository;
  late FirestoreLearningLedgerRepository ledgerRepository;
  late TrackProgressService service;

  setUp(() async {
    firestore = createFakeFirestore(authenticatedUid: _uid);
    completionRepository = FirestoreCompletionRepository(
      firestore: firestore,
      uid: _uid,
      profileId: _profileId,
    );
    ledgerRepository = FirestoreLearningLedgerRepository(
      firestore: firestore,
      uid: _uid,
      profileId: _profileId,
    );
    container = ProviderContainer(
      overrides: [
        firestoreCompletionRepositoryProvider.overrideWith(
          (ref) async => completionRepository,
        ),
        firestoreStageDefinitionRepositoryProvider.overrideWith(
          (ref) async => FirestoreStageDefinitionRepository(
            firestore: firestore,
            uid: _uid,
            profileId: _profileId,
          ),
        ),
      ],
    );
    await seedStageDefinitions(
      firestore,
      uid: _uid,
      profileId: _profileId,
      curriculumId: _curriculum,
      stages: [
        const StageDefinition(
          curriculumId: _curriculum,
          stageOrder: 1,
          stageName: 'Learn',
          delayDays: 0,
          isDefault: true,
          scheduleType: ScheduleType.delay,
        ),
      ],
    );
    service = container.read(_trackProgressServiceProvider);
    addTearDown(container.dispose);
  });

  const totalItems = 10;

  Future<double> legacyAllTierPercent() async {
    final completions = await completionRepository.getCompletionsForCurriculum(
      _curriculum,
    );
    final ledger = await ledgerRepository.getLedgerForCurriculum(_curriculum);
    return (completions.length + ledger.length) / totalItems;
  }

  group('dashboardTrackCompletionPercentage migration consistency', () {
    test('live-only profile: trackAchievement == old all-tiers result', () async {
      await _seedLive(firestore, ref: 'ref1');
      await _seedLive(firestore, ref: 'ref2');

      final legacyPct = await legacyAllTierPercent();
      final migratedPct = await service.completionPercent(
        curriculumId: _curriculum,
        tier: CompletionTierFilter.trackAchievement,
        totalItems: totalItems,
      );

      expect(
        migratedPct,
        closeTo(legacyPct, 1e-9),
        reason:
            'Live-only profile: trackAchievement must equal old all-tiers result',
      );
      expect(migratedPct, closeTo(0.2, 1e-9));
    });

    test(
      'bulk-only profile: trackAchievement credits bulkInTrack items',
      () async {
        await _seedBulkInTrack(firestore, ref: 'ref1');
        await _seedBulkInTrack(firestore, ref: 'ref2');
        await _seedBulkInTrack(firestore, ref: 'ref3');

        final migratedPct = await service.completionPercent(
          curriculumId: _curriculum,
          tier: CompletionTierFilter.trackAchievement,
          totalItems: totalItems,
        );

        expect(migratedPct, closeTo(0.3, 1e-9));
      },
    );

    test(
      'mixed profile: migrated value < old value when lifetimeOnly rows exist',
      () async {
        await _seedLive(firestore, ref: 'ref_live');
        await _seedBulkInTrack(firestore, ref: 'ref_bulk');
        await _seedLifetimeOnly(firestore, ref: 'ref_lt');

        final legacyPct = await legacyAllTierPercent();
        final migratedPct = await service.completionPercent(
          curriculumId: _curriculum,
          tier: CompletionTierFilter.trackAchievement,
          totalItems: totalItems,
        );

        expect(legacyPct, closeTo(0.3, 1e-9));
        expect(migratedPct, closeTo(0.2, 1e-9));
        expect(migratedPct, lessThan(legacyPct));
      },
    );
  });
}
