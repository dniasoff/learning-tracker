// DNI-496 (Story 2.5): the form-facing selectors — learner civil today in
// the profile's time zone (AD-41), the curriculum's sub-tracks as a
// complete read, the AD-45 ongoing count, calendar-program detection and
// the parent-session gate (DNI-495 seam).
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/time/local_day_clock.dart';
import 'package:learning_tracker/domain/learner_state/goals.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings.dart';
import 'package:learning_tracker/domain/learner_state/main_track_intent.dart';
import 'package:learning_tracker/domain/learner_state/ports/complete_read.dart';
import 'package:learning_tracker/domain/learner_state/ports/governed_intent_repository.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/features/profiles/domain/models/learner_profile_entity.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/parent_pin_session_provider.dart';
import 'package:learning_tracker/features/sub_tracks/data/repositories/ongoing_sub_track_sources.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/providers/ongoing_sub_track_providers.dart';
import 'package:learning_tracker/features/tutoring/domain/models/session_role.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_permissions.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/active_tutored_profile_provider.dart';

import '../../../../helpers/learner_state/c0_fixtures.dart';
import '../../../../helpers/learner_state/in_memory_ports.dart';
import '../../../../helpers/learner_state_fixtures.dart';

const _curriculum = 'mishnayos';

String _ulid(int n) => '01J${n.toString().padLeft(23, '0')}';

SubTrack _track(
  int id, {
  String curriculumId = _curriculum,
  String start = '2026-09-01',
  String? end,
  bool ended = false,
}) => SubTrack(
  id: _ulid(id),
  curriculumId: curriculumId,
  name: 'Sub $id',
  type: SubTrackType.ongoing,
  windowStart: start,
  windowEnd: end,
  ratePerWeek: 5,
  weeksPerYear: 52,
  learnsOnShabbos: false,
  ground: const [],
  lastChangeId: _ulid(id + 500),
  endedAt: ended ? DateTime.utc(2026, 9, 2) : null,
  endReason: ended ? SubTrackEndReason.ended : null,
);

LearnerIntent _intent({
  String timeZone = 'UTC',
  String? programId,
}) => LearnerIntent(
  settings: LearnerSettings(profileId: profileUlid, timeZone: timeZone),
  mainTracks: {
    _curriculum: MainTrackIntent(
      curriculumId: _curriculum,
      track: MainTrack(curriculumId: _curriculum, state: MainTrackState.active),
      program: programId == null
          ? null
          : MainTrackProgram(curriculumId: _curriculum, programId: programId),
    ),
  },
  goals: const <String, CurriculumGoals>{},
);

