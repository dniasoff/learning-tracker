// Story 3.5 (DNI-508 T2): the catch-up reminder provider graph — owner-only
// gating (AC-5), the default wiring, the resume counter (AC-7) and the sync
// effect's reconcile / no-op / failure-retry behaviour.


import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/features/profiles/profiles.dart';
import 'package:learning_tracker/features/sacred_time/data/repositories/learner_lock_settings_sources.dart';
import 'package:learning_tracker/features/sacred_time/data/repositories/shared_prefs_catch_up_reminder_ledger.dart';
import 'package:learning_tracker/features/sacred_time/data/services/catch_up_reminder_gateway_adapter.dart';
import 'package:learning_tracker/features/sacred_time/domain/services/catch_up_reminder_scheduler.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/account_lock_provider.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/catch_up_reminder_providers.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/learner_lock_settings_provider.dart';
import 'package:learning_tracker/features/tutoring/tutoring.dart';

import '../../../../helpers/catch_up_reminder_fakes.dart';
import '../../../../helpers/learner_state/catch_up_card_harness.dart';
import '../../../../helpers/learner_state/lock_fixtures.dart';

final _now = catchUpZone.at(DateTime.utc(2026, 10, 7), hour: 12);

LearnerProfileEntity _profile(String id, String name) => LearnerProfileEntity(
  profileId: id,
  displayName: name,
  mode: ProfileMode.child,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

class _NoResumes extends CatchUpReminderResumeCount {
  @override
  int build() => 0;
}

class _FailingNotifications extends FakeCatchUpNotifications {
  @override
  Future<void> schedule({
    required int id,
    required String profileId,
    required DateTime fireAtUtc,
    required String title,
    required String body,
  }) => throw StateError('os refused');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('defaults', () {
    test('owner device is true with no tutored session', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);

      expect(c.read(catchUpReminderOwnerDeviceProvider), isTrue);
    });

    test('owner device is false while a tutored session is active', () {
      final c = ProviderContainer(
        overrides: [
          activeTutoredProfileSelectionProvider.overrideWith(() => _Tutored()),
        ],
      );
      addTearDown(c.dispose);

      expect(c.read(catchUpReminderOwnerDeviceProvider), isFalse);
    });

    test('ledger, content reader and recheck interval are the real ones', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);

      expect(
        c.read(catchUpReminderLedgerProvider),
        isA<SharedPrefsCatchUpReminderLedger>(),
      );
      expect(c.read(catchUpReminderCardContentReaderProvider), isNotNull);
      expect(catchUpReminderRecheckInterval, const Duration(hours: 6));
    });

    test('the clock is UTC', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);

      expect(c.read(catchUpReminderClockProvider)().isUtc, isTrue);
    });

    test('the scheduler is built over the injected ports', () {
      final c = ProviderContainer(
        overrides: [
          catchUpReminderNotificationsProvider.overrideWithValue(
            FakeCatchUpNotifications(),
          ),
          catchUpReminderLedgerProvider.overrideWithValue(
            MemoryCatchUpLedger(),
          ),
        ],
      );
      addTearDown(c.dispose);

      expect(
        c.read(catchUpReminderSchedulerProvider),
        isA<CatchUpReminderScheduler>(),
      );
    });

    test('the gateway adapter is the default notification port', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);

      expect(
        c.read(catchUpReminderNotificationsProvider),
        isA<GatewayCatchUpReminderNotifications>(),
      );
    });
  });

  group('resume counter (AC-7)', () {
    void background(WidgetTester t) {
      for (final s in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
      ]) {
        t.binding.handleAppLifecycleStateChanged(s);
      }
    }

    void foreground(WidgetTester t) {
      for (final s in [
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        t.binding.handleAppLifecycleStateChanged(s);
      }
    }

    testWidgets('counts each app resume', (tester) async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      c.listen(catchUpReminderResumeCountProvider, (_, _) {});
      expect(c.read(catchUpReminderResumeCountProvider), 0);

      background(tester);
      foreground(tester);
      expect(c.read(catchUpReminderResumeCountProvider), 1);

      background(tester);
      foreground(tester);
      expect(c.read(catchUpReminderResumeCountProvider), 2);
    });
  });

  group('sync effect', () {
    late FakeCatchUpNotifications notifications;
    late MemoryCatchUpLedger ledger;
    late ProviderContainer container;

    setUp(() {
      notifications = FakeCatchUpNotifications();
      ledger = MemoryCatchUpLedger();
    });

    tearDown(() => container.dispose());

    Future<void> run({
      List<LearnerScope> owned = const [],
      List<LearnerProfileEntity> profiles = const [],
      FakeCatchUpNotifications? port,
    }) async {
      container = ProviderContainer(
        overrides: [
          lockDrivingScopesProvider.overrideWith((ref) => AsyncData(owned)),
          profileListStreamProvider.overrideWith(
            (ref) => Stream.value(profiles),
          ),
          activeLearnerScopeProvider.overrideWith((ref) async => catchUpScope),
          learnerLockSettingsProvider.overrideWith(
            (ref, scope) => Stream.value(constantHistory(lakewood)),
          ),
          catchUpReminderNotificationsProvider.overrideWithValue(
            port ?? notifications,
          ),
          catchUpReminderLedgerProvider.overrideWithValue(ledger),
          catchUpReminderClockProvider.overrideWithValue(() => _now),
          catchUpReminderCardContentReaderProvider.overrideWithValue(null),
          catchUpReminderResumeCountProvider.overrideWith(_NoResumes.new),
          currentAppLocaleProvider.overrideWithValue(const Locale('en')),
        ],
      );
      container.listen(catchUpReminderSyncEffectProvider, (_, _) {});
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(Duration.zero);
        try {
          await container.read(catchUpReminderSyncEffectProvider.future);
        } on Object {
          // a superseded run
        }
      }
    }

    testWidgets('schedules the owner profile with its display name', (
      tester,
    ) async {
      await tester.runAsync(
        () => run(
          owned: [catchUpScope],
          profiles: [_profile(catchUpScope.profileId, 'Avi')],
        ),
      );

      expect(notifications.schedules, isNotEmpty);
      expect(notifications.schedules.map((s) => s.profileId).toSet(), {
        catchUpScope.profileId,
      });
      expect(
        notifications.schedules.first.body,
        'Avi, record what you learnt?',
      );
      expect(notifications.schedules.first.title, 'Shabbos is over');
    });

    testWidgets('no owned profile: nothing is scheduled', (tester) async {
      await tester.runAsync(() => run());

      expect(notifications.calls, isEmpty);
      expect(container.exists(catchUpReminderSchedulerProvider), isFalse);
    });

    testWidgets('a reconcile failure is swallowed, not thrown', (tester) async {
      await tester.runAsync(
        () => run(
          owned: [catchUpScope],
          profiles: [_profile(catchUpScope.profileId, 'Avi')],
          port: _FailingNotifications(),
        ),
      );

      expect(
        container.read(catchUpReminderSyncEffectProvider).hasError,
        isFalse,
      );
    });
  });
}

class _Tutored extends ActiveTutoredProfileSelection {
  @override
  TutoredProfileSelection? build() => const TutoredProfileSelection(
    profileId: '01J8XKQ2M3N4P5R6S7T8V9W0XY',
    ownerUid: 'another-parent',
    grantId: 'grant-1',
    permissions: TutorPermissions(),
  );
}
