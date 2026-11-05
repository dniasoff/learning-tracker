/// Firestore-backed provider coverage for the dashboard.
///
/// These tests deliberately use the same fake Firestore and ULID profile
/// identity that production repositories use. The archived Drift database is
/// not part of the dashboard architecture anymore.
library;

// ignore_for_file: depend_on_referenced_packages
// setupFirebaseCoreMocks lives in firebase_core_platform_interface/test.dart,
// which is not re-exported by any direct dependency. It is test-only
// infrastructure; using the transitive package directly is the standard
// pattern for platform-interface test seams (see
// test/features/tutoring/data/repositories/firestore_tutor_grant_repository_test.dart).

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/time/local_day_clock.dart';
import 'package:learning_tracker/data/firestore/account_firebase.dart';
import 'package:learning_tracker/data/firestore/active_account_providers.dart';
import 'package:learning_tracker/data/firestore/learner_state_repository_providers.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart'
    show activeProfileDocIdProvider;
import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/ports/governed_intent_repository.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/gamification/data/repositories/engine_points_reader.dart';
import 'package:learning_tracker/features/gamification/presentation/providers/gamification_service_providers.dart'
    show rewardMilestoneServiceProvider;
import 'package:learning_tracker/features/learner_state/presentation/providers/learner_state_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/settings/presentation/providers/curriculum_scope_providers.dart';
import 'package:learning_tracker/features/tracks/setup/domain/entities/profile_program.dart';
import 'package:learning_tracker/features/tracks/stages/domain/models/schedule_type.dart';
import 'package:learning_tracker/features/tracks/stages/domain/models/stage_definition.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/firestore_fake.dart';
import '../../../../helpers/firestore_fixtures.dart';
import '../../../../helpers/learner_state/c0_fixtures.dart';
import '../../../../helpers/learner_state/engine_fixtures.dart';
import '../../../../helpers/learner_state/fake_learner_state.dart';
import '../../../../helpers/learner_state/in_memory_ports.dart';
import '../../../../helpers/learner_state/learner_state_overrides.dart';

class _MockFirebaseApp extends Mock implements FirebaseApp {}

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

const _uid = 'dashboard-providers-test';
const _adultProfileId = '01J6Q2H4A8M7K3P9R5T6V8WXYA';
const _childProfileId = '01J6Q2H4A8M7K3P9R5T6V8WXYB';

AccountFirebaseHandles _handles(FakeFirebaseFirestore firestore) {
  return AccountFirebaseHandles(
    app: _MockFirebaseApp(),
    firestore: firestore,
    auth: _MockFirebaseAuth(),
    uid: _uid,
  );
}

class _FixedActiveProfileId extends ActiveProfileId {
  _FixedActiveProfileId(this._id);
  final String _id;

  @override
  String build() => _id;
}

Future<void> _seedBase(
  FakeFirebaseFirestore firestore, {
  ProfileMode adultMode = ProfileMode.adult,
}) async {
  await seedAccount(firestore, uid: _uid);
  await seedProfile(
    firestore,
    uid: _uid,
    profileId: _adultProfileId,
    mode: adultMode,
  );
}

ProviderContainer _container(
  FakeFirebaseFirestore firestore, {
  String profileId = _adultProfileId,
  List<Override> extraOverrides = const [],
}) {
  final container = ProviderContainer(
    retry: (_, __) => null,
    overrides: [
      activeAccountFirebaseProvider.overrideWith(
        (ref) async => _handles(firestore),
      ),
      // No learning events: the AD-50 earning set is empty (DNI-480).
      activeEarningEventIdsProvider.overrideWith((ref) async => const {}),
      for (final curriculum in CurriculumId.values)
        scopedItemCountProvider(
          curriculum,
        ).overrideWith((ref) => Future.value(0)),
      ...extraOverrides,
    ],
  );
  container.read(selectedProfileIdProvider.notifier).select(profileId);
  return container;
}

Future<void> _seedStages(
  FakeFirebaseFirestore firestore, {
  required String profileId,
  required CurriculumId curriculumId,
  required int count,
}) async {
  await seedStageDefinitions(
    firestore,
    uid: _uid,
    profileId: profileId,
    curriculumId: curriculumId,
    stages: [
      for (var order = 1; order <= count; order++)
        StageDefinition(
          curriculumId: curriculumId,
          stageOrder: order,
          stageName: order == 1 ? 'Learn' : 'Chazara $order',
          delayDays: order == 1 ? 0 : order,
          isDefault: false,
          scheduleType: ScheduleType.delay,
        ),
    ],
  );
}

