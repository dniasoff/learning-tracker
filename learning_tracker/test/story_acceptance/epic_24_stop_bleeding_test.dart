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

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/track_type.dart';
import 'package:learning_tracker/core/sync/sync_write_facade.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/learning/data/repositories/track_repository_impl.dart';
import 'package:learning_tracker/features/learning/domain/repositories/track_repository.dart';
import 'package:learning_tracker/features/learning_order/data/repositories/learning_order_repository_impl.dart';
import 'package:learning_tracker/features/learning_order/domain/models/learning_order_item.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class MockSyncWriteFacade extends Mock implements SyncWriteFacade {}

class MockContentRepository extends Mock implements ContentRepository {}

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

        test('activateTrack pushes curriculum track to sync facade', () async {
          await db
              .into(db.curriculumTracks)
              .insert(
                CurriculumTracksCompanion.insert(
                  profileId: 1,
                  curriculumId: CurriculumId.mishnayos.storageKey,
                  trackType: TrackType.personal.storageKey,
                  activatedAt: DateTime.utc(2026, 1, 1),
                  isActive: const Value(false),
                ),
              );

          await repo.activateTrack(CurriculumId.mishnayos, TrackType.personal);

          verify(() => mockFacade.pushCurriculumTrack(any())).called(1);
        });

        test(
          'deactivateTrack is a no-op for personal track (guard preserved)',
          () async {
            await repo.initializeDefaultTracks(CurriculumId.mishnayos);
            clearInteractions(mockFacade);

            await expectLater(
              () => repo.deactivateTrack(
                CurriculumId.mishnayos,
                TrackType.personal,
              ),
              throwsA(isA<InvalidTrackOperationException>()),
            );
            verifyNever(() => mockFacade.pushCurriculumTrack(any()));
          },
        );

        test('initializeDefaultTracks pushes personal track', () async {
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
          expect(capturedPayload!['track_type'], isNotNull);
          expect(capturedPayload!['is_active'], isNotNull);
          expect(capturedPayload!['activated_at'], isNotNull);
        });

        test('no push when syncEngine is null (local-born user)', () async {
          final localRepo = TrackRepositoryImpl(database: db);
          await localRepo.initializeDefaultTracks(CurriculumId.bavli);
          verifyNever(() => mockFacade.pushCurriculumTrack(any()));
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

        setUp(() {
          db = _createDb();
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
            contentRepository: MockContentRepository(),
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
            contentRepository: MockContentRepository(),
          );
          await localRepo.saveOrder(CurriculumId.mishnayos, []);
          verifyNever(
            () => mockFacade.pushLearningOrder(
              profileId: any(named: 'profileId'),
              curriculumId: any(named: 'curriculumId'),
              items: any(named: 'items'),
              updatedAt: any(named: 'updatedAt'),
            ),
          );
        });

        test('resetToDefault calls pushLearningOrder with empty items', () async {
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
        });
      });
    },
  );
}
