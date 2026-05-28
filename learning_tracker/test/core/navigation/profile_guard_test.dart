// Unit tests for ProfileGuard — three routing branches (S6).
//
// Branch 1: tutored session active → resolver.next() (short-circuit, skip all
//           profile checks regardless of own-profile count).
// Branch 2: count==0 own profiles → router.replace(ProfilePickerRoute).
//           Covers both profile-less tutors and genuine first-run users; in
//           both cases the picker is the right destination (TutoredChildrenSection
//           shows active grants; Add Profile CTA handles first-run).
// Branch 3: count≥1 own profiles, one profile → auto-select + resolver.next().
library;

import 'package:auto_route/auto_route.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/daos/profile_dao.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/core/navigation/guards/profile_guard.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/test_database.dart';

class MockNavigationResolver extends Mock implements NavigationResolver {}

class MockStackRouter extends Mock implements StackRouter {}

// Registers fake values for auto_route's PageRouteInfo types so that
// verify() matcher captures them without a registerFallbackValue error.
class _FakePageRouteInfo extends Fake implements PageRouteInfo {}

Future<int> _insertOwnProfile(UserDatabase db, {required int accountId}) {
  return db.into(db.learnerProfiles).insert(
    LearnerProfilesCompanion.insert(
      accountId: accountId,
      displayName: 'Own Learner',
      mode: 'adult',
      createdAt: DateTimeFactory.nowUtc(),
      updatedAt: DateTimeFactory.nowUtc(),
    ),
  );
}

void main() {
  late UserDatabase db;
  late MockNavigationResolver resolver;
  late MockStackRouter router;

  setUpAll(() {
    registerFallbackValue(_FakePageRouteInfo());
  });

  setUp(() async {
    db = createTestDatabase();
    resolver = MockNavigationResolver();
    router = MockStackRouter();
    when(() => router.replace(any())).thenAnswer((_) async => null);
  });

  tearDown(() async {
    await db.close();
  });

  // ── Branch 1: tutored session active ────────────────────────────────────────

  group('tutored session active', () {
    ProfileGuard _makeGuard({required int? selectedId}) => ProfileGuard(
      getDatabase: () => db,
      getSelectedProfileId: () => selectedId,
      setSelectedProfileId: (_) {},
      getAccountId: () => 1,
      isTutoredSession: () => true,
    );

    test('allows through when account has zero own profiles', () async {
      // Profile-less tutor: no own profiles, tutored session active.
      final accountId = await seedAccount(db);
      final guard = _makeGuard(selectedId: null);

      await guard.onNavigation(resolver, router);

      // Must call next() with no argument (or true) — never next(false).
      verify(() => resolver.next()).called(1);
      verifyNever(() => resolver.next(false));
      verifyNever(() => router.replace(any()));
    });

    test('allows through when account has own profiles', () async {
      final accountId = await seedAccount(db);
      final profileId = await _insertOwnProfile(db, accountId: accountId);
      final guard = _makeGuard(selectedId: profileId);

      await guard.onNavigation(resolver, router);

      verify(() => resolver.next()).called(1);
      verifyNever(() => resolver.next(false));
      verifyNever(() => router.replace(any()));
    });
  });

  // ── Branch 2: count==0 own profiles, no tutored session ─────────────────────

  group('zero own profiles, not tutored', () {
    ProfileGuard _makeGuard() => ProfileGuard(
      getDatabase: () => db,
      getSelectedProfileId: () => null,
      setSelectedProfileId: (_) {},
      getAccountId: () => 1,
      isTutoredSession: () => false,
    );

    test('routes to ProfilePickerRoute — not the wizard', () async {
      // Genuine new user: no profiles, no tutored session.
      // ProfileGuard must send them to the picker (not a create-wizard).
      await seedAccount(db);
      final guard = _makeGuard();

      await guard.onNavigation(resolver, router);

      // Picker is the destination for count==0.
      verify(() => router.replace(const ProfilePickerRoute())).called(1);
      verify(() => resolver.next(false)).called(1);
    });

    test('routes to ProfilePickerRoute — same path for profile-less tutor',
        () async {
      // Pure tutor: 0 own profiles, tutored session NOT yet active (before
      // they select a talmid). The picker shows TutoredChildrenSection so they
      // can enter without creating a learner profile.
      await seedAccount(db);
      final guard = _makeGuard();

      await guard.onNavigation(resolver, router);

      verify(() => router.replace(const ProfilePickerRoute())).called(1);
      verify(() => resolver.next(false)).called(1);
    });
  });

  // ── Branch 3: count≥1 own profiles ──────────────────────────────────────────

  group('one own profile, not tutored', () {
    test('auto-selects single profile and calls resolver.next()', () async {
      final accountId = await seedAccount(db);
      final profileId = await _insertOwnProfile(db, accountId: accountId);

      var selected = <int>[];
      final guard = ProfileGuard(
        getDatabase: () => db,
        getSelectedProfileId: () => null,
        setSelectedProfileId: (id) => selected.add(id),
        getAccountId: () => accountId,
        isTutoredSession: () => false,
      );

      await guard.onNavigation(resolver, router);

      expect(selected, [profileId]);
      verify(() => resolver.next()).called(1);
      verifyNever(() => resolver.next(false));
      verifyNever(() => router.replace(any()));
    });
  });

  // ── Branch 4: already-selected valid profile ─────────────────────────────────

  group('valid profile already selected', () {
    test('short-circuits and calls resolver.next()', () async {
      final accountId = await seedAccount(db);
      final profileId = await _insertOwnProfile(db, accountId: accountId);

      final guard = ProfileGuard(
        getDatabase: () => db,
        getSelectedProfileId: () => profileId,
        setSelectedProfileId: (_) {},
        getAccountId: () => accountId,
        isTutoredSession: () => false,
      );

      await guard.onNavigation(resolver, router);

      verify(() => resolver.next()).called(1);
      verifyNever(() => resolver.next(false));
      verifyNever(() => router.replace(any()));
    });
  });
}
