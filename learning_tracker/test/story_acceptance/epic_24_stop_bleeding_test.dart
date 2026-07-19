/// Story acceptance tests for Epic 24 -- Stop-the-Bleeding (Phase 0).
///
/// Story 24.7: Sync curriculum track activation to Firestore (DNI-310).
/// Story 24.8: Sync learning order to Firestore (DNI-311).
///
/// Pull-on-launch and LWW conflict-resolution tests that exercised the
/// legacy SyncEngine were retired (W2.35). Push-on-write tests remain,
/// using MockSyncWriteFacade (the interface that repositories receive).
@Tags(['epic_24'])
library;

import 'package:drift/native.dart';
import 'package:learning_tracker/core/database/daos/track_dao.dart'
    show TrackState;
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/sync/sync_write_facade.dart';
import 'package:learning_tracker/features/learning/data/repositories/track_repository_impl.dart';
import 'package:learning_tracker/features/tracks/whole_curriculum_order/data/repositories/learning_order_repository_impl.dart';
import 'package:learning_tracker/features/tracks/whole_curriculum_order/domain/models/learning_order_item.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../helpers/test_database.dart' show seedProfile;

class MockSyncWriteFacade extends Mock implements SyncWriteFacade {}

UserDatabase _createDb() => UserDatabase(NativeDatabase.memory());

