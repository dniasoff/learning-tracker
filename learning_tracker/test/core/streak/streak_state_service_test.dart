/// Tests for StreakStateService covering read() and watch().
library;

import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/time/local_day_clock.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart';
import 'package:learning_tracker/data/repositories/firestore_streak_event_repository.dart';
import 'package:learning_tracker/features/gamification/presentation/providers/gamification_service_providers.dart';
import 'package:learning_tracker/features/gamification/streak/streak_state_service.dart';

import '../../helpers/firestore_fake.dart';

void main() {
  const uid = 'streak-service-uid';
  late FakeFirebaseFirestore firestore;
  late FirestoreStreakEventRepository eventRepository;
  late ProviderContainer container;
  late FakeLocalDayClock clock;
  late StreakStateService provider;
  const profileId = 'streak-profile-ulid';
  const otherProfileId = 'other-streak-profile-ulid';

  // Captured before insertEvent() below so its `profileId` parameter can
  // default to the outer constant without being shadowed by its own name.
  const defaultProfileId = profileId;

  DateTime utcDay(DateTime instant) =>
      DateTime.utc(instant.year, instant.month, instant.day);

  Future<void> insertEvent(DateTime timestamp, {String? profileId}) async {
    final targetProfile = profileId ?? defaultProfileId;
    final repository = targetProfile == defaultProfileId
        ? eventRepository
        : FirestoreStreakEventRepository(
            firestore: firestore,
            uid: uid,
            profileId: targetProfile,
          );
    await repository.append(
      eventType: 'completion',
      eventTimestamp: timestamp,
      ulid: 'streak-${timestamp.microsecondsSinceEpoch}',
    );
  }

  setUp(() async {
    firestore = createFakeFirestore(authenticatedUid: uid);
    eventRepository = FirestoreStreakEventRepository(
      firestore: firestore,
      uid: uid,
      profileId: profileId,
    );
    clock = FakeLocalDayClock(DateTime.utc(2026, 5, 14, 12));
    container = ProviderContainer(
      overrides: [
        firestoreStreakEventRepositoryProvider.overrideWith(
          (ref) async => eventRepository,
        ),
        streakStateProvider.overrideWith(
          (ref) => StreakStateService(ref: ref, clock: clock, dayOf: utcDay),
        ),
      ],
    );
    provider = container.read(streakStateProvider);
    addTearDown(container.dispose);
  });

  // ── read() ────────────────────────────────────────────────────────────────

  group('StreakStateService.read', () {
    test('returns zero streak when no events exist', () async {
      final state = await provider.read();
      expect(state.currentStreak, 0);
    });

    test('returns empty state when no events', () async {
      final state = await provider.read();
      expect(state.currentStreak, 0);
      expect(state.maxStreak, 0);
      expect(state.lastCompletionDayLocal, isNull);
    });

    test('returns streak of 1 for a single completion today', () async {
      await insertEvent(DateTime.utc(2026, 5, 14));

      final state = await provider.read();
      expect(state.currentStreak, 1);
      expect(state.maxStreak, 1);
    });

    test(
      'returns streak of 2 for completions on two consecutive days',
      () async {
        await insertEvent(DateTime.utc(2026, 5, 13));
        await insertEvent(DateTime.utc(2026, 5, 14));

        final state = await provider.read();
        expect(state.currentStreak, 2);
        expect(state.maxStreak, 2);
      },
    );

    test('streak lapses when last completion was 2+ days ago', () async {
      // Last completion 3 days ago, today is May 14.
      await insertEvent(DateTime.utc(2026, 5, 11));

      final state = await provider.read();
      expect(state.currentStreak, 0);
      expect(state.maxStreak, 1);
    });

    test('currentStreak for a fixed one-UTC-day gap does not depend on the '
        'host machine timezone (AUD-t-cross-79)', () async {
      // A completion at 2026-05-10 00:00 UTC and "today" pinned at
      // 2026-05-11 12:00 UTC are exactly one UTC calendar day apart --
      // still "alive" per the reducer's <=1-day grace window -- and that
      // answer must not depend on the executing machine's timezone.
      clock.setNow(DateTime.utc(2026, 5, 11, 12));
      await insertEvent(DateTime.utc(2026, 5, 10));

      final state = await provider.read();

      expect(
        state.currentStreak,
        1,
        reason:
            'events exactly one UTC calendar day apart must stay "alive" '
            "independent of the executing machine's TZ",
      );
    });

    test('does not count events from another profile', () async {
      // Insert event for profile 2.
      await insertEvent(DateTime.utc(2026, 5, 14), profileId: otherProfileId);

      final state = await provider.read();
      expect(state.currentStreak, 0);
    });
  });

  // ── watch() ───────────────────────────────────────────────────────────────

  group('StreakStateService.watch', () {
    test('emits streak state as a stream', () async {
      // First emission should be the initial state (no events = 0 streak).
      final firstState = await provider.watch().first;
      expect(firstState.currentStreak, 0);
    });

    test('emits empty state when no events', () async {
      final state = await provider.watch().first;
      expect(state.currentStreak, 0);
      expect(state.maxStreak, 0);
    });

    test('emits zero streak when profile has no events', () async {
      final states = provider.watch();
      final first = await states.first;
      expect(first.currentStreak, 0);
    });

    test('emits updated state after event is inserted', () async {
      await insertEvent(DateTime.utc(2026, 5, 14));

      final state = await provider.watch().first;
      expect(state.currentStreak, 1);
      expect(state.maxStreak, 1);
    });

    test('stream emits new value when event is added while watching', () async {
      final states = <int>[];
      final sub = provider.watch().listen((s) => states.add(s.currentStreak));
      addTearDown(sub.cancel);

      // Give the first emission time to arrive.
      await Future<void>.delayed(Duration.zero);
      expect(states.first, 0); // zero at start

      await insertEvent(DateTime.utc(2026, 5, 14));
      await Future<void>.delayed(Duration.zero);

      // Should have received at least 2 emissions.
      expect(states.length, greaterThanOrEqualTo(2));
      expect(states.last, 1);
    });

    // ── D17 regression: a throw inside onListen must surface as a stream ──
    // error, not silently hang the stream (perpetual loading). Reproduces the
    // D20 teardown window where the backing read handle becomes unavailable.
    test(
      'D17: error from restoreIfEmpty in onListen surfaces as a stream error '
      'instead of hanging forever',
      () async {
        // Resolve the Firestore repository as unavailable, modelling the
        // profile/account swap window without constructing a Drift database.
        final unavailableContainer = ProviderContainer(
          overrides: [
            firestoreStreakEventRepositoryProvider.overrideWith(
              (ref) async => null,
            ),
            streakStateProvider.overrideWith(
              (ref) =>
                  StreakStateService(ref: ref, clock: clock, dayOf: utcDay),
            ),
          ],
        );
        addTearDown(unavailableContainer.dispose);
        final unavailableProvider = unavailableContainer.read(
          streakStateProvider,
        );

        // Before the fix the unhandled async throw inside onListen meant the
        // The failure must reach the consumer as a stream error promptly (NOT
        // a timeout).
        await expectLater(
          unavailableProvider.watch().first.timeout(const Duration(seconds: 2)),
          throwsA(isNot(isA<TimeoutException>())),
          reason:
              'a restore/DB failure must reach the consumer as a stream error, '
              'not leave the stream stuck with no emission',
        );
      },
    );

    // ── D17: a dashboard left open across local midnight lapses the streak ──
    test(
      'D17: advancing the clock past local midnight (no new events) lapses the '
      'streak to 0 on the next rollover tick — without a relaunch',
      () async {
        // Seed a completion "today" (clock is 2026-05-14 in setUp).
        await insertEvent(DateTime.utc(2026, 5, 14, 12));

        final ticks = StreamController<void>();
        addTearDown(ticks.close);
        final states = <int>[];
        final sub = provider
            .watch(rolloverTicks: ticks.stream)
            .listen((s) => states.add(s.currentStreak));
        addTearDown(sub.cancel);

        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(states.last, 1, reason: 'streak alive on the seeded day');

        // Two local days pass with NO new completion, then a rollover tick.
        clock.advance(const Duration(days: 2));
        ticks.add(null);
        await Future<void>.delayed(const Duration(milliseconds: 10));

        expect(
          states.last,
          0,
          reason: 'recomputing today on the tick lapses the stale streak',
        );
      },
    );
  });
}
