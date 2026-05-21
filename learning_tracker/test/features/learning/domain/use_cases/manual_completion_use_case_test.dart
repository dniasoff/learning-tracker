import 'package:drift/drift.dart' show Value;
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/features/learning/data/repositories/learning_ledger_repository_impl.dart';
import 'package:learning_tracker/features/learning/domain/repositories/learning_ledger_repository.dart';
import 'package:learning_tracker/features/learning/domain/use_cases/manual_completion_use_case.dart';
import 'package:learning_tracker/features/sync/data/outbox_sync_write_facade.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../helpers/test_database.dart';

class _MockOutboxFacade extends Mock implements OutboxSyncWriteFacade {}

void main() {
  late UserDatabase db;
  late _MockOutboxFacade mockOutboxFacade;

  setUp(() async {
    db = createTestDatabase();
    await seedProfile(db);
    // Seed a second learner profile (id=5) used by child-profile tests.
    await db
        .into(db.learnerProfiles)
        .insert(
          LearnerProfilesCompanion(
            id: const Value(5),
            accountId: const Value(1),
            displayName: const Value('Child User'),
            mode: const Value('child'),
            createdAt: Value(DateTime.now().toUtc()),
            updatedAt: Value(DateTime.now().toUtc()),
          ),
        );
    mockOutboxFacade = _MockOutboxFacade();
    when(
      () => mockOutboxFacade.enqueueLedgerEntry(any()),
    ).thenAnswer((_) async {});
  });

  tearDown(() async {
    await db.close();
  });

  ManualCompletionUseCase createUseCase({
    int profileId = 1,
    ProfileMode profileMode = ProfileMode.adult,
    bool parentPinSessionMatchesActiveProfile = false,
  }) {
    final repo = LearningLedgerRepositoryImpl(
      database: db,
      outboxFacade: mockOutboxFacade,
      activeProfileId: profileId,
      activeProfileMode: profileMode,
      parentPinSessionMatchesActiveProfile:
          parentPinSessionMatchesActiveProfile,
    );
    return ManualCompletionUseCase(
      repository: repo,
      activeProfileId: profileId,
      activeProfileMode: profileMode,
      parentPinSessionMatchesActiveProfile:
          parentPinSessionMatchesActiveProfile,
    );
  }

  group('ManualCompletionUseCase', () {
    test('adult can self-mark manual completion', () async {
      final useCase = createUseCase(
        profileId: 1,
        profileMode: ProfileMode.adult,
      );
      final entry = await useCase(
        curriculumId: 'mishna',
        entryScope: 'masechta',
        unitIdentifier: 'Berakhot',
        unitDisplayNameHe: 'ברכות',
        unitDisplayNameEn: 'Berakhot',
        trackType: 'personal',
      );

      expect(entry.isManual, true);
      expect(entry.markedBy, 1);
      expect(entry.completionNumber, 1);
    });

    test('child can self-mark when parent PIN session is active', () async {
      final useCase = createUseCase(
        profileId: 5,
        profileMode: ProfileMode.child,
        parentPinSessionMatchesActiveProfile: true,
      );
      final entry = await useCase(
        curriculumId: 'mishna',
        entryScope: 'masechta',
        unitIdentifier: 'Berakhot',
        unitDisplayNameHe: 'ברכות',
        unitDisplayNameEn: 'Berakhot',
        trackType: 'personal',
      );

      expect(entry.isManual, true);
      expect(entry.markedBy, 5);
    });

    test('child is rejected from self-marking', () async {
      final useCase = createUseCase(
        profileId: 5,
        profileMode: ProfileMode.child,
      );

      expect(
        () => useCase(
          curriculumId: 'mishna',
          entryScope: 'masechta',
          unitIdentifier: 'Berakhot',
          unitDisplayNameHe: 'ברכות',
          unitDisplayNameEn: 'Berakhot',
          trackType: 'personal',
        ),
        throwsA(isA<ChildSelfMarkException>()),
      );
    });

    test('parent can mark for child (parent mode active)', () async {
      // Parent is logged in (profileId=1, mode=adult), marking for child
      final useCase = createUseCase(
        profileId: 1,
        profileMode: ProfileMode.adult,
      );
      final entry = await useCase(
        curriculumId: 'mishna',
        entryScope: 'masechta',
        unitIdentifier: 'Berakhot',
        unitDisplayNameHe: 'ברכות',
        unitDisplayNameEn: 'Berakhot',
        trackType: 'personal',
        targetProfileId: 5, // child's profile
      );

      expect(entry.markedBy, 1); // parent is the marker
      expect(entry.isManual, true);
    });
  });
}
