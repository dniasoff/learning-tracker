/// Story 2.8 (DNI-499) T4 (AC-5, AC-6): the lifecycle reads split on the
/// learner's civil today, move an elapsed window to Ended at the learner's
/// midnight without any write, and resolve the viewer role.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/time/local_day_clock.dart';
import 'package:learning_tracker/domain/learner_state/goals.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings_history.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/domain/learner_state/ports/governed_intent_repository.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/features/profiles/domain/models/learner_profile_entity.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/parent_pin_session_provider.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/learner_lock_settings_provider.dart';
import 'package:learning_tracker/features/sub_tracks/data/repositories/sub_track_lifecycle_sources.dart';
import 'package:learning_tracker/features/sub_tracks/domain/sub_track_lifecycle.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/providers/sub_track_lifecycle_providers.dart';

import '../../../helpers/learner_state/c0_fixtures.dart';
import '../../../helpers/learner_state/in_memory_ports.dart';
import '../../../helpers/learner_state_fixtures.dart';

SubTrack _track(String id, {String? windowEnd, SubTrackEndReason? endReason}) =>
    SubTrack(
      id: id,
      curriculumId: 'shas',
      name: 'Track $id',
      type: SubTrackType.ongoing,
      windowStart: '2026-01-01',
      windowEnd: windowEnd,
      ratePerWeek: 5,
      weeksPerYear: 40,
      learnsOnShabbos: false,
      ground: const [NodeEntry(level: 'masechta', ref: 'Berakhot')],
      lastChangeId: ulidE,
      endedAt: endReason == null ? null : t1,
      endReason: endReason,
    );

LearnerProfileEntity _profile(ProfileMode mode) => LearnerProfileEntity(
  profileId: profileUlid,
  displayName: 'Dovi',
  mode: mode,
  createdAt: t2,
  updatedAt: t2,
);

class _Ready extends Notifier<bool> {
  @override
  bool build() => false;

  void set() => state = true;
}

