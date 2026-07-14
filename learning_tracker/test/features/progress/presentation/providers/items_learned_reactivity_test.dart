/// ILP-01 regression guard — itemsLearnedDataProvider and lifetimeViewDataProvider
/// must re-execute when completionCommittedProvider ticks.
///
/// Before the fix both providers never watched completionCommittedProvider, so
/// the Items Learned and Lifetime View screens showed stale counts after a
/// completion until the user pulled to refresh.  After the fix a tick on
/// completionCommittedProvider invalidates both family providers and they
/// re-query the DB with the new row included.
///
/// AUD-t-progress-05: rewritten to drive the REAL providers over an
/// in-memory Drift DB and a fake content repository, instead of overriding
/// the providers under test with hand-written stubs that merely re-asserted
/// the fix's own `ref.watch(completionCommittedProvider)` line. A regression
/// that drops that watch call now shows up as a stale `learnedLeafCount` on
/// the REAL provider, not a call-count on a stand-in.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/learning/presentation/providers/completion_writer_providers.dart';
import 'package:learning_tracker/features/progress/presentation/providers/items_learned_providers.dart';

import '../../../../helpers/drift_memory.dart';

const _profileId = 1;

// ---------------------------------------------------------------------------
// Test doubles
// ---------------------------------------------------------------------------

class _FakeContentRepository extends Fake implements ContentRepository {
  _FakeContentRepository(this._byCurriculum);

  final Map<CurriculumId, List<ContentItem>> _byCurriculum;

  @override
  Future<List<ContentItem>> getContentForCurriculum(
    CurriculumId curriculumId,
  ) async => _byCurriculum[curriculumId] ?? const [];
}

ContentItem _leaf(
  String curriculumKey,
  String ref, {
  String level1 = 'Zeraim',
  String level2 = 'Berakhot',
  int sortOrder = 0,
}) => ContentItem(
  curriculumId: curriculumKey,
  sefariaRef: ref,
  displayNameEn: ref,
  displayNameHe: ref,
  level1: level1,
  level2: level2,
  level3: null,
  level4: null,
  isLeaf: true,
  sortOrder: sortOrder,
);

Future<void> _insertLiveCompletion(
  UserDatabase db, {
  required String curriculumId,
  required String sefariaRef,
  required int stageId,
  DateTime? at,
}) => db.completionEventDao.appendEvent(
  CompletionEventsCompanion.insert(
    profileId: _profileId,
    curriculumId: curriculumId,
    sefariaRef: sefariaRef,
    stageId: stageId,
    trackType: 'personal',
    eventTimestamp: at ?? DateTime.utc(2026, 5, 1, 10),
  ),
);

void main() {
  group(
    'ILP-01: itemsLearnedDataProvider reacts to completionCommittedProvider',
    () {
      test('provider re-executes after a completionCommittedProvider tick and '
          'reflects the new completion', () async {
        final db = inMemoryDb();
        addTearDown(db.close);
        await seedProfile(db);

        final leaf = _leaf('mishnayos', 'Mishnah Berakhot 1:1');
        final repo = _FakeContentRepository({
          CurriculumId.mishnayos: [leaf],
        });

        final container = ProviderContainer(
          overrides: [
            userDatabaseProvider.overrideWith((ref) => db),
            contentRepositoryProvider.overrideWithValue(repo),
          ],
        );
        addTearDown(container.dispose);

        final target = itemsLearnedDataProvider((
          profileId: _profileId,
          curriculumId: CurriculumId.mishnayos,
        ));
        // Keep the provider alive across the DB mutation + tick — mirrors
        // the mounted Items Learned screen. Without an active listener the
        // autoDispose family would tear down between the two reads, which
        // would mask a missing completionCommittedProvider watch.
        final sub = container.listen(target, (_, __) {});
        addTearDown(sub.close);

        final before = await container.read(target.future);
        expect(before, isNull, reason: 'no track completions seeded yet');

        await _insertLiveCompletion(
          db,
          curriculumId: 'mishnayos',
          sefariaRef: leaf.sefariaRef,
          stageId: 1,
        );
        container.read(completionCommittedProvider.notifier).increment();

        final after = await container.read(target.future);
        expect(
          after?.learnedLeafCount,
          1,
          reason:
              'ILP-01: after completionCommittedProvider tick, '
              'itemsLearnedDataProvider must re-execute and reflect the '
              'new completion',
        );
      });
    },
  );

  group(
    'ILP-01: lifetimeViewDataProvider reacts to completionCommittedProvider',
    () {
      test('provider re-executes after a completionCommittedProvider tick and '
          'reflects the new completion', () async {
        final db = inMemoryDb();
        addTearDown(db.close);
        await seedProfile(db);

        final leaf = _leaf('chumash', 'Genesis 1:1');
        final repo = _FakeContentRepository({
          CurriculumId.chumash: [leaf],
        });

        final container = ProviderContainer(
          overrides: [
            userDatabaseProvider.overrideWith((ref) => db),
            contentRepositoryProvider.overrideWithValue(repo),
          ],
        );
        addTearDown(container.dispose);

        final target = lifetimeViewDataProvider((
          profileId: _profileId,
          curriculumId: CurriculumId.chumash,
        ));
        final sub = container.listen(target, (_, __) {});
        addTearDown(sub.close);

        final before = await container.read(target.future);
        expect(before, isNull, reason: 'no completions seeded yet');

        await _insertLiveCompletion(
          db,
          curriculumId: 'chumash',
          sefariaRef: leaf.sefariaRef,
          stageId: 1,
        );
        container.read(completionCommittedProvider.notifier).increment();

        final after = await container.read(target.future);
        expect(
          after?.learnedLeafCount,
          1,
          reason:
              'ILP-01: after completionCommittedProvider tick, '
              'lifetimeViewDataProvider must re-execute and reflect the '
              'new completion',
        );
      });
    },
  );

  group(
    'ILP-01: itemsLearnedSummariesProvider reacts to completionCommittedProvider',
    () {
      test('aggregate provider re-executes after a completionCommittedProvider '
          'tick and reflects the new completion', () async {
        final db = inMemoryDb();
        addTearDown(db.close);
        await seedProfile(db);

        final leaf = _leaf('mishnayos', 'Mishnah Berakhot 1:1');
        final repo = _FakeContentRepository({
          CurriculumId.mishnayos: [leaf],
        });

        final container = ProviderContainer(
          overrides: [
            userDatabaseProvider.overrideWith((ref) => db),
            contentRepositoryProvider.overrideWithValue(repo),
          ],
        );
        addTearDown(container.dispose);

        final target = itemsLearnedSummariesProvider(_profileId);
        final sub = container.listen(target, (_, __) {});
        addTearDown(sub.close);

        final before = await container.read(target.future);
        expect(before, isEmpty, reason: 'no track completions seeded yet');

        await _insertLiveCompletion(
          db,
          curriculumId: 'mishnayos',
          sefariaRef: leaf.sefariaRef,
          stageId: 1,
        );
        container.read(completionCommittedProvider.notifier).increment();

        final after = await container.read(target.future);
        expect(
          after,
          hasLength(1),
          reason:
              'ILP-01: itemsLearnedSummariesProvider must re-execute on a '
              'completionCommittedProvider tick and pick up the new '
              'completion',
        );
      });
    },
  );
}
