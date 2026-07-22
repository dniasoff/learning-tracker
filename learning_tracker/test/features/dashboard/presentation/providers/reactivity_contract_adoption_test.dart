/// R5 reactivity-contract adoption — dashboard percentage aggregates.
///
/// Drives [dashboardTrackCompletionPercentageProvider] and
/// [dashboardCompletionPercentageProvider] through the shared
/// `expectRebuildsOn` helper (`test/helpers/reactivity_contract.dart`).
/// Both watch `completionCommittedProvider` so the dashboard's completion
/// bars update live after a completion, without pull-to-refresh.
///
/// Fixture mirrors `dashboard_completion_percentage_test.dart`'s proven
/// `_makeContainer` override set (`scopedItemCountProvider` stubbed per
/// curriculum so no content DB is touched); this is a NEW, additional guard
/// alongside that file's detailed value-level assertions, not a
/// replacement for them.
@Tags(['dashboard', 'riverpod', 'contract'])
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/learning/presentation/providers/completion_writer_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/settings/presentation/providers/curriculum_scope_providers.dart';
import 'package:learning_tracker/features/sync/presentation/providers/sync_providers.dart';

import '../../../../helpers/drift_memory.dart';
import '../../../../helpers/reactivity_contract.dart';

const _profileId = 1;
const _curriculumKey = 'mishnayos';
const _curriculum = CurriculumId.mishnayos;

ProviderContainer _makeContainer(UserDatabase db) => ProviderContainer(
  overrides: [
    userDatabaseProvider.overrideWithValue(db),
    activeProfileIdProvider.overrideWithValue(_profileId),
    syncWriteFacadeProvider.overrideWithValue(null),
    // Stub every curriculum's scoped item count so the test never touches
    // the (heavy) bundled content database — only `_curriculum` has any
    // items, matching the single stage/track seeded below.
    for (final c in CurriculumId.values)
      scopedItemCountProvider(
        c,
      ).overrideWith((ref) => Future.value(c == _curriculum ? 1 : 0)),
  ],
);

Future<int> _seedTrackWithStage(UserDatabase db) async {
  final trackId = await seedTrack(
    db,
    profileId: _profileId,
    curriculumId: _curriculumKey,
  );
  await db
      .into(db.stageDefinitions)
      .insert(
        StageDefinitionsCompanion.insert(
          profileId: _profileId,
          trackId: trackId,
          curriculumId: _curriculumKey,
          stageOrder: 1,
          stageName: 'Learned',
          schedule: const Value('{"type":"delay","delay_days":0}'),
        ),
      );
  return trackId;
}

Future<void> _recordCompletionAndTick(
  ProviderContainer container,
  UserDatabase db,
  int trackId,
) async {
  await db
      .into(db.completionEvents)
      .insert(
        CompletionEventsCompanion.insert(
          profileId: _profileId,
          curriculumId: _curriculumKey,
          sefariaRef: 'Mishnah Berakhot 1:1',
          stageId: 1,
          trackType: 'personal',
          trackId: Value(trackId),
          eventTimestamp: DateTime.utc(2026, 1, 2),
        ),
      );
  container.read(completionCommittedProvider.notifier).increment();
}

void main() {
  group('dashboard percentage providers rebuild on '
      'completionCommittedProvider', () {
    test('dashboardTrackCompletionPercentageProvider', () async {
      final db = inMemoryDb();
      addTearDown(db.close);
      await seedProfile(db);
      final trackId = await _seedTrackWithStage(db);

      final container = _makeContainer(db);
      addTearDown(container.dispose);

      await expectRebuildsOn(
        container,
        dashboardTrackCompletionPercentageProvider(trackId),
        () => _recordCompletionAndTick(container, db, trackId),
        reason:
            'dashboardTrackCompletionPercentageProvider must watch '
            'completionCommittedProvider so the dashboard bar updates live',
      );
    });

    test('dashboardCompletionPercentageProvider', () async {
      final db = inMemoryDb();
      addTearDown(db.close);
      await seedProfile(db);
      final trackId = await _seedTrackWithStage(db);

      final container = _makeContainer(db);
      addTearDown(container.dispose);

      await expectRebuildsOn(
        container,
        dashboardCompletionPercentageProvider(_curriculum),
        () => _recordCompletionAndTick(container, db, trackId),
        reason:
            'dashboardCompletionPercentageProvider must watch '
            'completionCommittedProvider so the dashboard bar updates live',
      );
    });
  });
}
