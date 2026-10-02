// DNI-497 (Story 2.6) T1: the detail provider joins the selected sub-track
// with the complete engine inputs and publishes only engine values.
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/ports/complete_read.dart';
import 'package:learning_tracker/features/profiles/profiles.dart';
import 'package:learning_tracker/features/sub_tracks/domain/sub_track_detail.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/providers/sub_track_detail_provider.dart';

import '../../../../helpers/learner_state/engine_fixtures.dart';
import '../../sub_track_detail_harness.dart';

void main() {
  late DetailHarness h;
  setUp(() => h = DetailHarness());
  tearDown(() => h.dispose());

  ProviderContainer container({Stream<LearnerState>? state}) {
    final c = ProviderContainer(overrides: h.overrides(state: state));
    addTearDown(c.dispose);
    return c;
  }

  Future<AsyncValue<SubTrackDetail>> settle(
    ProviderContainer c,
    String id,
  ) async {
    final sub = c.listen(subTrackDetailProvider(id), (_, _) {});
    addTearDown(sub.close);
    for (var i = 0; i < 20 && sub.read().isLoading; i++) {
      await pumpEventQueue();
    }
    return sub.read();
  }

  test('publishes the engine position, ticked count, remaining path and '
      'capacity values for the selected sub-track', () async {
    final school = detailSubTrack(10, 'School', const [berakhot1, peah]);
    h
      ..seed(
        subTracks: [school],
        learnEvents: [
          engineLearn(1, 'Mishnah Berakhot 1:1', source: school.id),
          engineLearn(2, 'Mishnah Berakhot 1:1', source: school.id),
          engineLearn(3, 'Mishnah Berakhot 1:2'),
        ],
      )
      ..capacities[school.id] = (capacity: 9, shortfall: 0);

    final detail = (await settle(container(), school.id)).requireValue;
    final engine = h.curriculum.subTracks[school.id]!;
    expect(detail.track, school);
    expect(detail.upNext, engine.position);
    expect(detail.upNext, 'Mishnah Berakhot 1:2');
    expect(detail.ticked, 1, reason: 'distinct leaves ticked here');
    expect(detail.remainingPath, engine.remainingPath.length);
    expect(detail.capacity, 9);
    expect(detail.hasDeadline, isTrue);
    expect(detail.ground.entries.map((r) => r.node), [berakhot1, peah]);
    expect(detail.ground.entries.first.learnt, 2, reason: 'all sources');
  });

  test('stays loading until every complete input is ready', () async {
    final school = detailSubTrack(10, 'School', const [peah]);
    h.seed(subTracks: [school]);
    final never = StreamController<LearnerState>();
    addTearDown(never.close);
    final value = await settle(container(state: never.stream), school.id);
    expect(value, isA<AsyncLoading<SubTrackDetail>>());
  });

  test('a missing or undecodable sub-track is an error', () async {
    final school = detailSubTrack(10, 'School', const [peah]);
    h.seed(subTracks: [school]);
    final c = container();
    expect(
      (await settle(c, engineUlid(77))).error,
      isA<SubTrackDetailUnavailable>(),
    );

    h.tracks.seedRejected(h.scope, [RejectedRow(school.id, 'bad')]);
    await pumpEventQueue();
    expect(
      c.read(subTrackDetailProvider(school.id)).error,
      isA<SubTrackDetailUnavailable>(),
    );
  });

  test('an engine error is forwarded', () async {
    final school = detailSubTrack(10, 'School', const [peah]);
    h.seed(subTracks: [school]);
    final value = await settle(
      container(state: Stream.error(StateError('engine'))),
      school.id,
    );
    expect(value.error, isA<StateError>());
  });

  test('a ground override re-projects the rows in the pending order', () async {
    final school = detailSubTrack(10, 'School', const [berakhot1, peah]);
    h.seed(subTracks: [school]);
    final c = ProviderContainer(
      overrides: [
        ...h.overrides(),
        subTrackGroundOverrideProvider(
          school.id,
        ).overrideWithValue(const [peah, berakhot1]),
      ],
    );
    addTearDown(c.dispose);
    final detail = (await settle(c, school.id)).requireValue;
    expect(detail.ground.entries.map((r) => r.node), [peah, berakhot1]);
  });

  group('role', () {
    LearnerProfileEntity profile(ProfileMode mode) => LearnerProfileEntity(
      profileId: 'p1',
      displayName: 'Dovid',
      mode: mode,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );

    Future<SubTrackDetailRole> roleWith(
      Future<LearnerProfileEntity?> Function() load, {
      String? pinProfileId,
    }) async {
      final c = ProviderContainer(
        overrides: [
          activeProfileProvider.overrideWith((ref) => load()),
          parentPinAuthenticatedProfileIdProvider.overrideWithValue(
            pinProfileId,
          ),
        ],
      );
      addTearDown(c.dispose);
      final sub = c.listen(subTrackDetailRoleProvider, (_, _) {});
      addTearDown(sub.close);
      await pumpEventQueue();
      return sub.read();
    }

    test('an adult profile is the parent', () async {
      expect(
        await roleWith(() async => profile(ProfileMode.adult)),
        SubTrackDetailRole.parent,
      );
    });

    test(
      'a child profile is the child until its parent PIN is verified',
      () async {
        expect(
          await roleWith(() async => profile(ProfileMode.child)),
          SubTrackDetailRole.child,
        );
        expect(
          await roleWith(
            () async => profile(ProfileMode.child),
            pinProfileId: 'p1',
          ),
          SubTrackDetailRole.parent,
        );
      },
    );

    test('a loading profile fails closed to the child', () async {
      expect(
        await roleWith(() => Completer<LearnerProfileEntity?>().future),
        SubTrackDetailRole.child,
      );
    });
  });
}
