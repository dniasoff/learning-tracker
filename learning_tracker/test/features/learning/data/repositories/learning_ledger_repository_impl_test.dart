import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/learning/data/repositories/learning_ledger_repository_impl.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_source.dart';
import 'package:learning_tracker/features/learning/domain/entities/learning_ledger_entry.dart';
import 'package:learning_tracker/features/learning/domain/repositories/learning_ledger_repository.dart';
import 'package:test/test.dart';

import '../../../../helpers/firestore_fixtures.dart';
import '../../../../helpers/writer_reader_agreement.dart';

const _uid = 'ledger-test-user';
const _profileId = '01ARZ3NDEKTSV4RRFFQ69G5FAV';

void main() {
  late FakeFirebaseFirestore firestore;
  late ProviderContainer container;

  setUp(() {
    final rig = activateAccountAndProfile(
      uid: _uid,
      profileId: _profileId,
    );
    firestore = rig.firestore;
    container = rig.container;
  });

  tearDown(() => container.dispose());

  LearningLedgerRepository createRepo({
    ProfileMode profileMode = ProfileMode.adult,
    bool parentPinSessionMatches = false,
  }) {
    final provider = Provider<LearningLedgerRepository>(
      (ref) => FirestoreLearningLedgerRepositoryAdapter(
        ref: ref,
        activeProfileMode: profileMode,
        parentPinSessionMatchesActiveProfile: parentPinSessionMatches,
      ),
    );
    return container.read(provider);
  }

  LedgerEntryDraft draft({
    String unitIdentifier = 'Berakhot',
    CurriculumId curriculumId = CurriculumId.mishnayos,
    bool isManual = true,
    String? ulid,
  }) => LedgerEntryDraft(
    curriculumId: curriculumId,
    entryScope: 'masechta',
    unitIdentifier: unitIdentifier,
    unitDisplayNameHe: 'ברכות',
    unitDisplayNameEn: unitIdentifier,
    trackType: 'personal',
    markedBy: _profileId,
    isManual: isManual,
    ulid: ulid,
  );

  group('LearningLedgerRepository', () {
    group('recordCompletion', () {
      test('auto-calculates completionNumber starting at 1', () async {
        final entry = await createRepo().recordCompletion(
          curriculumId: CurriculumId.mishnayos,
          entryScope: 'masechta',
          unitIdentifier: 'Berakhot',
          unitDisplayNameHe: 'ברכות',
          unitDisplayNameEn: 'Berakhot',
          trackType: 'personal',
          markedBy: _profileId,
          isManual: false,
        );

        expect(entry.completionNumber, 1);
      });

      test('increments completionNumber on subsequent completions', () async {
        final repo = createRepo();
        await repo.recordCompletion(
          curriculumId: CurriculumId.mishnayos,
          entryScope: 'masechta',
          unitIdentifier: 'Berakhot',
          unitDisplayNameHe: 'ברכות',
          unitDisplayNameEn: 'Berakhot',
          trackType: 'personal',
          markedBy: _profileId,
          isManual: false,
        );
        final entry = await repo.recordCompletion(
          curriculumId: CurriculumId.mishnayos,
          entryScope: 'masechta',
          unitIdentifier: 'Berakhot',
          unitDisplayNameHe: 'ברכות',
          unitDisplayNameEn: 'Berakhot',
          trackType: 'personal',
          markedBy: _profileId,
          isManual: false,
        );

        expect(entry.completionNumber, 2);
      });

      test('persists the completion document in Firestore', () async {
        final repo = createRepo();
        final entry = await repo.recordCompletion(
          curriculumId: CurriculumId.mishnayos,
          entryScope: 'masechta',
          unitIdentifier: 'Berakhot',
          unitDisplayNameHe: 'ברכות',
          unitDisplayNameEn: 'Berakhot',
          trackType: 'personal',
          markedBy: _profileId,
          isManual: false,
        );

        final snapshot = await firestore
            .collection('users')
            .doc(_uid)
            .collection('learner_profiles')
            .doc(_profileId)
            .collection('learning_ledger')
            .doc(entry.ulid)
            .get();
        expect(snapshot.exists, isTrue);
        expect(snapshot.data()!['marked_by'], _profileId);
      });

      test('allows manual completion for child when parent PIN session active',
          () async {
        final entry = await createRepo(
          profileMode: ProfileMode.child,
          parentPinSessionMatches: true,
        ).recordCompletion(
          curriculumId: CurriculumId.mishnayos,
          entryScope: 'masechta',
          unitIdentifier: 'Berakhot',
          unitDisplayNameHe: 'ברכות',
          unitDisplayNameEn: 'Berakhot',
          trackType: 'personal',
          markedBy: _profileId,
          isManual: true,
        );

        expect(entry.isManual, isTrue);
        expect(entry.markedBy, _profileId);
      });

      test('rejects child self-mark for manual completions', () async {
        expect(
          () => createRepo(profileMode: ProfileMode.child).recordCompletion(
            curriculumId: CurriculumId.mishnayos,
            entryScope: 'masechta',
            unitIdentifier: 'Berakhot',
            unitDisplayNameHe: 'ברכות',
            unitDisplayNameEn: 'Berakhot',
            trackType: 'personal',
            markedBy: _profileId,
            isManual: true,
          ),
          throwsA(isA<ChildSelfMarkException>()),
        );
      });

      test('allows adult self-mark for manual completions', () async {
        final entry = await createRepo().recordCompletion(
          curriculumId: CurriculumId.mishnayos,
          entryScope: 'masechta',
          unitIdentifier: 'Berakhot',
          unitDisplayNameHe: 'ברכות',
          unitDisplayNameEn: 'Berakhot',
          trackType: 'personal',
          markedBy: _profileId,
          isManual: true,
        );

        expect(entry.isManual, isTrue);
        expect(entry.markedBy, _profileId);
      });

      test('uses CurriculumId as the sole track identity', () async {
        final entry = await createRepo().recordCompletion(
          curriculumId: CurriculumId.mishnayos,
          entryScope: 'masechta',
          unitIdentifier: 'Berakhot',
          unitDisplayNameHe: 'ברכות',
          unitDisplayNameEn: 'Berakhot',
          trackType: 'personal',
          markedBy: _profileId,
          isManual: false,
        );

        expect(entry.curriculumId, CurriculumId.mishnayos);
      });
    });

    group('recordCompletionsBatch', () {
      test('inserts multiple Firestore documents with per-unit numbering',
          () async {
        final entries = await createRepo().recordCompletionsBatch([
          draft(unitIdentifier: 'A'),
          draft(unitIdentifier: 'B'),
        ]);

        expect(entries, hasLength(2));
        expect(entries.map((e) => e.completionNumber), [1, 1]);
        final ledger = await createRepo().getLifetimeLedger();
        expect(ledger, hasLength(2));
      });

      test('writes the sentinel date for lifetime-only marks', () async {
        final entries = await createRepo().recordCompletionsBatch([
          draft(unitIdentifier: 'A'),
          draft(unitIdentifier: 'B'),
        ]);

        expect(entries, hasLength(2));
        expect(entries.every((e) => e.completedAt.year == 2000), isTrue);
      });

      test('writes the sentinel date for bulk-in-track marks', () async {
        final entries = await createRepo().recordCompletionsBatch(
          [draft(unitIdentifier: 'A'), draft(unitIdentifier: 'B')],
          source: CompletionSource.bulkInTrack,
        );

        expect(entries.every((e) => e.completedAt.year == 2000), isTrue);
      });

      test('writes a real timestamp for live marks', () async {
        final entries = await createRepo().recordCompletionsBatch(
          [draft(unitIdentifier: 'A'), draft(unitIdentifier: 'B')],
          source: CompletionSource.live,
        );

        expect(entries.every((e) => e.completedAt.year != 2000), isTrue);
      });
    });

    group('getLifetimeLedger', () {
      test('returns all entries for a profile', () async {
        await seedLedgerEntry(
          firestore,
          uid: _uid,
          profileId: _profileId,
          ulid: '01ARZ3NDEKTSV4RRFFQ69G5FAW',
          curriculumId: CurriculumId.mishnayos,
          unitIdentifier: 'Berakhot',
        );
        await seedLedgerEntry(
          firestore,
          uid: _uid,
          profileId: _profileId,
          ulid: '01ARZ3NDEKTSV4RRFFQ69G5FAX',
          curriculumId: CurriculumId.bavli,
          unitIdentifier: 'Shabbat',
        );

        final ledger = await createRepo().getLifetimeLedger();
        expect(ledger, hasLength(2));
      });
    });

    group('getCompletionStats', () {
      test('returns correct auto/manual breakdown', () async {
        await seedLedgerEntry(
          firestore,
          uid: _uid,
          profileId: _profileId,
          ulid: '01ARZ3NDEKTSV4RRFFQ69G5FAY',
          curriculumId: CurriculumId.mishnayos,
          unitIdentifier: 'Berakhot',
          isManual: false,
        );
        await seedLedgerEntry(
          firestore,
          uid: _uid,
          profileId: _profileId,
          ulid: '01ARZ3NDEKTSV4RRFFQ69G5FAZ',
          curriculumId: CurriculumId.mishnayos,
          unitIdentifier: 'Shabbat',
          isManual: true,
        );

        final stats = await createRepo().getCompletionStats(
          CurriculumId.mishnayos,
        );
        expect(stats['total'], 2);
        expect(stats['auto'], 1);
        expect(stats['manual'], 1);
      });
    });
  });
}
