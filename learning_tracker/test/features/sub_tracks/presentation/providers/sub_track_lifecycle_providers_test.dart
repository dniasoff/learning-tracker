/// Story 2.8 (DNI-499) T4 (AC-5, AC-6): the hub's active/ended split over
/// Story 2.4's complete read (`learnerSubTracksProvider`) on the learner's
/// civil today moves an elapsed window to Ended at the learner's midnight
/// without any write.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/time/local_day_clock.dart';
import 'package:learning_tracker/data/firestore/learner_state_repository_providers.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings_history.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/learner_lock_settings_provider.dart';
import 'package:learning_tracker/features/sub_tracks/domain/sub_track_lifecycle.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/providers/sub_track_lifecycle_providers.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/providers/sub_track_providers.dart';

import '../../../../helpers/learner_state/c0_fixtures.dart';
import '../../../../helpers/learner_state/in_memory_ports.dart';
import '../../../../helpers/learner_state_fixtures.dart';

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
    c
      ..listen(learnerSubTracksProvider, (_, _) {})
      ..listen(subTrackLifecycleTodayProvider, (_, _) {})
      ..listen(learnerLockSettingsProvider(scope), (_, _) {});
    final tracks = await c.read(learnerSubTracksProvider.future);
    await c.read(learnerLockSettingsProvider(scope).future);
    final groups = groupSubTracksByLifecycle(
      tracks,
      c.read(subTrackLifecycleTodayProvider),
    );
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
}
