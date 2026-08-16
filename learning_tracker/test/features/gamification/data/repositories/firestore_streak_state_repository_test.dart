import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/time/local_day_clock.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/data/firestore/account_firebase.dart';
import 'package:learning_tracker/data/firestore/active_account_providers.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart'
    show activeProfileDocIdProvider;
import 'package:learning_tracker/features/gamification/data/repositories/firestore_streak_state_repository.dart';
import 'package:learning_tracker/features/gamification/streak/streak_event_entry.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/data_export_firestore_test_support.dart';

class MockFirebaseApp extends Mock implements FirebaseApp {}

class MockFirebaseAuthHandle extends Mock implements FirebaseAuth {}

void main() {
  FirestoreStreakStateRepository buildAdapter(
    ProviderContainer container, {
    LocalDayClock? clock,
  }) {
    final adapterProvider = Provider<FirestoreStreakStateRepository>(
      (ref) => FirestoreStreakStateRepository(ref: ref, clock: clock),
    );
    return container.read(adapterProvider);
  }

  group('not ready (no active account/profile)', () {
    test('getStreak throws instead of returning StreakState.empty', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final adapter = buildAdapter(container);

      await expectLater(
        adapter.getStreak(),
        throwsA(isA<StreakStateRepositoryNotReadyException>()),
      );
    });

    test(
      'getRecoveryInfo throws instead of reflecting an empty streak',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final adapter = buildAdapter(container);

        await expectLater(
          adapter.getRecoveryInfo(),
          throwsA(isA<StreakStateRepositoryNotReadyException>()),
        );
      },
    );

    test(
      'getStreakCalendar throws instead of returning an empty set',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final adapter = buildAdapter(container);

        await expectLater(
          adapter.getStreakCalendar(
            startUtc: DateTime.utc(2026, 5, 1),
            endUtc: DateTime.utc(2026, 5, 31),
          ),
          throwsA(isA<StreakStateRepositoryNotReadyException>()),
        );
      },
    );

    test(
      'watchStreak emits a not-ready error instead of a zero state',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final adapter = buildAdapter(container);

        await expectLater(
          adapter.watchStreak().toList(),
          throwsA(isA<StreakStateRepositoryNotReadyException>()),
        );
      },
    );
  });

  group('ready (active account + profile)', () {
    const uid = 'uid-1';
    const profileDocId = testProfileId;

    late FakeFirebaseFirestore firestore;
    late ProviderContainer container;
    late FakeLocalDayClock clock;

    AccountFirebaseHandles handles() {
      return AccountFirebaseHandles(
        app: MockFirebaseApp(),
        firestore: firestore,
        auth: MockFirebaseAuthHandle(),
        uid: uid,
      );
    }

    setUp(() {
      firestore = FakeFirebaseFirestore();
      // Anchor "today" so streak math is deterministic regardless of the
      // host machine's timezone/clock.
      clock = FakeLocalDayClock(DateTime.utc(2026, 5, 3));
      container = ProviderContainer(
        overrides: [
          activeAccountFirebaseProvider.overrideWith((ref) async => handles()),
        ],
      );
      container.read(activeProfileDocIdProvider.notifier).set(profileDocId);
    });

    tearDown(() => container.dispose());

    Future<void> writeEvent({
      required String ulid,
      required String eventType,
      required DateTime eventTimestamp,
    }) async {
      final ts = eventTimestamp.toUtc();
      final entry = StreakEventEntry(
        ulid: ulid,
        eventType: eventType,
        dayUtc: DateTime.utc(ts.year, ts.month, ts.day),
        eventTimestamp: ts,
      );
      await firestore
          .collection('users')
          .doc(uid)
          .collection('learner_profiles')
          .doc(profileDocId)
          .collection('streak_events')
          .doc(ulid)
          .set(entry.toFirestore());
    }

    test(
      'getStreak derives a 2-day run from two consecutive completion days',
      () async {
        await writeEvent(
          ulid: 'evt1',
          eventType: 'completion',
          eventTimestamp: DateTime.utc(2026, 5, 2),
        );
        await writeEvent(
          ulid: 'evt2',
          eventType: 'completion',
          eventTimestamp: DateTime.utc(2026, 5, 3),
        );

        final adapter = buildAdapter(container, clock: clock);
        final result = await adapter.getStreak();

        expect(result.currentStreak, 2);
        expect(result.maxStreak, 2);
      },
    );

    test('getStreak ignores non-completion event types', () async {
      await writeEvent(
        ulid: 'evt1',
        eventType: 'day_boundary',
        eventTimestamp: DateTime.utc(2026, 5, 3),
      );

      final adapter = buildAdapter(container, clock: clock);
      final result = await adapter.getStreak();

      expect(result.currentStreak, 0);
    });

    test('getStreak reports a lapsed streak (0) when the last completion was '
        'more than one day ago', () async {
      await writeEvent(
        ulid: 'evt1',
        eventType: 'completion',
        eventTimestamp: DateTime.utc(2026, 4, 20),
      );

      final adapter = buildAdapter(container, clock: clock);
      final result = await adapter.getStreak();

      expect(result.currentStreak, 0);
      expect(result.maxStreak, 1);
    });

    test('getRecoveryInfo always reports wasRecovered: false', () async {
      await writeEvent(
        ulid: 'evt1',
        eventType: 'completion',
        eventTimestamp: DateTime.utc(2026, 5, 3),
      );

      final adapter = buildAdapter(container, clock: clock);
      final result = await adapter.getRecoveryInfo();

      expect(result.wasRecovered, isFalse);
      expect(result.currentStreak, 1);
    });

    test('getStreakCalendar returns local dates within range', () async {
      await writeEvent(
        ulid: 'evt1',
        eventType: 'completion',
        eventTimestamp: DateTime.utc(2026, 5, 2),
      );
      await writeEvent(
        ulid: 'evt2',
        eventType: 'completion',
        eventTimestamp: DateTime.utc(2026, 5, 10),
      );

      final adapter = buildAdapter(container, clock: clock);
      final result = await adapter.getStreakCalendar(
        startUtc: DateTime.utc(2026, 5, 1),
        endUtc: DateTime.utc(2026, 5, 5),
      );

      // Expected values derived through the SAME LocalDayUtils.extractLocalDate
      // conversion the adapter uses internally, rather than a hardcoded
      // `DateTime(...)` literal — extractLocalDate returns a LOCAL (not
      // UTC) DateTime (see its own doc comment), so a literal would be
      // timezone-dependent on the host running the test.
      expect(
        result,
        contains(LocalDayUtils.extractLocalDate(DateTime.utc(2026, 5, 2))),
      );
      expect(
        result,
        isNot(
          contains(LocalDayUtils.extractLocalDate(DateTime.utc(2026, 5, 10))),
        ),
      );
    });

    test(
      'watchStreak emits the derived state from the live event feed',
      () async {
        await writeEvent(
          ulid: 'evt1',
          eventType: 'completion',
          eventTimestamp: DateTime.utc(2026, 5, 3),
        );

        final adapter = buildAdapter(container, clock: clock);
        final first = await adapter.watchStreak().first;

        expect(first.currentStreak, 1);
      },
    );
  });
}
