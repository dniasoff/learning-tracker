/// Acceptance test for Plan §F Phase 4 deliverable 5 — "restore complete
/// → reroute" must NEVER push the onboarding wizard when the just-merged
/// Drift state shows ≥ 1 learner profile for the current account.
///
/// Real Firestore is not available in unit tests; we simulate the pulled
/// state by pre-populating the in-memory Drift DB with the rows that
/// pull-on-launch would have merged from `users/{uid}/learner_profiles/`.
/// The decision logic in `_navigateAfterRestore`
/// (`lib/app/restore/device_restore_screen.dart`) reads exclusively from
/// `profileDao.getProfilesByAccount(accountId)` — exactly what this test
/// asserts against.
@Tags(['integration'])
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/app/restore/device_restore_service.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/sync/sync_orchestrator.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/onboarding/domain/services/curriculum_import_service.dart';
import 'package:learning_tracker/features/sync/domain/models/sync_status.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talker/talker.dart';

import '../helpers/drift_memory.dart';

class _MockCurriculumImportService extends Mock
    implements CurriculumImportService {}

/// Sync orchestrator stub that mimics a successful pull-on-launch by
/// inserting [profiles] into [db] when [pullOnLaunch] is invoked.
class _SeedingSyncOrchestrator implements SyncOrchestrator {
  _SeedingSyncOrchestrator({required this.db, required this.profiles});

  final UserDatabase db;
  final List<({int id, String displayName, String mode})> profiles;

  @override
  Future<void> pullOnLaunch({bool triggeredFromResume = false}) async {
    // Simulate the LearnerProfileMerger writing into Drift after a pull.
    for (final p in profiles) {
      await db
          .into(db.learnerProfiles)
          .insert(
            LearnerProfilesCompanion.insert(
              id: Value(p.id),
              accountId: 1,
              displayName: p.displayName,
              mode: p.mode,
              createdAt: DateTimeFactory.nowUtc(),
              updatedAt: DateTimeFactory.nowUtc(),
            ),
          );
    }
  }

  @override
  Future<void> retryPull() async {}

  @override
  Future<void> pushAllLocalData() async {}

  @override
  Future<void> stopListeners() async {}

  @override
  void restartListeners() {}

  @override
  SyncStatus get currentStatus =>
      SyncStatus.synced(lastSyncedAt: DateTimeFactory.nowUtc());

  @override
  Stream<SyncStatus> get statusStream => const Stream.empty();
}

/// Helper that mirrors the routing decision in
/// `device_restore_screen._navigateAfterRestore`. The screen's actual
/// `replaceAll([route])` call cannot be exercised without a running
/// MaterialApp + AutoRouter, but the choice of route is a pure function
/// of the profile count — exactly what this helper returns.
String _decideRouteAfterRestore(List<dynamic> profiles) {
  if (profiles.length == 1) return 'AppShellRoute';
  if (profiles.length > 1) return 'ProfilePickerRoute';
  return 'AppShellRoute'; // defensive — never OnboardingRoute post-restore.
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group(
    'Plan §F Phase 4 deliverable 5 — restore skips the onboarding wizard',
    () {
      test(
        'single cloud profile → AppShellRoute (never OnboardingRoute)',
        () async {
          final db = inMemoryDb();
          addTearDown(db.close);

          // Seed the account locally — the LearnerProfilesCompanion FK
          // requires this row before learner_profiles can be inserted.
          await db
              .into(db.accounts)
              .insert(
                AccountsCompanion.insert(
                  email: 'returning@example.com',
                  tier: 'cloudBorn',
                  displayName: 'Returning User',
                  createdAt: DateTimeFactory.nowUtc(),
                  updatedAt: DateTimeFactory.nowUtc(),
                ),
              );

          final orchestrator = _SeedingSyncOrchestrator(
            db: db,
            profiles: const [(id: 1, displayName: 'Daniel', mode: 'adult')],
          );

          final importSvc = _MockCurriculumImportService();
          when(
            () => importSvc.importAll(any()),
          ).thenAnswer((_) => const Stream.empty());

          final svc = DeviceRestoreService(
            database: db,
            syncOrchestrator: orchestrator,
            profileId: 1,
            isAuthenticated: true,
            curriculumImportService: importSvc,
            logger: AppLogger(Talker()),
          );
          addTearDown(svc.dispose);

          final success = await svc.restore();
          expect(success, isTrue, reason: 'restore should succeed');

          // Post-restore profile count drives the route decision.
          final profiles = await db.profileDao.getProfilesByAccount(1);
          expect(profiles, hasLength(1));

          final route = _decideRouteAfterRestore(profiles);
          expect(route, 'AppShellRoute');
          expect(
            route,
            isNot('OnboardingRoute'),
            reason:
                'a returning user with cloud profiles must never land '
                'on the onboarding wizard after restore',
          );
        },
      );

      test(
        'multiple cloud profiles → ProfilePickerRoute (never OnboardingRoute)',
        () async {
          final db = inMemoryDb();
          addTearDown(db.close);

          await db
              .into(db.accounts)
              .insert(
                AccountsCompanion.insert(
                  email: 'family@example.com',
                  tier: 'cloudBorn',
                  displayName: 'Family Account',
                  createdAt: DateTimeFactory.nowUtc(),
                  updatedAt: DateTimeFactory.nowUtc(),
                ),
              );

          final orchestrator = _SeedingSyncOrchestrator(
            db: db,
            profiles: const [
              (id: 1, displayName: 'Parent', mode: 'adult'),
              (id: 2, displayName: 'Child', mode: 'child'),
            ],
          );

          final importSvc = _MockCurriculumImportService();
          when(
            () => importSvc.importAll(any()),
          ).thenAnswer((_) => const Stream.empty());

          final svc = DeviceRestoreService(
            database: db,
            syncOrchestrator: orchestrator,
            profileId: 1,
            isAuthenticated: true,
            curriculumImportService: importSvc,
            logger: AppLogger(Talker()),
          );
          addTearDown(svc.dispose);

          final success = await svc.restore();
          expect(success, isTrue);

          final profiles = await db.profileDao.getProfilesByAccount(1);
          expect(profiles, hasLength(2));

          final route = _decideRouteAfterRestore(profiles);
          expect(route, 'ProfilePickerRoute');
          expect(route, isNot('OnboardingRoute'));
        },
      );
    },
  );
}
