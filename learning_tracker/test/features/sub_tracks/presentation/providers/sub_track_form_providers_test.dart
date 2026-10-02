import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/data/firestore/learner_state_repository_providers.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/learning/presentation/providers/learning_command_providers.dart';
import 'package:learning_tracker/features/profiles/profiles.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/providers/sub_track_providers.dart';
import 'package:learning_tracker/features/tutoring/tutoring.dart';

import '../../../../helpers/learner_state/fake_learning_commands.dart';
import '../../../../helpers/pump_app.dart';
import '../../../../helpers/sub_tracks/sub_track_harness.dart';

const _childId = '01J6Q2H4A8M7K3P9R5T6V8WXY9';

LearnerProfileEntity _profile(ProfileMode mode) => LearnerProfileEntity(
  profileId: _childId,
  displayName: 'Yehuda',
  mode: mode,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

class _PinFor extends ParentPinAuthenticatedProfileId {
  _PinFor(this.id);

  final String? id;

  @override
  String? build() => id;
}

Future<bool> _session({
  required LearnerProfileEntity? profile,
  String? pinFor,
  bool tutored = false,
}) async {
  final container = ProviderContainer(
    overrides: [
      activeProfileProvider.overrideWith((ref) async => profile),
      parentPinAuthenticatedProfileIdProvider.overrideWith(
        () => _PinFor(pinFor),
      ),
      if (tutored)
        activeTutoredProfileSelectionProvider.overrideWith(
          _FakeTutoredSelection.new,
        ),
    ],
  );
  addTearDown(container.dispose);
  final sub = container.listen(subTrackParentSessionProvider.future, (_, _) {});
  return sub.read();
}

class _FakeTutoredSelection extends ActiveTutoredProfileSelection {
  @override
  TutoredProfileSelection? build() => const TutoredProfileSelection(
    profileId: _childId,
    ownerUid: 'parent-uid',
    grantId: 'grant-1',
    permissions: TutorPermissions(),
    tutorOwnProfileId: '01J6Q2H4A8M7K3P9R5T6V8WXYA',
  );
}

void main() {
  group('subTrackParentSessionProvider (AC-3)', () {
    test('an adult profile is its own parent', () async {
      expect(await _session(profile: _profile(ProfileMode.adult)), isTrue);
    });

    test('a child profile without a parent PIN session is refused', () async {
      expect(await _session(profile: _profile(ProfileMode.child)), isFalse);
    });

    test(
      'a child profile with the parent PIN verified for it passes',
      () async {
        expect(
          await _session(
            profile: _profile(ProfileMode.child),
            pinFor: _childId,
          ),
          isTrue,
        );
      },
    );

    test('a PIN verified for another profile does not count', () async {
      expect(
        await _session(
          profile: _profile(ProfileMode.child),
          pinFor: '01J6Q2H4A8M7K3P9R5T6V8WXYB',
        ),
        isFalse,
      );
    });

    test('no profile or a tutored session is refused', () async {
      expect(await _session(profile: null), isFalse);
      expect(
        await _session(profile: _profile(ProfileMode.adult), tutored: true),
        isFalse,
      );
    });
  });

  group('learner reads', () {
    test('sub-tracks and intent come from the Story 2.1 / C0 ports', () async {
      final h = SubTrackHarness(
        deadline: '2028-06-01',
        seed: [storedSchoolYear('01JHARN0000000000000000001')],
      );
      addTearDown(h.dispose);
      final container = ProviderContainer(overrides: h.overrides());
      addTearDown(container.dispose);

      final tracks = container.listen(
        learnerSubTracksProvider.future,
        (_, _) {},
      );
      expect((await tracks.read()).single.id, '01JHARN0000000000000000001');

      final intent = container.listen(
        subTrackCurriculumIntentProvider(subTrackTestCurriculum).future,
        (_, _) {},
      );
      expect(
        await intent.read(),
        const SubTrackCurriculumIntent(deadline: '2028-06-01'),
      );
    });

    test('a calendar program marks the curriculum', () async {
      final h = SubTrackHarness(calendarProgramId: 'daf_yomi');
      addTearDown(h.dispose);
      final container = ProviderContainer(overrides: h.overrides());
      addTearDown(container.dispose);
      final intent = container.listen(
        subTrackCurriculumIntentProvider(subTrackTestCurriculum).future,
        (_, _) {},
      );
      expect((await intent.read()).followsCalendarProgram, isTrue);
    });

    test('no learner: empty sub-tracks and an empty intent', () async {
      final container = ProviderContainer(
        overrides: [
          activeLearnerScopeProvider.overrideWith((ref) async => null),
        ],
      );
      addTearDown(container.dispose);
      final tracks = container.listen(
        learnerSubTracksProvider.future,
        (_, _) {},
      );
      expect(await tracks.read(), isEmpty);
      final intent = container.listen(
        subTrackCurriculumIntentProvider('mishnayos').future,
        (_, _) {},
      );
      expect(await intent.read(), const SubTrackCurriculumIntent());
    });

    test('pending failures keep only sub-track batches', () async {
      final commands = FakeLearningCommands();
      final container = ProviderContainer(
        overrides: [
          learningCommandsProvider.overrideWith((ref) async => commands),
        ],
      );
      addTearDown(container.dispose);
      final sub = container.listen(subTrackPendingFailuresProvider, (_, _) {});
      await pumpEventQueue();
      commands.pendingFailures.add(const [
        PendingFailure(
          id: 'entry',
          eventIds: [],
          changeIds: ['entry'],
          reason: PendingFailureReason.permissionDenied,
        ),
        PendingFailure(
          id: 'event',
          eventIds: ['ev'],
          changeIds: [],
          reason: PendingFailureReason.other,
        ),
      ]);
      await pumpEventQueue();
      expect(sub.read().value!.map((f) => f.id), ['entry']);
    });
  });

  testWidgets('the leaf-unit label follows the curriculum', (tester) async {
    final h = SubTrackHarness();
    addTearDown(h.dispose);
    late String label;
    await tester.pumpWidget(
      pumpApp(
        overrides: h.overrides(),
        child: Consumer(
          builder: (context, ref, _) {
            label = subTrackLeafUnitLabel(ref, subTrackTestCurriculum);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(label, 'Mishnayos');
  });
}
