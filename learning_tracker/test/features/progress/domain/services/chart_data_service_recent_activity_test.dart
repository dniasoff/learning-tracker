/// Regression tests for the Firestore-backed Recent Activity chart service.
@Tags(['progress', 'recent_activity'])
library;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/time/ulid.dart';
import 'package:learning_tracker/data/firestore/account_firebase.dart';
import 'package:learning_tracker/data/firestore/active_account_providers.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart'
    show activeProfileDocIdProvider;
import 'package:learning_tracker/features/learning/domain/entities/completion_source.dart';
import 'package:learning_tracker/features/progress/data/repositories/firestore_chart_data_repository_adapter.dart';
import 'package:learning_tracker/features/progress/domain/services/chart_data_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/firestore_fake.dart';
import '../../../../helpers/firestore_fixtures.dart';

class _MockFirebaseApp extends Mock implements FirebaseApp {}

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

const _uid = 'recent-activity-test-user';
const _profileId = '01ARZ3NDEKTSV4RRFFQ69G5FAV';
const _curriculumId = CurriculumId.mishnayos;
final _startDate = DateTime(2026, 5, 1);
final _endDate = DateTime(2026, 5, 31);
// Chart buckets are local calendar dates. The service normalizes completion
// timestamps through _extractLocalDate before emitting them.
final _liveDay = DateTime(2026, 5, 10);

