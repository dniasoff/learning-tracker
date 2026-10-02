// DNI-497 (Story 2.6) T1: the detail provider joins the selected sub-track
// with the complete engine inputs and publishes only engine values.
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/data/firestore/tutor_scope_grant_providers.dart';
import 'package:learning_tracker/domain/learner_state/goals.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/domain/learner_state/ports/complete_read.dart';
import 'package:learning_tracker/domain/learner_state/ports/governed_intent_repository.dart';
import 'package:learning_tracker/domain/learner_state/ports/tutor_scope_grant_source.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_commands.dart';
import 'package:learning_tracker/features/learning/domain/commands/sub_track_commands.dart';
import 'package:learning_tracker/features/profiles/profiles.dart';
import 'package:learning_tracker/features/sub_tracks/domain/sub_track_detail.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/providers/sub_track_detail_provider.dart';
import 'package:learning_tracker/features/tutoring/tutoring.dart';

import '../../../../helpers/learner_state/c0_fixtures.dart';
import '../../../../helpers/learner_state/engine_fixtures.dart';
import '../../../../helpers/learner_state/fake_tutor_scope_grant_source.dart';
import '../../../../helpers/learner_state/in_memory_ports.dart';
import '../../../../helpers/learner_state_fixtures.dart';
import '../../sub_track_detail_harness.dart';

