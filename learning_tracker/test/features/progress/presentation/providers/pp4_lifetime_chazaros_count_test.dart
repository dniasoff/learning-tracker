/// Regression test for PP-4 — lifetimeHeaderCountersProvider counts ALL
/// completions as "chazaros" instead of only review events.
///
/// ROOT CAUSE: `lifetimeHeaderCountersProvider` sets
///   `totalChazaros: completions.length`
/// which counts EVERY completion event (limud stageId==1 + chazaros stageId>1).
/// A user who has learned but never reviewed sees a non-zero "total chazaros"
/// that is actually their learn count, while every leaf shows "Live" with zero
/// chazaros — the screen self-contradicts.
///
/// FIX: Count only chazara (stageId > 1) completions:
///   `totalChazaros: completions.where((c) => c.stageId > 1).length`
///
/// RED test: seeds 5 limud + 2 chazara events and asserts the REAL
/// `lifetimeHeaderCountersProvider` reports 2 (not 7 — the pre-fix
/// `completions.length` value), so a regression that reverts the fix line
/// makes this assertion fail red.
/// GREEN test: a user with only limud completions must see 0 chazaros.
///
/// AUD-t-progress-05: rewritten to read the REAL provider via a
/// [ProviderContainer] over a seeded in-memory DB, instead of recomputing
/// the buggy/fixed formula inline in the test (which never touched
/// `lifetimeHeaderCountersProvider` and so could never catch a regression to
/// its source).
@Tags(['unit', 'progress', 'lifetime', 'pp4'])
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/progress/presentation/providers/lifetime_knowledge_providers.dart';

import '../../../../helpers/drift_memory.dart'
    show inMemoryDb, seedCompletion, seedProfile;

// ---------------------------------------------------------------------------
// Test doubles
// ---------------------------------------------------------------------------

/// `lifetimeHeaderCountersProvider`'s `totalChazaros` branch reads completion
/// events directly and does not depend on curriculum content at all; its
/// `itemsLearned` branch does, via `lifetimeSummariesProvider`, but that
/// number is irrelevant to this PP-4 guard. Returning no content for every
/// curriculum keeps the fixture minimal — `_safeLoadLeaves` treats an empty
/// list as "skip this curriculum" (no exception), so `totalChazaros` is
/// still computed correctly.
class _EmptyContentRepository extends Fake implements ContentRepository {
  @override
  Future<List<ContentItem>> getContentForCurriculum(
    CurriculumId curriculumId,
  ) async => const [];
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Future<void> _insertCompletion(
  UserDatabase db, {
  String sefariaRef = 'Berakhot.1.1',
  required int stageId,
}) => seedCompletion(
  db,
  CompletionEventsCompanion.insert(
    profileId: 1,
    curriculumId: 'mishnayos',
    sefariaRef: sefariaRef,
    stageId: stageId,
    trackType: 'mishna',
    eventTimestamp: DateTime(2024, 6, 15),
  ),
);

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('PP-4 — totalChazaros must exclude limud (stageId == 1) completions', () {
    test('PP-4 RED: lifetimeHeaderCountersProvider reports 2 chazaros for 5 '
        'limud + 2 review events, not 7 (completions.length — the reverted-bug '
        'value)', () async {
      final db = inMemoryDb();
      addTearDown(db.close);
      await seedProfile(db);

      // Seed: 5 limud completions + 2 review completions.
      for (var i = 0; i < 5; i++) {
        await _insertCompletion(db, sefariaRef: 'Berakhot.1.$i', stageId: 1);
      }
      await _insertCompletion(db, sefariaRef: 'Berakhot.1.0', stageId: 2);
      await _insertCompletion(db, sefariaRef: 'Berakhot.1.1', stageId: 2);

      final completions = await db.completionDao.getCompletionsByProfile(1);
      expect(
        completions,
        hasLength(7),
        reason: 'sanity: 7 raw completion-event rows seeded',
      );

      final container = ProviderContainer(
        overrides: [
          userDatabaseProvider.overrideWith((ref) => db),
          contentRepositoryProvider.overrideWithValue(
            _EmptyContentRepository(),
          ),
        ],
      );
      addTearDown(container.dispose);

      final counters = await container.read(
        lifetimeHeaderCountersProvider(1).future,
      );

      expect(
        counters.totalChazaros,
        2,
        reason:
            'PP-4: lifetimeHeaderCountersProvider.totalChazaros must count '
            'only stageId > 1 review events (2), not every completion row '
            '(7). A regression to `completions.length` would make this '
            'assertion observe 7 and fail red — a user with no reviews '
            'would see "7 chazaros" instead of 0.',
      );
    });

    test(
      'PP-4 GREEN: user with 3 learned items and 0 reviews has totalChazaros '
      '== 0 on the REAL provider',
      () async {
        final db = inMemoryDb();
        addTearDown(db.close);
        await seedProfile(db);

        for (var i = 0; i < 3; i++) {
          await _insertCompletion(db, sefariaRef: 'Berakhot.1.$i', stageId: 1);
        }

        final container = ProviderContainer(
          overrides: [
            userDatabaseProvider.overrideWith((ref) => db),
            contentRepositoryProvider.overrideWithValue(
              _EmptyContentRepository(),
            ),
          ],
        );
        addTearDown(container.dispose);

        final counters = await container.read(
          lifetimeHeaderCountersProvider(1).future,
        );

        expect(
          counters.totalChazaros,
          0,
          reason:
              'User with only limud completions (stageId==1) must show 0 '
              'total chazaros, not 3.',
        );
      },
    );
  });
}