void main() {
  late FakeFirebaseFirestore firestore;
  late ProviderContainer container;
  late ChartDataService service;

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
    service = ChartDataService(repository: container.read(adapterProvider));
  });

  tearDown(() => container.dispose());

  Future<String> seedMark(
    String ref, {
    required int stageId,
    required CompletionSource source,
    DateTime? at,
    CurriculumId curriculum = _curriculumId,
  }) async {
    if (source == CompletionSource.lifetimeOnly) {
      final ulid = newUlid();
      await seedLedgerEntry(
        firestore,
        uid: _uid,
        profileId: _profileId,
        ulid: ulid,
        curriculumId: curriculum,
        entryScope: 'leaf',
        unitIdentifier: ref,
        unitDisplayNameEn: ref,
        source: CompletionSource.lifetimeOnly,
        completedAt: at ?? DateTime(2026, 5, 10, 10),
      );
      return ulid;
    }
    return seedCompletion(
      firestore,
      uid: _uid,
      profileId: _profileId,
      curriculumId: curriculum,
      sefariaRef: ref,
      stageId: stageId,
      source: source,
      completedAt: at ?? DateTime(2026, 5, 10, 10),
    );
  }

  group('getDailyLimudimAndChazaros', () {
    test('zero-fills empty window with zero limud + zero chazara', () async {
      final result = await service.getDailyLimudimAndChazaros(
        startDate: DateTime(2026, 3, 1),
        endDate: DateTime(2026, 3, 3),
      );
      expect(result, hasLength(3));
      expect(
        result.every((d) => d.limudCount == 0 && d.chazaraCount == 0),
        isTrue,
      );
    });

    test(
      'mixed stages on one day produce a stacked bar with both segments',
      () async {
        for (final ref in ['limud_a', 'limud_b']) {
          await seedMark(ref, stageId: 1, source: CompletionSource.live);
        }
        for (final ref in ['chaz_a', 'chaz_b', 'chaz_c']) {
          await seedMark(ref, stageId: 2, source: CompletionSource.live);
        }

        final result = await service.getDailyLimudimAndChazaros(
          startDate: _startDate,
          endDate: _endDate,
        );
        final day10 = result.firstWhere((d) => d.date == _liveDay);
        expect(day10.limudCount, 2);
        expect(day10.chazaraCount, 3);
        expect(day10.total, 5);
        expect(
          result
              .where((d) => d.date != _liveDay)
              .every((d) => d.limudCount == 0 && d.chazaraCount == 0),
          isTrue,
        );
      },
    );

    test(
      'bulkInTrack rows are included in the track-learning stacked feed',
      () async {
        await seedMark('live', stageId: 1, source: CompletionSource.live);
        await seedMark(
          'bulk',
          stageId: 1,
          source: CompletionSource.bulkInTrack,
        );

        final result = await service.getDailyLimudimAndChazaros(
          startDate: _startDate,
          endDate: _endDate,
        );
        final day10 = result.firstWhere((d) => d.date == _liveDay);
        expect(day10.limudCount, 2);
        expect(day10.chazaraCount, 0);
      },
    );

    test(
      'lifetimeOnly rows are excluded from the track-learning feed',
      () async {
        await seedMark('live', stageId: 2, source: CompletionSource.live);
        final lifetimeUlid = await seedMark(
          'lifetime',
          stageId: 2,
          source: CompletionSource.lifetimeOnly,
        );
        final ledger = await firestore
            .collection('users')
            .doc(_uid)
            .collection('learner_profiles')
            .doc(_profileId)
            .collection('learning_ledger')
            .doc(lifetimeUlid)
            .get();
        expect(ledger.exists, isTrue);

        final result = await service.getDailyLimudimAndChazaros(
          startDate: _startDate,
          endDate: _endDate,
        );
        final day10 = result.firstWhere((d) => d.date == _liveDay);
        expect(day10.limudCount, 0);
        expect(day10.chazaraCount, 1);
      },
    );

    test('curriculum filter applies', () async {
      await seedMark(
        'bavli_ref',
        stageId: 1,
        source: CompletionSource.live,
        curriculum: CurriculumId.bavli,
      );
      await seedMark('mish_ref', stageId: 1, source: CompletionSource.live);

      final result = await service.getDailyLimudimAndChazaros(
        startDate: _startDate,
        endDate: _endDate,
        curriculumId: _curriculumId.storageKey,
      );
      final day10 = result.firstWhere((d) => d.date == _liveDay);
      expect(day10.limudCount, 1);
      expect(day10.chazaraCount, 0);
    });
  });

  group('getCumulativeProgressLive', () {
    test('live + bulkInTrack contribute to the running total', () async {
      await seedMark('live_1', stageId: 1, source: CompletionSource.live);
      await seedMark(
        'bulk_1',
        stageId: 1,
        source: CompletionSource.bulkInTrack,
      );
      final result = await service.getCumulativeProgressLive(
        startDate: _startDate,
        endDate: _endDate,
      );
      expect(result.map((p) => p.total).reduce((a, b) => a > b ? a : b), 2);
    });
  });

  group('getStreakCalendarLive', () {
    test('only live marks light up the streak calendar', () async {
      await seedMark(
        'bulk',
        stageId: 1,
        source: CompletionSource.bulkInTrack,
        at: DateTime(2026, 5, 5, 9),
      );
      await seedMark(
        'live_may10',
        stageId: 1,
        source: CompletionSource.live,
        at: DateTime(2026, 5, 10, 9),
      );

      final dates = await service.getStreakCalendarLive(
        startDate: _startDate,
        endDate: _endDate,
      );
      expect(dates.contains(DateTime(2026, 5, 10)), isTrue);
      expect(dates.contains(DateTime(2026, 5, 5)), isFalse);
    });

    test('curriculum filter scopes the streak calendar', () async {
      await seedMark(
        'mish_may5',
        stageId: 1,
        source: CompletionSource.live,
        at: DateTime(2026, 5, 5, 9),
      );
      await seedMark(
        'bav_may10',
        stageId: 1,
        source: CompletionSource.live,
        at: DateTime(2026, 5, 10, 10),
        curriculum: CurriculumId.bavli,
      );

      final allDates = await service.getStreakCalendarLive(
        startDate: _startDate,
        endDate: _endDate,
      );
      expect(
        allDates,
        containsAll([DateTime(2026, 5, 5), DateTime(2026, 5, 10)]),
      );

      final mishOnly = await service.getStreakCalendarLive(
        startDate: _startDate,
        endDate: _endDate,
        curriculumId: _curriculumId.storageKey,
      );
      expect(mishOnly, contains(DateTime(2026, 5, 5)));
      expect(mishOnly, isNot(contains(DateTime(2026, 5, 10))));

      final bavOnly = await service.getStreakCalendarLive(
        startDate: _startDate,
        endDate: _endDate,
        curriculumId: CurriculumId.bavli.storageKey,
      );
      expect(bavOnly, contains(DateTime(2026, 5, 10)));
      expect(bavOnly, isNot(contains(DateTime(2026, 5, 5))));
    });
  });
}
