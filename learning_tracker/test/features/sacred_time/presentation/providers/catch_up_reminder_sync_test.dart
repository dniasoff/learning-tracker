// Story 3.5 (DNI-508) T2/T6: the one owner registration path of the
// catch-up reminder scheduler — every owner profile on the device (AC-1),
// never on a tutor session or tutor account (AC-5), and a settings edit or
// a removed profile reschedules or cancels (AC-6). One scheduler, one
// entry point (T8).

import 'dart:io';
import 'dart:ui' show Locale;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings_history.dart';
import 'package:learning_tracker/domain/learner_state/lock_windows.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/features/profiles/profiles.dart';
import 'package:learning_tracker/features/sacred_time/data/repositories/learner_lock_settings_sources.dart';
import 'package:learning_tracker/features/sacred_time/domain/services/catch_up_reminder_scheduler.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/account_lock_provider.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/catch_up_reminder_providers.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/learner_lock_settings_provider.dart';
import 'package:learning_tracker/features/tutoring/tutoring.dart';

import '../../../../helpers/catch_up_reminder_fakes.dart';
import '../../../../helpers/learner_state/catch_up_card_harness.dart';
import '../../../../helpers/learner_state/lock_fixtures.dart';

final _now = catchUpZone.at(DateTime.utc(2026, 10, 7), hour: 12); // Wed

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

  void resume() => state++;
}

class _Tutored extends ActiveTutoredProfileSelection {
  @override
  TutoredProfileSelection? build() => TutoredProfileSelection(
    profileId: catchUpOtherScope.profileId,
    ownerUid: 'another-parent',
    grantId: 'grant-1',
    permissions: const TutorPermissions(),
  );
}

