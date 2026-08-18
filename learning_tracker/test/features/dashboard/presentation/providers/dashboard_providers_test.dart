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
import 'package:learning_tracker/data/firestore/repository_providers.dart'
    show activeProfileDocIdProvider;
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/gamification/presentation/providers/gamification_service_providers.dart'
    show rewardMilestoneServiceProvider, streakStateProvider;
import 'package:learning_tracker/features/gamification/streak/streak_event_entry.dart';
import 'package:learning_tracker/features/gamification/streak/streak_state_service.dart';
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

class _MockFirebaseApp extends Mock implements FirebaseApp {}

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

const _uid = 'dashboard-providers-test';
const _adultProfileId = '01J6Q2H4A8M7K3P9R5T6V8WXYA';
const _childProfileId = '01J6Q2H4A8M7K3P9R5T6V8WXYB';
const _streakEventId = '01J6Q2H4A8M7K3P9R5T6V8WXYZ';

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

Future<void> _seedStreakEvent(
  FakeFirebaseFirestore firestore, {
  required String profileId,
  required DateTime day,
}) async {
  final event = StreakEventEntry(
    ulid: _streakEventId,
    eventType: 'completion',
    dayUtc: DateTime.utc(day.year, day.month, day.day),
    eventTimestamp: day.toUtc(),
  );
  await firestore
      .collection('users')
      .doc(_uid)
      .collection('learner_profiles')
      .doc(profileId)
      .collection('streak_events')
      .doc(_streakEventId)
      .set(event.toFirestore());
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

  group('dashboardLastCompletionProvider', () {
    test('returns null when no completions exist', () async {
      final container = _container(firestore);
      addTearDown(container.dispose);

      expect(
        await container.read(
          dashboardLastCompletionProvider(CurriculumId.mishnayos).future,
        ),
        isNull,
      );
    });

    test('returns the latest completion for its curriculum', () async {
      final first = DateTime.utc(2026, 1, 1);
      final latest = DateTime.utc(2026, 1, 3);
      await seedCompletion(
        firestore,
        uid: _uid,
        profileId: _adultProfileId,
        curriculumId: CurriculumId.mishnayos,
        sefariaRef: 'Mishnah 1',
        completedAt: first,
      );
      await seedCompletion(
        firestore,
        uid: _uid,
        profileId: _adultProfileId,
        curriculumId: CurriculumId.mishnayos,
        sefariaRef: 'Mishnah 2',
        completedAt: latest,
      );
      await seedCompletion(
        firestore,
        uid: _uid,
        profileId: _adultProfileId,
        curriculumId: CurriculumId.bavli,
        sefariaRef: 'Chullin 25a',
        completedAt: DateTime.utc(2026, 1, 5),
      );
      final container = _container(firestore);
      addTearDown(container.dispose);

      expect(
        await container.read(
          dashboardLastCompletionProvider(CurriculumId.mishnayos).future,
        ),
        latest,
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

  group('dashboardStreakProvider', () {
    test('emits zero streak when no streak events exist', () async {
      final container = _container(
        firestore,
        extraOverrides: [
          streakStateProvider.overrideWith(
            (ref) => StreakStateService(
              ref: ref,
              clock: FakeLocalDayClock(DateTime.utc(2026, 5, 20, 12)),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final sub = container.listen(dashboardStreakProvider, (_, __) {});
      addTearDown(sub.close);
      final value = await container.read(dashboardStreakProvider.future);

      expect(value.currentStreak, 0);
      expect(value.maxStreak, 0);
    });

    test('emits streak >= 1 after a streak event for today', () async {
      final fixedToday = DateTime.utc(2026, 5, 20, 12);
      await _seedStreakEvent(
        firestore,
        profileId: _adultProfileId,
        day: fixedToday,
      );
      final container = _container(
        firestore,
        extraOverrides: [
          streakStateProvider.overrideWith(
            (ref) => StreakStateService(
              ref: ref,
              clock: FakeLocalDayClock(fixedToday),
              dayOf: (dt) => DateTime.utc(
                dt.toUtc().year,
                dt.toUtc().month,
                dt.toUtc().day,
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final sub = container.listen(dashboardStreakProvider, (_, __) {});
      addTearDown(sub.close);
      final value = await container.read(dashboardStreakProvider.future);

      expect(value.currentStreak, greaterThanOrEqualTo(1));
    });

    test('emits non-negative currentStreak and maxStreak', () async {
      final container = _container(
        firestore,
        extraOverrides: [
          streakStateProvider.overrideWith(
            (ref) => StreakStateService(
              ref: ref,
              clock: FakeLocalDayClock(DateTime.utc(2026, 5, 20, 12)),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final sub = container.listen(dashboardStreakProvider, (_, __) {});
      addTearDown(sub.close);
      final value = await container.read(dashboardStreakProvider.future);

      expect(value.currentStreak, greaterThanOrEqualTo(0));
      expect(value.maxStreak, greaterThanOrEqualTo(0));
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
      final enrollment = ProfileProgramEntity(
        curriculumId: CurriculumId.mishnayos,
        programId: 1,
        updatedAt: DateTime.utc(2026, 1, 1),
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

    test(
      'dashboardPaceStatus: container disposed mid-goals-read — no crash',
      () async {
        await seedGoal(
          firestore,
          uid: _uid,
          profileId: _adultProfileId,
          curriculumId: CurriculumId.mishnayos,
          targetDate: DateTime.utc(2026, 6, 1),
          createdAt: DateTime.utc(2026, 1, 1),
        );
        final container = _container(firestore);
        final capturedRef = _captureRef(container);
        final resultFuture = dashboardPaceStatus(
          capturedRef,
          CurriculumId.mishnayos,
        );

        container.dispose();
        expect(capturedRef.mounted, isFalse);
        await expectLater(resultFuture, completes);
      },
    );
  });

  group('dashboardPaceStatusProvider', () {
    test('returns null when no Firestore goal exists', () async {
      final container = _container(firestore);
      addTearDown(container.dispose);

      expect(
        await container.read(
          dashboardPaceStatusProvider(CurriculumId.mishnayos).future,
        ),
        isNull,
      );
    });
  });
}
