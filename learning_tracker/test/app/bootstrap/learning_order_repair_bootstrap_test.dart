/// Regression test for AUD-tracks-06's REGRESSION bounce finding:
///
/// [LearningOrderRepositoryImpl.repairStaleOrderVersion] (the one-shot §10.1
/// re-amnesty repair extracted out of the impure `getOrder`, see
/// `learning_order_repository.dart`) had ZERO production callers — nothing
/// ever invoked it, so a stale `learningOrderVersion` guard left after a
/// content reseed was never repaired and pre-reseed overdue items were never
/// re-amnestied (`lastReorderAt` never got stamped by any reachable code
/// path).
///
/// [repairStaleLearningOrders] is the fix: a bootstrap-time sweep, wired
/// into `bootstrap.dart`, that runs the repair for every [CurriculumId] once
/// per app start. These tests exercise the sweep itself — the reachable
/// path — not the repository method directly, so a green suite here can no
/// longer mask "nothing calls this."
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/app/bootstrap/learning_order_repair_bootstrap.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/tracks/whole_curriculum_order/data/repositories/learning_order_repository_impl.dart';
import 'package:learning_tracker/features/tracks/whole_curriculum_order/domain/models/learning_order_item.dart';
import 'package:learning_tracker/features/tracks/whole_curriculum_order/domain/repositories/learning_order_repository.dart';
import 'package:learning_tracker/features/tracks/whole_curriculum_order/presentation/providers/learning_order_providers.dart';
import 'package:talker/talker.dart';

import '../../helpers/drift_memory.dart';

class _ProfileId1 extends ActiveProfileId {
  @override
  int build() => 1;
}

AppLogger _testLogger() => AppLogger(Talker());

/// Records every curriculum passed to [repairStaleOrderVersion] without
/// touching a real database — proves the sweep visits every curriculum.
class _RecordingRepository implements LearningOrderRepository {
  final List<CurriculumId> repaired = [];

  @override
  Future<void> repairStaleOrderVersion(CurriculumId curriculumId) async {
    repaired.add(curriculumId);
  }

  @override
  Future<List<LearningOrderItem>> getOrder(
    CurriculumId curriculumId,
    List<ContentItem> allItems,
  ) async => const [];

  @override
  Future<void> saveOrder(
    CurriculumId curriculumId,
    List<LearningOrderItem> items, {
    bool isChildRestricted = false,
  }) async {}

  @override
  Future<void> resetToDefault(CurriculumId curriculumId) async {}
}

void main() {
  test('repairStaleLearningOrders sweeps every CurriculumId through the '
      'repository once per call (bootstrap-reachable path)', () async {
    final repo = _RecordingRepository();
    final container = ProviderContainer.test(
      overrides: [
        learningOrderRepositoryProvider.overrideWithValue(repo),
        contentVersionProvider.overrideWith((ref) async => 2),
      ],
    );

    await repairStaleLearningOrders(container: container, log: _testLogger());

    expect(
      repo.repaired,
      equals(CurriculumId.all),
      reason:
          'AUD-tracks-06 REGRESSION: the sweep is the only reachable '
          'caller of repairStaleOrderVersion — it must visit every '
          'curriculum, not a subset.',
    );
  });

  test('repairStaleLearningOrders end-to-end: a stale learningOrderVersion row '
      'gets its track lastReorderAt stamped via the REAL repository, reached '
      'only through the sweep (not by calling repairStaleOrderVersion '
      'directly)', () async {
    final db = inMemoryDb();
    addTearDown(db.close);
    await seedProfile(db);

    // Arrange: an active track with no prior lastReorderAt.
    final activatedAt = DateTime.utc(2026, 1, 1);
    final trackId = await db
        .into(db.curriculumTracks)
        .insert(
          CurriculumTracksCompanion.insert(
            profileId: 1,
            curriculumId: CurriculumId.mishnayos.storageKey,
            stateChangedAt: activatedAt,
            activatedAt: activatedAt,
          ),
        );

    // A learning_order row saved against seed version 1.
    await db.learningOrderDao.upsertLearningOrder(
      LearningOrderCompanion.insert(
        profileId: 1,
        curriculumId: CurriculumId.mishnayos.storageKey,
        sefariaRef: 'Berakhot',
        userSortOrder: 0,
        learningOrderVersion: const Value(1),
      ),
    );

    // The real repository — currentContentVersion: 2 simulates a reseed
    // that bumped the content version past the saved order's version.
    final repo = LearningOrderRepositoryImpl(
      database: db,
      profileId: 1,
      currentContentVersion: 2,
    );

    final container = ProviderContainer.test(
      overrides: [
        userDatabaseProvider.overrideWithValue(db),
        activeProfileIdProvider.overrideWith(_ProfileId1.new),
        learningOrderRepositoryProvider.overrideWithValue(repo),
        contentVersionProvider.overrideWith((ref) async => 2),
      ],
    );

    // Pre-condition: nothing has repaired the stale row yet.
    final before = await db.trackDao.getTrackById(trackId);
    expect(before!.lastReorderAt, isNull);

    // Act: this is the ONLY call in this test — no direct call to
    // repairStaleOrderVersion. If the bootstrap sweep is the sole
    // reachable path (as production now requires), this must repair it.
    await repairStaleLearningOrders(container: container, log: _testLogger());

    // Assert: the reachable sweep actually performed the §10.1 re-amnesty.
    final after = await db.trackDao.getTrackById(trackId);
    expect(
      after!.lastReorderAt,
      isNotNull,
      reason:
          'AUD-tracks-06 REGRESSION: after a reseed, lastReorderAt must '
          'be stamped by a reachable code path (the bootstrap sweep) — '
          'not merely by calling repairStaleOrderVersion directly in a '
          'unit test.',
    );
  });
}