void main() {
  late FakeCatchUpNotifications notifications;
  late MemoryCatchUpLedger ledger;
  late Map<LearnerScope, LiveSource<LearnerSettingsHistory>> histories;
  late LiveSource<List<LearnerProfileEntity>> profiles;
  late LiveSource<List<LearnerScope>> scopes;
  late ProviderContainer container;

  setUp(() {
    notifications = FakeCatchUpNotifications();
    ledger = MemoryCatchUpLedger();
    histories = {
      catchUpScope: LiveSource(constantHistory(lakewood)),
      catchUpOtherScope: LiveSource(constantHistory(jerusalem)),
    };
    profiles = LiveSource([
      _profile(catchUpScope.profileId, 'Avi'),
      _profile(catchUpOtherScope.profileId, 'Dina'),
    ]);
    scopes = LiveSource([catchUpScope, catchUpOtherScope]);
  });

  tearDown(() => container.dispose());

  ProviderContainer build({bool tutored = false}) {
    final ownerScopes = StreamProvider<List<LearnerScope>>(
      (ref) => scopes.stream(),
    );
    container = ProviderContainer(
      overrides: [
        if (tutored)
          activeTutoredProfileSelectionProvider.overrideWith(_Tutored.new),
        lockDrivingScopesProvider.overrideWith((ref) => ref.watch(ownerScopes)),
        profileListStreamProvider.overrideWith((ref) => profiles.stream()),
        activeLearnerScopeProvider.overrideWith((ref) async => catchUpScope),
        learnerLockSettingsProvider.overrideWith(
          (ref, scope) => histories[scope]!.stream(),
        ),
        catchUpReminderNotificationsProvider.overrideWithValue(notifications),
        catchUpReminderLedgerProvider.overrideWithValue(ledger),
        catchUpReminderClockProvider.overrideWithValue(() => _now),
        catchUpReminderCardContentReaderProvider.overrideWithValue(null),
        catchUpReminderResumeCountProvider.overrideWith(_NoResumes.new),
        currentAppLocaleProvider.overrideWithValue(const Locale('en')),
      ],
    );
    return container;
  }

  /// Keeps the effect alive and lets every pending run finish.
  Future<void> settle() async {
    for (var i = 0; i < 20; i++) {
      await Future<void>.delayed(Duration.zero);
      try {
        await container.read(catchUpReminderSyncEffectProvider.future);
      } on Object {
        // a superseded run
      }
    }
  }

  Future<void> start({bool tutored = false}) async {
    build(
      tutored: tutored,
    ).listen(catchUpReminderSyncEffectProvider, (_, _) {});
    await settle();
  }

  List<DateTime> endsFor(LearnerSettingsHistory h) => [
    for (final l in lockWindows(h, _now, _now.add(catchUpReminderHorizon)))
      if (l.endUtc.isAfter(_now)) l.endUtc,
  ];

  group('AC-1: every owner profile on the device', () {
    test('each profile gets its own lock reminders, not only the selected '
        'one', () async {
      await start();
      final byProfile = <String, List<DateTime>>{};
      for (final s in notifications.schedules) {
        (byProfile[s.profileId] ??= []).add(s.fireAtUtc);
      }
      expect(
        byProfile[catchUpScope.profileId],
        endsFor(constantHistory(lakewood)),
      );
      expect(
        byProfile[catchUpOtherScope.profileId],
        endsFor(constantHistory(jerusalem)),
      );
      // The copy carries the display name and nothing else of the learner.
      expect(
        notifications.schedules
            .where((s) => s.profileId == catchUpOtherScope.profileId)
            .map((s) => s.body)
            .toSet(),
        {'Dina, record what you learnt?'},
      );
      expect(notifications.schedules.first.title, 'Shabbos is over');
    });

    test('a resume re-arms the same ids without a duplicate', () async {
      await start();
      final ids = notifications.osPending.keys.toSet();
      notifications.calls.clear();
      (container.read(catchUpReminderResumeCountProvider.notifier)
              as _NoResumes)
          .resume();
      await settle();
      expect(notifications.schedules.map((s) => s.id).toSet(), ids);
      expect(notifications.cancels, isEmpty);
      expect(notifications.osPending.keys.toSet(), ids);
    });
  });

  group('AC-5: never on a tutor device', () {
    test('a tutor session: the scheduler is never built and the gateway '
        'gets no catch-up call, even for the viewable learner', () async {
      await start(tutored: true);
      expect(container.exists(catchUpReminderSchedulerProvider), isFalse);
      expect(notifications.calls, isEmpty);
      expect(notifications.permissionChecks, 0);
    });

    test('a tutor account with no own profile never starts', () async {
      scopes = LiveSource(const []);
      profiles = LiveSource(const []);
      await start();
      expect(container.exists(catchUpReminderSchedulerProvider), isFalse);
      expect(notifications.calls, isEmpty);
    });
  });

  group('AC-6: settings edits and removed profiles', () {
    Future<void> expectMovedTo(LearnerSettingsHistory moved) async {
      await start();
      final oldIds = {
        for (final s in notifications.schedules)
          if (s.profileId == catchUpScope.profileId) s.id,
      };
      notifications.calls.clear();
      histories[catchUpScope]!.value = moved;
      await settle();
      final pending = [
        for (final s in notifications.osPending.values)
          if (s.profileId == catchUpScope.profileId) s.fireAtUtc,
      ]..sort();
      expect(pending, endsFor(moved));
      // Old ids are cancelled before anything new is scheduled.
      final firstSchedule = notifications.calls.indexWhere(
        (c) => c is ScheduleCall,
      );
      final cancelled = notifications.cancels.map((c) => c.id).toSet();
      expect(cancelled, isNotEmpty);
      expect(oldIds.containsAll(cancelled), isTrue);
      expect(
        notifications.calls.lastIndexWhere((c) => c is CancelCall),
        lessThan(firstSchedule),
      );
      // The other profile is untouched.
      expect(
        notifications.calls.whereType<ScheduleCall>().where(
          (s) => s.profileId == catchUpOtherScope.profileId,
        ),
        isEmpty,
      );
    }

    final changeAt = _now.subtract(const Duration(hours: 1));

    test('a moved location', () async {
      await expectMovedTo(
        movedHistory(
          lakewood,
          changeAt,
          lockSettings(latitude: 34.05, longitude: -118.24, inIsrael: false),
        ),
      );
    });

    test('a new IANA time_zone', () async {
      await expectMovedTo(
        movedHistory(
          lakewood,
          changeAt,
          lockSettings(
            timeZone: 'Europe/London',
            latitude: 51.5074,
            longitude: -0.1278,
            inIsrael: false,
          ),
        ),
      );
    });

    test('in_israel set', () async {
      // Israel coordinates with a flag flip only: the Shabbos ends do not
      // move, so nothing is rescheduled — and nothing is duplicated.
      await start();
      final before = Map.of(notifications.osPending);
      notifications.calls.clear();
      histories[catchUpScope]!.value = movedHistory(
        lakewood,
        changeAt,
        lockSettings(latitude: 40.0821, longitude: -74.2097, inIsrael: true),
      );
      await settle();
      expect(notifications.osPending, before);
    });

    test('a profile removed from the device loses every reminder', () async {
      await start();
      final otherIds = {
        for (final s in notifications.schedules)
          if (s.profileId == catchUpOtherScope.profileId) s.id,
      };
      notifications.calls.clear();
      scopes.value = [catchUpScope];
      profiles.value = [_profile(catchUpScope.profileId, 'Avi')];
      await settle();
      expect(notifications.cancels.map((c) => c.id).toSet(), otherIds);
      expect(notifications.osPending.values.map((s) => s.profileId).toSet(), {
        catchUpScope.profileId,
      });
    });
  });

  group('T8: one scheduler, one registration path', () {
    List<File> dartFiles(String dir) => [
      for (final f in Directory(dir).listSync(recursive: true))
        if (f is File && f.path.endsWith('.dart')) f,
    ];

    test('CatchUpReminderScheduler is constructed in exactly one place', () {
      // Every `CatchUpReminderScheduler(` outside its own declaration.
      final sites = [
        for (final f in dartFiles('lib'))
          if (!f.path.endsWith('catch_up_reminder_scheduler.dart') &&
              RegExp(
                r'\bCatchUpReminderScheduler\(',
              ).hasMatch(f.readAsStringSync()))
            f.path,
      ];
      expect(sites, hasLength(1));
      expect(sites.single, endsWith('catch_up_reminder_providers.dart'));
    });

    test('only the notifications bootstrap starts the sync effect', () {
      final sites = [
        for (final f in dartFiles('lib'))
          if (f.readAsStringSync().contains(
            'read(catchUpReminderSyncEffectProvider)',
          ))
            f.path,
      ];
      expect(sites, [endsWith('notifications_bootstrap.dart')]);
    });

    test('the catch-up code never requests a permission', () {
      for (final path in [
        'lib/features/sacred_time/domain/services/catch_up_reminder_scheduler.dart',
        'lib/features/sacred_time/presentation/providers/catch_up_reminder_providers.dart',
        'lib/features/sacred_time/data/services/catch_up_reminder_gateway_adapter.dart',
      ]) {
        expect(
          File(path).readAsStringSync(),
          isNot(contains('requestPermission')),
          reason: path,
        );
      }
    });
  });
}