void main() {
  group(
    'Story 24.7 -- Sync curriculum track activation to Firestore',
    tags: ['story_24_7'],
    () {
      group('push-on-write', () {
        late UserDatabase db;
        late MockSyncWriteFacade mockFacade;
        late TrackRepositoryImpl repo;

        setUp(() async {
          db = _createDb();
          mockFacade = MockSyncWriteFacade();
          when(
            () => mockFacade.pushCurriculumTrack(any()),
          ).thenAnswer((_) async {});
          repo = TrackRepositoryImpl(
            database: db,
            syncEngine: mockFacade,
            activeProfileId: 0,
          );
        });

        tearDown(() => db.close());

        test('initializeDefaultTracks pushes the track', () async {
          await repo.initializeDefaultTracks(CurriculumId.mishnayos);
          verify(() => mockFacade.pushCurriculumTrack(any())).called(1);
        });

        test('push payload contains required fields', () async {
          Map<String, dynamic>? capturedPayload;
          when(() => mockFacade.pushCurriculumTrack(any())).thenAnswer((inv) {
            capturedPayload =
                inv.positionalArguments[0] as Map<String, dynamic>;
            return Future<void>.value();
          });

          await repo.initializeDefaultTracks(CurriculumId.mishnayos);

          expect(capturedPayload, isNotNull);
          expect(capturedPayload!['curriculum_id'], isNotNull);
          // W3.22/W3.28: track_type/is_active replaced by state + state_changed_at
          expect(capturedPayload!['state'], isNotNull);
          expect(capturedPayload!['activated_at'], isNotNull);
        });

        test('no push when syncEngine is null (local-born user)', () async {
          final localRepo = TrackRepositoryImpl(database: db);
          await localRepo.initializeDefaultTracks(CurriculumId.bavli);

          // AUD-t-story-acceptance-18: localRepo never holds a reference to
          // mockFacade (it wasn't passed a syncEngine), so verifying against
          // mockFacade -- as this test previously did -- is a vacuous check
          // that passes no matter what localRepo does internally. Assert
          // against localRepo's actual collaborator instead: the local
          // write must have completed correctly on its own, with no facade
          // involved.
          final tracks = await db.trackDao.getAllTracks(CurriculumId.bavli);
          expect(tracks, hasLength(1));
          expect(tracks.single.profileId, 0);
          expect(tracks.single.state, TrackState.active.storageKey);

          // No push artifact of any kind may exist for a local-born write
          // (the production push path always enqueues through the shared
          // `outbox` table -- see OutboxSyncWriteFacade -- so an ambient/
          // stray facade reference that pushed anyway would show up here
          // even though it can't reach the disconnected mockFacade above).
          final outboxRows = await db.select(db.outbox).get();
          expect(outboxRows, isEmpty);
        });
      });
    },
  );

  group(
    'Story 24.8 (DNI-311) -- Sync learning order to Firestore',
    tags: ['story_24_8'],
    () {
      group('push-on-write', () {
        late UserDatabase db;
        late MockSyncWriteFacade mockFacade;
        late LearningOrderRepositoryImpl repo;

        setUp(() async {
          db = _createDb();
          await seedProfile(db);
          mockFacade = MockSyncWriteFacade();
          when(
            () => mockFacade.pushLearningOrder(
              profileId: any(named: 'profileId'),
              curriculumId: any(named: 'curriculumId'),
              items: any(named: 'items'),
              updatedAt: any(named: 'updatedAt'),
            ),
          ).thenAnswer((_) async {});
          repo = LearningOrderRepositoryImpl(
            database: db,
            syncEngine: mockFacade,
            profileId: 1,
          );
        });

        tearDown(() => db.close());

        test('saveOrder calls pushLearningOrder on sync facade', () async {
          final items = [
            const LearningOrderItem(
              sefariaRef: 'Mishnah Berakhot 1',
              displayNameHe: 'ברכות א',
              displayNameEn: 'Berakhot 1',
              userSortOrder: 0,
              isCustomOrdered: true,
            ),
          ];

          await repo.saveOrder(CurriculumId.mishnayos, items);

          verify(
            () => mockFacade.pushLearningOrder(
              profileId: 1,
              curriculumId: CurriculumId.mishnayos.storageKey,
              items: any(named: 'items'),
              updatedAt: any(named: 'updatedAt'),
            ),
          ).called(1);
        });

        test('no push when syncEngine is null (local-born user)', () async {
          final localRepo = LearningOrderRepositoryImpl(
            database: db,
            profileId: 1,
          );
          final items = [
            const LearningOrderItem(
              sefariaRef: 'Mishnah Berakhot 1',
              displayNameHe: 'ברכות א',
              displayNameEn: 'Berakhot 1',
              userSortOrder: 0,
              isCustomOrdered: true,
            ),
          ];

          await localRepo.saveOrder(CurriculumId.mishnayos, items);

          // AUD-t-story-acceptance-18: localRepo never holds a reference to
          // mockFacade (it wasn't passed a syncEngine), so verifying against
          // mockFacade -- as this test previously did -- is a vacuous check
          // that passes no matter what localRepo does internally. Assert
          // against localRepo's actual collaborator instead: the local
          // write must have completed correctly on its own.
          final rows = await db.learningOrderDao.getLearningOrderByCurriculum(
            CurriculumId.mishnayos.storageKey,
            profileId: 1,
          );
          expect(rows, hasLength(1));
          expect(rows.single.sefariaRef, 'Mishnah Berakhot 1');

          // No push artifact of any kind may exist for a local-born write
          // (the production push path always enqueues through the shared
          // `outbox` table -- see OutboxSyncWriteFacade -- so an ambient/
          // stray facade reference that pushed anyway would show up here
          // even though it can't reach the disconnected mockFacade above).
          final outboxRows = await db.select(db.outbox).get();
          expect(outboxRows, isEmpty);
        });

        test(
          'resetToDefault calls pushLearningOrder with empty items',
          () async {
            await repo.resetToDefault(CurriculumId.mishnayos);

            final captured = verify(
              () => mockFacade.pushLearningOrder(
                profileId: 1,
                curriculumId: CurriculumId.mishnayos.storageKey,
                items: captureAny(named: 'items'),
                updatedAt: any(named: 'updatedAt'),
              ),
            ).captured;
            expect(captured.first as List, isEmpty);
          },
        );
      });
    },
  );
}