void main() {
  late InMemorySubTrackRepository subTracks;
  late InMemoryGovernedIntentRepository intents;

  setUp(() {
    subTracks = InMemorySubTrackRepository();
    intents = InMemoryGovernedIntentRepository();
  });

  ProviderContainer container({DateTime? now, bool scoped = true}) {
    final c = ProviderContainer(
      overrides: [
        activeLearnerScopeProvider.overrideWith(
          (ref) async => scoped ? c0Scope() : null,
        ),
        subTrackRepositoryProvider.overrideWith((ref) async => subTracks),
        governedIntentRepositoryProvider.overrideWith((ref) async => intents),
        localDayClockProvider.overrideWithValue(
          FakeLocalDayClock(now ?? DateTime.utc(2026, 9, 7, 12)),
        ),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<OngoingSubTrackContext?> read(ProviderContainer c) async {
    final sub = c.listen(
      ongoingSubTrackContextProvider(_curriculum),
      (_, __) {},
    );
    addTearDown(sub.close);
    return c.read(ongoingSubTrackContextProvider(_curriculum).future);
  }

  group('ongoingSubTrackContextProvider', () {
    test('today is the civil date in the profile time zone, not UTC', () async {
      intents.emit(c0Scope(), _intent(timeZone: 'Asia/Jerusalem'));
      subTracks.seed(c0Scope(), const []);
      // 22:30 UTC on 6 Sep is already 7 Sep in Jerusalem.
      final c = container(now: DateTime.utc(2026, 9, 6, 22, 30));
      final data = await read(c);
      expect(data!.today, '2026-09-07');
    });

    test('lists this curriculum only and counts per AD-45', () async {
      intents.emit(c0Scope(), _intent());
      subTracks.seed(c0Scope(), [
        _track(1),
        _track(2, start: '2026-12-01'),
        _track(3, ended: true),
        _track(4, end: '2026-09-01'),
        _track(5, curriculumId: 'chumash'),
      ]);
      final data = await read(container());
      expect(data!.calendarProgram, isFalse);
      expect(data.subTracks.map((s) => s.id), [
        _ulid(1),
        _ulid(2),
        _ulid(3),
        _ulid(4),
      ]);
      expect(data.liveSubTracks.map((s) => s.id), [
        _ulid(1),
        _ulid(2),
        _ulid(4),
      ]);
      expect(data.ongoingInUse(), 2);
      expect(data.ongoingInUse(excludingId: _ulid(2)), 1);
    });

    test('a live calendar program is detected', () async {
      intents.emit(c0Scope(), _intent(programId: 'daf_yomi'));
      subTracks.seed(c0Scope(), const []);
      expect((await read(container()))!.calendarProgram, isTrue);
    });

    test('unreadable rows fail closed', () async {
      intents.emit(c0Scope(), _intent());
      subTracks
        ..seed(c0Scope(), [_track(1)])
        ..seedRejected(c0Scope(), [RejectedRow(_ulid(9), 'bad row')]);
      final c = container();
      await expectLater(
        read(c),
        throwsA(isA<SubTrackRowsUnreadableException>()),
      );
    });

    test('re-reads at the learner midnight in the profile zone', () async {
      intents.emit(c0Scope(), _intent(timeZone: 'Asia/Jerusalem'));
      // The limit reads on the old day: track 2's window ends on 7 Sep.
      subTracks.seed(c0Scope(), [_track(1), _track(2, end: '2026-09-07')]);
      // 20:59:59.95 UTC on 7 Sep is 50ms before midnight in Jerusalem
      // (UTC+3 in September).
      final clock = FakeLocalDayClock(
        DateTime.utc(2026, 9, 7, 20, 59, 59, 950),
      );
      final c = ProviderContainer(
        overrides: [
          activeLearnerScopeProvider.overrideWith((ref) async => c0Scope()),
          subTrackRepositoryProvider.overrideWith((ref) async => subTracks),
          governedIntentRepositoryProvider.overrideWith((ref) async => intents),
          localDayClockProvider.overrideWithValue(clock),
        ],
      );
      addTearDown(c.dispose);
      final before = await read(c);
      expect(before!.today, '2026-09-07');
      expect(before.timeZone, 'Asia/Jerusalem');
      expect(before.ongoingInUse(), 2);
      clock.advance(const Duration(milliseconds: 60));
      await Future<void>.delayed(const Duration(milliseconds: 200));
      final after = await c.read(
        ongoingSubTrackContextProvider(_curriculum).future,
      );
      expect(after!.today, '2026-09-08');
      expect(after.ongoingInUse(), 1);
    });

    test('null while no learner is active', () async {
      expect(await read(container(scoped: false)), isNull);
    });

    test('recomputes when a sub-track is written', () async {
      intents.emit(c0Scope(), _intent());
      subTracks.seed(c0Scope(), [_track(1)]);
      final c = container();
      expect((await read(c))!.ongoingInUse(), 1);
      subTracks.seed(c0Scope(), [_track(2)]);
      await Future<void>.delayed(Duration.zero);
      final again = await c.read(
        ongoingSubTrackContextProvider(_curriculum).future,
      );
      expect(again!.ongoingInUse(), 2);
    });
  });

  group('learner civil day helpers', () {
    test('todayAt and atDay re-judge a read on a later instant', () {
      final read = OngoingSubTrackContext(
        scope: c0Scope(),
        curriculumId: _curriculum,
        today: '2026-09-07',
        timeZone: 'Asia/Jerusalem',
        subTracks: [
          _track(1),
          _track(2, end: '2026-09-07'),
        ],
        calendarProgram: false,
      );
      expect(read.todayAt(DateTime.utc(2026, 9, 7, 20, 59)), '2026-09-07');
      final later = read.todayAt(DateTime.utc(2026, 9, 7, 21, 1));
      expect(later, '2026-09-08');
      expect(identical(read.atDay('2026-09-07'), read), isTrue);
      final next = read.atDay(later);
      expect(next.today, '2026-09-08');
      expect(next.timeZone, 'Asia/Jerusalem');
      expect(next.subTracks, read.subTracks);
      expect(read.ongoingInUse(), 2);
      expect(next.ongoingInUse(), 1);
    });

    test('untilNextLearnerDay waits for the zone midnight, DST-aware', () {
      expect(
        untilNextLearnerDay('UTC', DateTime.utc(2026, 9, 7, 23)),
        const Duration(hours: 1, microseconds: 1),
      );
      // Jerusalem leaves summer time on 25 Oct 2026: that civil day is
      // 25 hours long, and midnight is 22:00 UTC after it.
      expect(
        untilNextLearnerDay('Asia/Jerusalem', DateTime.utc(2026, 10, 24, 21)),
        const Duration(hours: 25, microseconds: 1),
      );
    });
  });

  group('ongoingSubTrackParentSessionProvider', () {
    LearnerProfileEntity profile(ProfileMode mode) => LearnerProfileEntity(
      profileId: profileUlid,
      displayName: 'Yehuda',
      mode: mode,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );

    Future<bool> session({
      required ProfileMode mode,
      String? pinFor,
      bool tutored = false,
    }) async {
      final c = ProviderContainer(
        overrides: [
          activeProfileProvider.overrideWith((ref) async => profile(mode)),
          parentPinAuthenticatedProfileIdProvider.overrideWith(
            () => _Pin(pinFor),
          ),
          activeTutoredProfileSelectionProvider.overrideWith(
            () => _Tutored(tutored),
          ),
        ],
      );
      addTearDown(c.dispose);
      final sub = c.listen(ongoingSubTrackParentSessionProvider, (_, __) {});
      addTearDown(sub.close);
      return c.read(ongoingSubTrackParentSessionProvider.future);
    }

    test('an adult learner is the parent', () async {
      expect(await session(mode: ProfileMode.adult), isTrue);
    });

    test('a child without the parent PIN session is refused', () async {
      expect(await session(mode: ProfileMode.child), isFalse);
      expect(
        await session(mode: ProfileMode.child, pinFor: 'another-profile'),
        isFalse,
      );
    });

    test(
      'a child with this profile\'s parent PIN session is allowed',
      () async {
        expect(
          await session(mode: ProfileMode.child, pinFor: profileUlid),
          isTrue,
        );
      },
    );

    test('a tutored session is refused (Epic 4)', () async {
      expect(await session(mode: ProfileMode.adult, tutored: true), isFalse);
    });
  });

  group('ongoingSubTrackWriteScopeProvider', () {
    LearnerProfileEntity profile(ProfileMode mode, {String? id}) =>
        LearnerProfileEntity(
          profileId: id ?? profileUlid,
          displayName: 'Yehuda',
          mode: mode,
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
        );

    Future<Object?> grant({
      required ProfileMode mode,
      String? profileId,
      String? pinFor,
      bool scoped = true,
    }) async {
      final c = ProviderContainer(
        overrides: [
          activeProfileProvider.overrideWith(
            (ref) async => profile(mode, id: profileId),
          ),
          parentPinAuthenticatedProfileIdProvider.overrideWith(
            () => _Pin(pinFor),
          ),
          activeTutoredProfileSelectionProvider.overrideWith(
            () => _Tutored(false),
          ),
          activeLearnerScopeProvider.overrideWith(
            (ref) async => scoped ? c0Scope() : null,
          ),
        ],
      );
      addTearDown(c.dispose);
      final sub = c.listen(ongoingSubTrackWriteScopeProvider, (_, __) {});
      addTearDown(sub.close);
      return c.read(ongoingSubTrackWriteScopeProvider.future);
    }

    test('an adult learner is granted its own scope', () async {
      expect(await grant(mode: ProfileMode.adult), c0Scope());
    });

    test('a child is granted only with its parent PIN session', () async {
      expect(await grant(mode: ProfileMode.child), isNull);
      expect(
        await grant(mode: ProfileMode.child, pinFor: profileUlid),
        c0Scope(),
      );
    });

    test('no learner scope grants nothing', () async {
      expect(await grant(mode: ProfileMode.adult, scoped: false), isNull);
    });

    test(
      'a profile and scope that disagree mid-switch grant nothing',
      () async {
        expect(
          await grant(
            mode: ProfileMode.adult,
            profileId: '01ARZ3NDEKTSV4RRFFQ69G5FB2',
          ),
          isNull,
        );
      },
    );
  });
}

class _Pin extends ParentPinAuthenticatedProfileId {
  _Pin(this._id);

  final String? _id;

  @override
  String? build() => _id;
}

class _Tutored extends ActiveTutoredProfileSelection {
  _Tutored(this._on);

  final bool _on;

  @override
  TutoredProfileSelection? build() => _on
      ? TutoredProfileSelection(
          profileId: profileUlid,
          ownerUid: 'owner-uid',
          grantId: 'grant',
          permissions: TutorPermissions.defaults(),
        )
      : null;
}