Ref _captureRef(ProviderContainer container) {
  late Ref capturedRef;
  final hostProvider = Provider<void>((ref) {
    capturedRef = ref;
  });
  container.read(hostProvider);
  return capturedRef;
}

void main() {
  late FakeFirebaseFirestore firestore;

  setUpAll(() async {
    // FirestoreCurriculumTrackRepositoryAdapter's constructor (used by
    // dashboardActiveCurricula, dashboardActiveCurriculaStream, and
    // anyActiveTrackHasChazaraProvider) falls back to FirebaseFunctions
    // .instance when no functions override is supplied, which requires a
    // registered default Firebase app — this test's other Firebase surfaces
    // (_MockFirebaseApp, _MockFirebaseAuth, FakeFirebaseFirestore) are all
    // mocked, but never register one. None of the providers under test here
    // actually invoke a callable, so registering a Core app is enough; no
    // FirebaseFunctionsPlatform fake is needed (contrast
    // firestore_tutor_grant_repository_test.dart, which does call callables).
    TestWidgetsFlutterBinding.ensureInitialized();
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  setUp(() async {
    firestore = createFakeFirestore(authenticatedUid: _uid);
    await _seedBase(firestore);
  });

  group('dashboardUserModeProvider', () {
    test('returns adult for an adult profile', () async {
      final container = _container(firestore);
      addTearDown(container.dispose);

      final mode = await container.read(dashboardUserModeProvider.future);
      expect(mode, ProfileMode.adult);
    });

    test('returns child for the active child profile', () async {
      await seedProfile(
        firestore,
        uid: _uid,
        profileId: _childProfileId,
        displayName: 'Child',
        mode: ProfileMode.child,
      );
      final container = _container(firestore, profileId: _childProfileId);
      addTearDown(container.dispose);

      final mode = await container.read(dashboardUserModeProvider.future);
      expect(mode, ProfileMode.child);
    });

    test('defaults to adult when no profile document matches', () async {
      final container = _container(
        firestore,
        profileId: '01J6Q2H4A8M7K3P9R5T6V8WXYC',
      );
      addTearDown(container.dispose);

      final mode = await container.read(dashboardUserModeProvider.future);
      expect(mode, ProfileMode.adult);
    });

    test('tutor-active child identity follows the active profile', () async {
      await seedProfile(
        firestore,
        uid: _uid,
        profileId: _childProfileId,
        displayName: 'Child',
        mode: ProfileMode.child,
      );
      final container = ProviderContainer(
        overrides: [
          activeAccountFirebaseProvider.overrideWith(
            (ref) async => _handles(firestore),
          ),
          activeProfileIdProvider.overrideWith(
            () => _FixedActiveProfileId(_childProfileId),
          ),
        ],
      );
      addTearDown(container.dispose);
      container.read(activeProfileDocIdProvider.notifier).set(_childProfileId);

      final mode = await container.read(dashboardUserModeProvider.future);
      expect(mode, ProfileMode.child);
    });
  });

  group('dashboardActiveCurriculaProvider', () {
    test('returns empty when no tracks exist', () async {
      final container = _container(firestore);
      addTearDown(container.dispose);

      // Keep a listener so the autoDispose provider is not torn down mid-load
      // — reading `.future` without one races Riverpod's autoDispose
      // scheduler, which can dispose the provider while its async chain
      // (account -> profile -> Firestore track repo) is still in flight,
      // surfacing as "disposed during loading state" (see the analogous
      // container.listen(dashboardStreakProvider, ...) calls below).
      final sub = container.listen(
        dashboardActiveCurriculaProvider,
        (_, __) {},
      );
      addTearDown(sub.close);

      expect(
        await container.read(dashboardActiveCurriculaProvider.future),
        isEmpty,
      );
    });

    test('returns active curricula and skips retired tracks', () async {
      await seedTrack(
        firestore,
        uid: _uid,
        profileId: _adultProfileId,
        curriculumId: CurriculumId.mishnayos,
      );
      await seedTrack(
        firestore,
        uid: _uid,
        profileId: _adultProfileId,
        curriculumId: CurriculumId.bavli,
        state: 'retired',
      );
      final container = _container(firestore);
      addTearDown(container.dispose);

      final sub = container.listen(
        dashboardActiveCurriculaProvider,
        (_, __) {},
      );
      addTearDown(sub.close);

      expect(await container.read(dashboardActiveCurriculaProvider.future), [
        CurriculumId.mishnayos,
      ]);
    });

    test('returns multiple active curricula in Firestore order', () async {
      await seedTrack(
        firestore,
        uid: _uid,
        profileId: _adultProfileId,
        curriculumId: CurriculumId.mishnayos,
      );
      await seedTrack(
        firestore,
        uid: _uid,
        profileId: _adultProfileId,
        curriculumId: CurriculumId.bavli,
      );
      final container = _container(firestore);
      addTearDown(container.dispose);

      final sub = container.listen(
        dashboardActiveCurriculaProvider,
        (_, __) {},
      );
      addTearDown(sub.close);

      expect(
        await container.read(dashboardActiveCurriculaProvider.future),
        containsAll(<CurriculumId>[CurriculumId.mishnayos, CurriculumId.bavli]),
      );
    });
  });

  group('dashboardActiveCurriculaStreamProvider', () {
    test('emits empty when no active tracks exist', () async {
      final container = _container(firestore);
      addTearDown(container.dispose);

      // Keep a listener so the autoDispose provider is not torn down mid-load
      // — see the identical guard on dashboardActiveCurriculaProvider above.
      final sub = container.listen(
        dashboardActiveCurriculaStreamProvider,
        (_, __) {},
      );
      addTearDown(sub.close);

      expect(
        await container.read(dashboardActiveCurriculaStreamProvider.future),
        isEmpty,
      );
    });

    test('emits the active curriculum when a track exists', () async {
      await seedTrack(
        firestore,
        uid: _uid,
        profileId: _adultProfileId,
        curriculumId: CurriculumId.mishnayos,
      );
      final container = _container(firestore);
      addTearDown(container.dispose);

      final sub = container.listen(
        dashboardActiveCurriculaStreamProvider,
        (_, __) {},
      );
      addTearDown(sub.close);

      expect(
        await container.read(dashboardActiveCurriculaStreamProvider.future),
        [CurriculumId.mishnayos],
      );
    });
  });

  group('dashboardActiveTracksStreamProvider', () {
    test('emits empty when no tracks exist', () async {
      final container = _container(firestore);
      addTearDown(container.dispose);

      // Keep a listener so the autoDispose provider is not torn down mid-load
      // — see the identical guard on dashboardActiveCurriculaProvider above.
      final sub = container.listen(
        dashboardActiveTracksStreamProvider,
        (_, __) {},
      );
      addTearDown(sub.close);

      expect(
        await container.read(dashboardActiveTracksStreamProvider.future),
        isEmpty,
      );
    });

    test('emits only active Firestore tracks', () async {
      await seedTrack(
        firestore,
        uid: _uid,
        profileId: _adultProfileId,
        curriculumId: CurriculumId.mishnayos,
      );
      await seedTrack(
        firestore,
        uid: _uid,
        profileId: _adultProfileId,
        curriculumId: CurriculumId.bavli,
        state: 'archived',
      );
      final container = _container(firestore);
      addTearDown(container.dispose);

      final sub = container.listen(
        dashboardActiveTracksStreamProvider,
        (_, __) {},
      );
      addTearDown(sub.close);

      final tracks = await container.read(
        dashboardActiveTracksStreamProvider.future,
      );
      expect(tracks, hasLength(1));
      expect(tracks.single.curriculumId, CurriculumId.mishnayos);
    });
  });

  group('trackHasChazaraProvider and anyActiveTrackHasChazaraProvider', () {
    test('returns false for a single-stage track', () async {
      await seedTrack(
        firestore,
        uid: _uid,
        profileId: _adultProfileId,
        curriculumId: CurriculumId.mishnayos,
      );
      await _seedStages(
        firestore,
        profileId: _adultProfileId,
        curriculumId: CurriculumId.mishnayos,
        count: 1,
      );
      final container = _container(firestore);
      addTearDown(container.dispose);

      // Keep a listener on each autoDispose provider under test so it is
      // not torn down mid-load — see the identical guard on
      // dashboardActiveCurriculaProvider above.
      final trackSub = container.listen(
        trackHasChazaraProvider(CurriculumId.mishnayos),
        (_, __) {},
      );
      addTearDown(trackSub.close);
      final anySub = container.listen(
        anyActiveTrackHasChazaraProvider,
        (_, __) {},
      );
      addTearDown(anySub.close);

      expect(
        await container.read(
          trackHasChazaraProvider(CurriculumId.mishnayos).future,
        ),
        isFalse,
      );
      expect(
        await container.read(anyActiveTrackHasChazaraProvider.future),
        isFalse,
      );
    });

    test('returns true for an active track with multiple stages', () async {
      await seedTrack(
        firestore,
        uid: _uid,
        profileId: _adultProfileId,
        curriculumId: CurriculumId.mishnayos,
      );
      await _seedStages(
        firestore,
        profileId: _adultProfileId,
        curriculumId: CurriculumId.mishnayos,
        count: 2,
      );
      final container = _container(firestore);
      addTearDown(container.dispose);

      final trackSub = container.listen(
        trackHasChazaraProvider(CurriculumId.mishnayos),
        (_, __) {},
      );
      addTearDown(trackSub.close);
      final anySub = container.listen(
        anyActiveTrackHasChazaraProvider,
        (_, __) {},
      );
      addTearDown(anySub.close);

      expect(
        await container.read(
          trackHasChazaraProvider(CurriculumId.mishnayos).future,
        ),
        isTrue,
      );
      expect(
        await container.read(anyActiveTrackHasChazaraProvider.future),
        isTrue,
      );
    });

    test('ignores retired tracks when determining chazara', () async {
      await seedTrack(
        firestore,
        uid: _uid,
        profileId: _adultProfileId,
        curriculumId: CurriculumId.mishnayos,
        state: 'retired',
      );
      await _seedStages(
        firestore,
        profileId: _adultProfileId,
        curriculumId: CurriculumId.mishnayos,
        count: 2,
      );
      final container = _container(firestore);
      addTearDown(container.dispose);

      final anySub = container.listen(
        anyActiveTrackHasChazaraProvider,
        (_, __) {},
      );
      addTearDown(anySub.close);

      expect(
        await container.read(anyActiveTrackHasChazaraProvider.future),
        isFalse,
      );
    });
  });

  group('dashboardGlobalPointsProvider product rules', () {
    test('adult profiles always have zero points', () async {
      final container = _container(firestore);
      addTearDown(container.dispose);

      expect(await container.read(dashboardGlobalPointsProvider.future), 0);
    });

    test('child profiles with no balance fall back to zero', () async {
      await seedProfile(
        firestore,
        uid: _uid,
        profileId: _childProfileId,
        displayName: 'Child',
        mode: ProfileMode.child,
      );
      final container = _container(firestore, profileId: _childProfileId);
      addTearDown(container.dispose);

      expect(await container.read(dashboardGlobalPointsProvider.future), 0);
    });
  });

  group('dashboardStreakProvider (DNI-479: the curriculum in view)', () {
    // AD-40: LearnerState has no profile-wide streak; each curriculum has
    // its own. Mishnayos and Bavli are both active tracks here.
    final state = fakeLearnerState(
      curricula: {
        CurriculumId.mishnayos.storageKey: FakeCurriculumState(
          curriculumId: CurriculumId.mishnayos.storageKey,
          streak: const CurriculumStreak(current: 4, best: 9),
        ),
        CurriculumId.bavli.storageKey: FakeCurriculumState(
          curriculumId: CurriculumId.bavli.storageKey,
          streak: const CurriculumStreak(current: 1, best: 2),
        ),
      },
    );

    Future<ProviderContainer> streakContainer({LearnerState? learner}) async {
      for (final c in [CurriculumId.mishnayos, CurriculumId.bavli]) {
        await seedTrack(
          firestore,
          uid: _uid,
          profileId: _adultProfileId,
          curriculumId: c,
        );
      }
      final container = _container(
        firestore,
        extraOverrides: learnerStateOverrides(
          scope: c0Scope(),
          state: learner ?? state,
        ),
      );
      addTearDown(container.dispose);
      final sub = container.listen(dashboardStreakProvider, (_, __) {});
      addTearDown(sub.close);
      final inView = container.listen(
        dashboardStreakCurriculumProvider,
        (_, __) {},
      );
      addTearDown(inView.close);
      return container;
    }

    test('shows the first active track until one is put in view', () async {
      final container = await streakContainer();
      final first = await container.read(
        dashboardStreakCurriculumProvider.future,
      );
      final value = await container.read(dashboardStreakProvider.future);
      final expected = first == CurriculumId.mishnayos ? (4, 9) : (1, 2);
      expect((value.currentStreak, value.maxStreak), expected);
    });

    test('switching the curriculum in view switches the streak', () async {
      final container = await streakContainer();
      await container.read(dashboardStreakProvider.future);

      container
          .read(dashboardCurriculumInViewProvider.notifier)
          .show(CurriculumId.bavli);
      var value = await container.read(dashboardStreakProvider.future);
      expect(value.currentStreak, 1);
      expect(value.maxStreak, 2);

      container
          .read(dashboardCurriculumInViewProvider.notifier)
          .show(CurriculumId.mishnayos);
      value = await container.read(dashboardStreakProvider.future);
      expect(value.currentStreak, 4);
      expect(value.maxStreak, 9);
    });

    test('a curriculum in view that is no longer active falls back', () async {
      final container = await streakContainer();
      container
          .read(dashboardCurriculumInViewProvider.notifier)
          .show(CurriculumId.tanach);
      expect(
        await container.read(dashboardStreakCurriculumProvider.future),
        isNot(CurriculumId.tanach),
      );
    });

    test('a curriculum the engine did not evaluate shows zero', () async {
      final container = await streakContainer(learner: fakeLearnerState());
      final value = await container.read(dashboardStreakProvider.future);
      expect(value.currentStreak, 0);
      expect(value.maxStreak, 0);
    });

    test('a learner-state error is an error, never a zero streak', () async {
      for (final c in [CurriculumId.mishnayos]) {
        await seedTrack(
          firestore,
          uid: _uid,
          profileId: _adultProfileId,
          curriculumId: c,
        );
      }
      final container = _container(
        firestore,
        extraOverrides: [
          ...learnerStateOverrides(scope: c0Scope()),
          learnerStateProvider.overrideWith(
            (ref, _) => Stream.error(StateError('engine failed')),
          ),
        ],
      );
      addTearDown(container.dispose);
      final sub = container.listen(dashboardStreakProvider, (_, __) {});
      addTearDown(sub.close);
      await expectLater(
        container.read(dashboardStreakProvider.future),
        throwsA(isA<StateError>()),
      );
    });

    test('curriculumInView prefers the selection while it is active', () {
      const active = [CurriculumId.mishnayos, CurriculumId.bavli];
      expect(curriculumInView(null, active), CurriculumId.mishnayos);
      expect(curriculumInView(CurriculumId.bavli, active), CurriculumId.bavli);
      expect(
        curriculumInView(CurriculumId.tanach, active),
        CurriculumId.mishnayos,
      );
      expect(curriculumInView(CurriculumId.bavli, const []), isNull);
    });
  });

  group('dashboardStreakProvider through the real engine (DNI-479 AC-1)', () {
    // The dashboard streak is the engine's derivation over the whole event
    // log: a voided event cannot keep a streak, and nothing caps the history
    // at a page (the retired streak_events read stopped at 500 rows).
    // Tue 2026-09-01 .. Thu 09-03 are ordinary weekdays; the zone is UTC.
    late InMemoryLearningEventRepository events;
    late InMemorySubTrackRepository subTracks;
    late InMemoryChangeLogRepository changeLog;
    late InMemoryGovernedIntentRepository intent;

    setUp(() {
      events = InMemoryLearningEventRepository();
      subTracks = InMemorySubTrackRepository();
      changeLog = InMemoryChangeLogRepository();
      intent = InMemoryGovernedIntentRepository();
    });
    tearDown(() async {
      await events.dispose();
      await subTracks.dispose();
      await changeLog.dispose();
      await intent.dispose();
    });

    const day = 24 * 60;
    // 520 main events on 09-01, then one on 09-02 and one on 09-03: the
    // days after the 500th event must still reach the streak.
    final history = [
      for (var i = 1; i <= 520; i++)
        engineLearn(i, 'Mishnah Berakhot 1:1', minutes: 600 + i),
      engineLearn(
        521,
        'Mishnah Berakhot 1:2',
        minutes: day + 600,
        learnedOn: '2026-09-02',
      ),
      engineLearn(
        522,
        'Mishnah Berakhot 1:3',
        minutes: 2 * day + 600,
        learnedOn: '2026-09-03',
      ),
    ];

    Future<({int currentStreak, int maxStreak})> streakOf(
      List<LearningEvent> log,
    ) async {
      await seedTrack(
        firestore,
        uid: _uid,
        profileId: _adultProfileId,
        curriculumId: CurriculumId.mishnayos,
      );
      events.seed(c0Scope(), log);
      subTracks.seed(c0Scope(), const []);
      changeLog.seed(c0Scope(), const []);
      final container = _container(
        firestore,
        extraOverrides: [
          ...learnerStateOverrides(scope: c0Scope()),
          learningEventRepositoryProvider.overrideWith((ref) async => events),
          subTrackRepositoryProvider.overrideWith((ref) async => subTracks),
          changeLogRepositoryProvider.overrideWith((ref) async => changeLog),
          governedIntentRepositoryProvider.overrideWith((ref) async => intent),
          corporaProvider.overrideWith(
            (ref) async => <String, Corpus>{
              engineCurriculum: mishnayosCorpus(),
            },
          ),
          learnerCalendarLoaderProvider.overrideWithValue(
            (intent, settings, now) async => const {},
          ),
          localDayClockProvider.overrideWithValue(
            FakeLocalDayClock(engineAt(2 * day + 720)),
          ),
          learnerStateDayTickProvider.overrideWithValue(const Stream.empty()),
        ],
      );
      addTearDown(container.dispose);
      final sub = container.listen(dashboardStreakProvider, (_, __) {});
      addTearDown(sub.close);
      intent.emit(
        c0Scope(),
        LearnerIntent(
          settings: c0Settings,
          mainTracks: {engineCurriculum: engineIntent()},
          goals: const {},
        ),
      );
      return container.read(dashboardStreakProvider.future);
    }

    test('a history past 500 events still reaches the streak', () async {
      final value = await streakOf(history);
      expect((value.currentStreak, value.maxStreak), (3, 3));
    });

    test('a voided event does not keep the streak', () async {
      final value = await streakOf([
        ...history,
        engineVoid(523, 521, minutes: day + 660),
      ]);
      expect((value.currentStreak, value.maxStreak), (1, 1));
    });
  });

  group('dashboardStreakRecoveryProvider', () {
    test('adult profiles receive the no-recovery fallback', () async {
      final container = _container(firestore);
      addTearDown(container.dispose);

      final info = await container.read(dashboardStreakRecoveryProvider.future);
      expect(info.wasRecovered, isFalse);
      expect(info.currentStreak, 0);
    });
  });

  group('dashboardHasProgramEnrollmentProvider', () {
    test('returns false when no enrollment exists', () async {
      final container = _container(firestore);
      addTearDown(container.dispose);

      expect(
        await container.read(
          dashboardHasProgramEnrollmentProvider(CurriculumId.mishnayos).future,
        ),
        isFalse,
      );
    });

    test('returns true when an enrollment is present', () async {
      const enrollment = ProfileProgramEntity(
        curriculumId: CurriculumId.mishnayos,
        programId: 1,
      );
      await firestore
          .collection('users')
          .doc(_uid)
          .collection('learner_profiles')
          .doc(_adultProfileId)
          .collection('profile_programs')
          .doc(CurriculumId.mishnayos.storageKey)
          .set(enrollment.toFirestore(profileId: _adultProfileId));

      final container = _container(firestore);
      addTearDown(container.dispose);

      expect(
        await container.read(
          dashboardHasProgramEnrollmentProvider(CurriculumId.mishnayos).future,
        ),
        isTrue,
      );
    });
  });

  group('dashboardChildNextReward — mounted-guard (R3-12)', () {
    test(
      'happy path: returns null for a child profile with no tracks/milestones',
      () async {
        SharedPreferences.setMockInitialValues({});
        await seedProfile(
          firestore,
          uid: _uid,
          profileId: _childProfileId,
          displayName: 'Child',
          mode: ProfileMode.child,
        );
        final container = _container(firestore, profileId: _childProfileId);
        addTearDown(container.dispose);

        await container.read(dashboardUserModeProvider.future);
        expect(
          await container.read(dashboardChildNextRewardProvider.future),
          isNull,
        );
      },
    );

    test(
      'returns null immediately for adult profile before the await gap',
      () async {
        final container = _container(firestore);
        addTearDown(container.dispose);

        expect(
          await container.read(dashboardChildNextRewardProvider.future),
          isNull,
        );
      },
    );

    test(
      'stripStockMilestonesEffect: container disposed mid-strip — no leak/crash',
      () async {
        SharedPreferences.setMockInitialValues({});
        final container = _container(firestore);
        final milestoneService = container.read(rewardMilestoneServiceProvider);
        for (final threshold in [50, 150, 300]) {
          await milestoneService.upsertMilestone(
            title: 'Stock $threshold',
            thresholdPoints: threshold,
            milestoneId: 'stock-$threshold',
          );
        }

        final capturedRef = _captureRef(container);
        final resultFuture = stripStockMilestonesEffect(capturedRef);

        container.dispose();
        expect(capturedRef.mounted, isFalse);
        await expectLater(resultFuture, completes);
      },
    );
  });
}