void main() {
  final scope = c0Scope();
  late InMemorySubTrackRepository repo;
  late FakeLocalDayClock clock;

  setUp(() {
    repo = InMemorySubTrackRepository()
      ..seed(scope, [
        _track(ulidA),
        _track(ulidB, windowEnd: '2026-09-06'),
        _track(ulidC, endReason: SubTrackEndReason.deleted),
      ]);
    // 22:30 UTC on 6 Sep: still 6 Sep in UTC, already 7 Sep in Jerusalem.
    clock = FakeLocalDayClock(DateTime.utc(2026, 9, 6, 22, 30));
  });

  tearDown(() => repo.dispose());

  ProviderContainer container({String timeZone = 'Asia/Jerusalem'}) {
    final c = ProviderContainer.test(
      overrides: [
        localDayClockProvider.overrideWithValue(clock),
        activeLearnerScopeProvider.overrideWith((ref) async => scope),
        subTrackRepositoryProvider.overrideWith((ref) async => repo),
        learnerLockSettingsProvider.overrideWith(
          (ref, _) => Stream.value(
            LearnerSettingsHistory.constant(
              LearnerSettings(profileId: profileUlid, timeZone: timeZone),
            ),
          ),
        ),
      ],
    );
    return c;
  }

  Future<List<String>> endedIds(ProviderContainer c) async {
    c.listen(subTrackLifecycleGroupsProvider, (_, _) {});
    c.listen(learnerLockSettingsProvider(scope), (_, _) {});
    await c.read(subTrackLifecycleTracksProvider.future);
    await c.read(learnerLockSettingsProvider(scope).future);
    final groups = c.read(subTrackLifecycleGroupsProvider).requireValue;
    return [for (final t in groups.ended) t.id];
  }

  test("today is the learner's civil date, not the UTC one (AD-41)", () async {
    final jerusalem = container();
    await endedIds(jerusalem);
    expect(jerusalem.read(subTrackLifecycleTodayProvider), '2026-09-07');
    final utc = container(timeZone: 'UTC');
    await endedIds(utc);
    expect(utc.read(subTrackLifecycleTodayProvider), '2026-09-06');
  });

  test('a window passing at the learner midnight moves the track to Ended '
      'with no write, change-log entry or ended_at', () async {
    clock.setNow(DateTime.utc(2026, 9, 6, 20, 30)); // 23:30 in Jerusalem
    final before = container();
    expect(await endedIds(before), [ulidC]);
    before.dispose();

    clock.setNow(DateTime.utc(2026, 9, 6, 21, 30)); // 00:30 on 7 Sep
    final after = container();
    expect(await endedIds(after), [ulidB, ulidC]);
    expect(repo.calls, isEmpty);
    expect(repo.entries, isEmpty);
    final stored = repo.tracksOf(scope).firstWhere((t) => t.id == ulidB);
    expect(stored.endedAt, isNull);
    expect(stored.endReason, isNull);
  });

  group('not ready is a read failure, never a false empty list', () {
    Future<void> expectNotReady(ProviderContainer c) async {
      c.listen(subTrackLifecycleGroupsProvider, (_, _) {});
      await expectLater(
        c.read(subTrackLifecycleTracksProvider.future),
        throwsA(isA<SubTrackReadNotReadyException>()),
      );
      final groups = c.read(subTrackLifecycleGroupsProvider);
      expect(groups.hasError, isTrue);
      expect(groups.value, isNull);
    }

    test('no learner scope yet', () async {
      await expectNotReady(
        ProviderContainer.test(
          overrides: [
            localDayClockProvider.overrideWithValue(clock),
            activeLearnerScopeProvider.overrideWith((ref) async => null),
            subTrackRepositoryProvider.overrideWith((ref) async => repo),
          ],
        ),
      );
    });

    test('sub-track repository not ready (account degraded)', () async {
      await expectNotReady(
        ProviderContainer.test(
          overrides: [
            localDayClockProvider.overrideWithValue(clock),
            activeLearnerScopeProvider.overrideWith((ref) async => scope),
            subTrackRepositoryProvider.overrideWith((ref) async => null),
          ],
        ),
      );
    });

    test('the read starts by itself once the repository is ready', () async {
      final ready = NotifierProvider<_Ready, bool>(_Ready.new);
      final c = ProviderContainer.test(
        overrides: [
          localDayClockProvider.overrideWithValue(clock),
          activeLearnerScopeProvider.overrideWith((ref) async => scope),
          subTrackRepositoryProvider.overrideWith(
            (ref) async => ref.watch(ready) ? repo : null,
          ),
        ],
      );
      await expectNotReady(c);
      c.read(ready.notifier).set();
      final tracks = await c.read(subTrackLifecycleTracksProvider.future);
      expect([for (final t in tracks) t.id], [ulidA, ulidB, ulidC]);
    });
  });

  test('the deadline is the live deadline goal of the curriculum', () async {
    final intent = InMemoryGovernedIntentRepository()
      ..emit(
        scope,
        LearnerIntent(
          settings: c0Settings,
          mainTracks: const {},
          goals: {
            'shas': const CurriculumGoals(
              deadline: DeadlineGoal(
                curriculumId: 'shas',
                targetDate: '2027-06-30',
              ),
            ),
            'mishnayos': CurriculumGoals(
              deadline: DeadlineGoal(
                curriculumId: 'mishnayos',
                targetDate: '2027-06-30',
                endedAt: t1,
              ),
            ),
          },
        ),
      );
    final c = ProviderContainer.test(
      overrides: [
        activeLearnerScopeProvider.overrideWith((ref) async => scope),
        governedIntentRepositoryProvider.overrideWith((ref) async => intent),
      ],
    );
    c.listen(subTrackCurriculumDeadlineProvider('shas'), (_, _) {});
    c.listen(subTrackCurriculumDeadlineProvider('mishnayos'), (_, _) {});
    expect(
      await c.read(subTrackCurriculumDeadlineProvider('shas').future),
      '2027-06-30',
    );
    expect(
      await c.read(subTrackCurriculumDeadlineProvider('mishnayos').future),
      isNull,
    );
    await intent.dispose();
  });

  group('viewer', () {
    Future<SubTrackLifecycleViewer> viewer(
      ProfileMode mode, {
      String? pin,
    }) async {
      final c = ProviderContainer.test(
        overrides: [
          activeProfileProvider.overrideWith((ref) async => _profile(mode)),
        ],
      );
      if (pin != null) {
        c
            .read(parentPinAuthenticatedProfileIdProvider.notifier)
            .setAuthenticated(pin);
      }
      c.listen(subTrackLifecycleViewerProvider, (_, _) {});
      await c.read(activeProfileProvider.future);
      return c.read(subTrackLifecycleViewerProvider);
    }

    test('an adult is the parent', () async {
      expect(await viewer(ProfileMode.adult), SubTrackLifecycleViewer.parent);
    });

    test('a child is read-only until the parent PIN is verified', () async {
      expect(await viewer(ProfileMode.child), SubTrackLifecycleViewer.readOnly);
      expect(
        await viewer(ProfileMode.child, pin: profileUlid),
        SubTrackLifecycleViewer.parent,
      );
    });
  });
}