void main() {
  late DetailHarness h;
  setUp(() => h = DetailHarness());
  tearDown(() => h.dispose());

  ProviderContainer container({
    Stream<LearnerState>? state,
    LearningCommands? commands,
  }) {
    final c = ProviderContainer(
      overrides: h.overrides(state: state, commands: commands),
    );
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
      ..deadline = '2026-12-31';

    final detail = (await settle(container(), school.id)).requireValue;
    final engine = h.curriculum.subTracks[school.id]!;
    expect(detail.track, school);
    expect(detail.upNext, engine.position);
    expect(detail.upNext, 'Mishnah Berakhot 1:2');
    expect(detail.ticked, 1, reason: 'distinct leaves ticked here');
    expect(detail.remainingPath, engine.remainingPath.length);
    expect(detail.capacity, engine.capacity);
    expect(detail.shortfall, engine.shortfall);
    expect(detail.hasCapacity, isTrue);
    expect(detail.noDeadline, isFalse);
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

    h.repository.seedRejected([RejectedRow(school.id, 'bad')]);
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

  group('ground edits (AC-5, AC-6, UX-DR-124)', () {
    test('groundOver: the pending order wins; a refused order still in the '
        'store shows the last confirmed one; otherwise the store', () {
      const refused = SubTrackGroundRollback(
        rejected: [peah, berakhot1],
        prior: [berakhot1, peah],
        removal: false,
      );
      expect(
        const SubTrackGroundEditState(
          pending: [peah],
          rollback: refused,
        ).groundOver(const [berakhot1, peah]),
        const [peah],
      );
      const rolledBack = SubTrackGroundEditState(rollback: refused);
      expect(rolledBack.groundOver(const [peah, berakhot1]), const [
        berakhot1,
        peah,
      ]);
      expect(rolledBack.groundOver(const [berakhot2]), const [
        berakhot2,
      ], reason: 'the store moved on (reverted or edited elsewhere)');
      expect(const SubTrackGroundEditState().groundOver(const [peah]), const [
        peah,
      ]);
    });

    test(
      'a queued edit later refused restores the last confirmed order '
      'even before the store reverts it, and counts a late rejection',
      () async {
        final school = detailSubTrack(10, 'School', const [berakhot1, peah]);
        h.seed(subTracks: [school]);
        h.tracks.offline = true; // applied locally, never acknowledged here
        final intent = InMemoryGovernedIntentRepository()
          ..emit(
            h.scope,
            LearnerIntent(
              settings: c0Settings,
              mainTracks: {engineCurriculum: engineIntent()},
              goals: const <String, CurriculumGoals>{},
            ),
          );
        final failures = StreamController<List<PendingFailure>>.broadcast();
        var ids = 0;
        final inner = SubTrackCommands(
          scope: h.scope,
          actor: parentActor,
          subTracks: h.repository,
          intent: intent,
          today: () => '2026-09-07',
          nowUtc: () => engineAt(10000),
          newId: () => engineUlid(5000 + ++ids),
          ackTimeout: const Duration(milliseconds: 10),
        );
        addTearDown(() async {
          await failures.close();
          await inner.dispose();
          await intent.dispose();
        });
        final c = container(commands: _QueuedCommands(inner, failures.stream));
        final edits = c.listen(
          subTrackGroundEditorProvider(school.id),
          (_, _) {},
        );
        addTearDown(edits.close);
        await settle(c, school.id);
        List<NodeEntry> shown() => [
          for (final r
              in c
                  .read(subTrackDetailProvider(school.id))
                  .requireValue
                  .ground
                  .entries)
            r.node,
        ];
        expect(shown(), const [berakhot1, peah]);

        final accepted = await c
            .read(subTrackGroundEditorProvider(school.id).notifier)
            .commit(const [peah, berakhot1], prior: const [berakhot1, peah]);
        await pumpEventQueue();
        expect(accepted, isTrue, reason: 'queued counts as accepted');
        expect(shown(), const [peah, berakhot1]);
        expect(edits.read().lateRejections, 0);
        final changeId = h.tracks.entries.single.$2.id;

        // The server refuses it for good; the store keeps the unsaved order.
        PendingFailure refused(String id) => PendingFailure(
          id: id,
          eventIds: const [],
          changeIds: [id],
          reason: PendingFailureReason.permissionDenied,
        );
        failures.add([refused('unrelated'), refused(changeId)]);
        await pumpEventQueue();
        expect(edits.read().lateRejections, 1);
        expect(edits.read().rollback!.removal, isFalse);
        expect(h.tracks.tracksOf(h.scope).single.ground, const [
          peah,
          berakhot1,
        ]);
        expect(shown(), const [berakhot1, peah]);

        // The same failure listed again is not a second rejection.
        failures.add([refused(changeId)]);
        await pumpEventQueue();
        expect(edits.read().lateRejections, 1);
      },
    );
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
  group('tutored session (grant-gated read, DNI-523)', () {
    late FakeTutorScopeGrantSource grants;
    setUp(() => grants = FakeTutorScopeGrantSource());

    ProviderContainer tutored() {
      final c = ProviderContainer(
        overrides: [
          ...h.overrides(role: SubTrackDetailRole.tutor),
          tutorScopeGrantSourceProvider.overrideWith((ref) async => grants),
          activeTutoredProfileSelectionProvider.overrideWithValue(
            TutoredProfileSelection(
              profileId: h.scope.profileId,
              ownerUid: h.scope.ownerUid,
              grantId: 'grant',
              permissions: TutorPermissions.readOnly(),
            ),
          ),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('reads nothing of the learner until an active grant authorizes '
        'the tutor', () async {
      final school = detailSubTrack(10, 'School', const [peah]);
      h.seed(subTracks: [school]);
      final c = tutored();
      expect(await settle(c, school.id), isA<AsyncLoading<SubTrackDetail>>());
      expect(c.exists(subTrackDetailTracksProvider(h.scope)), isFalse);
      expect(c.exists(subTrackDetailEventsProvider(h.scope)), isFalse);
    });

    test('a granted tutor sees the detail; once the grant is revoked the '
        'detail is a fresh access-denied error with no cached value, and the '
        'sub-track and event reads are released', () async {
      final school = detailSubTrack(10, 'School', const [berakhot1, peah]);
      h.seed(subTracks: [school]);
      grants.grant(h.scope);
      final c = tutored();
      final sub = c.listen(subTrackDetailProvider(school.id), (_, _) {});
      addTearDown(sub.close);
      for (var i = 0; i < 20 && sub.read().isLoading; i++) {
        await pumpEventQueue();
      }
      expect(sub.read().requireValue.track, school);
      expect(c.exists(subTrackDetailTracksProvider(h.scope)), isTrue);

      grants.deny(h.scope, TutorScopeDenialReason.grantNotActive);
      await pumpEventQueue();
      final denied = sub.read();
      expect(denied.error, isA<TutorScopeAccessDeniedException>());
      expect(denied.hasValue, isFalse);
      await pumpEventQueue();
      expect(c.exists(subTrackDetailTracksProvider(h.scope)), isFalse);
      expect(c.exists(subTrackDetailEventsProvider(h.scope)), isFalse);
    });
  });
}

/// The real sub-track commands for writes, with a scripted
/// pending-failure feed.
final class _QueuedCommands implements LearningCommands {
  _QueuedCommands(this.inner, this.failures);

  final SubTrackCommands inner;
  final Stream<List<PendingFailure>> failures;

  @override
  Future<CaptureResult> editSubTrack(String subTrackId, SubTrackEdit edit) =>
      inner.editSubTrack(subTrackId, edit);

  @override
  Stream<List<PendingFailure>> watchPendingFailures() => failures;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}
