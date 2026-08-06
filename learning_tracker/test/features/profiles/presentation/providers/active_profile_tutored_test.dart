// Regression tests for BUG-NEW-2 — in an active tutored session the *active*
// profile (id + identity) must resolve to the TALMID's local mirror, never the
// tutor's own profile or the legacy `0` sentinel.
//
// Two product invariants are covered:
//   1. activeProfileIdProvider resolves to the talmid mirror id (not 0, not the
//      tutor's selected profile id) when a tutored selection + resolved mirror
//      are present.
//   2. activeProfileProvider returns the TALMID's ProfileModel — so the
//      dashboard greeting shows the talmid's name, not the tutor's.
@Tags(['tutoring', 'profiles', 'dashboard'])
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/profiles/domain/models/profile_model.dart';
import 'package:learning_tracker/features/profiles/domain/repositories/profile_repository.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/tutoring/domain/models/session_role.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_permissions.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/active_tutored_profile_provider.dart';

// ── Fixtures ──────────────────────────────────────────────────────────────────

const int _tutorOwnProfileId = 1;
const int _talmidMirrorProfileId = 42;
const String _tutorOwnProfileUlid = 'ulid-1';
const String _talmidMirrorProfileUlid = 'ulid-42';

ProfileModel _talmidProfile() => ProfileModel(
  id: _talmidMirrorProfileId,
  ulid: _talmidMirrorProfileUlid,
  accountId: 1,
  displayName: 'Tttt',
  mode: 'child',
  avatarIndex: 0,
  createdAt: DateTime.utc(2026, 1, 1),
  updatedAt: DateTime.utc(2026, 1, 1),
);

ProfileModel _tutorProfile() => ProfileModel(
  id: _tutorOwnProfileId,
  ulid: _tutorOwnProfileUlid,
  accountId: 1,
  displayName: 'Daniel Niasoff',
  mode: 'adult',
  avatarIndex: 0,
  createdAt: DateTime.utc(2026, 1, 1),
  updatedAt: DateTime.utc(2026, 1, 1),
);

TutoredProfileSelection _selection() => const TutoredProfileSelection(
  profileId: 'remote-talmid-id',
  ownerUid: 'owner-uid',
  grantId: 'grant-id',
  permissions: TutorPermissions(),
  tutorOwnProfileId: _tutorOwnProfileId,
);

/// Minimal fake repo: returns the talmid for the mirror id and the tutor for
/// the tutor's own id, so we can assert which profile the active providers pick.
class _FakeProfileRepository implements ProfileRepository {
  @override
  Future<ProfileModel?> getProfileById(int id) async {
    if (id == _talmidMirrorProfileId) return _talmidProfile();
    if (id == _tutorOwnProfileId) return _tutorProfile();
    return null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ProviderContainer _container({required bool tutored}) {
  final container = ProviderContainer(
    overrides: [
      profileRepositoryProvider.overrideWithValue(_FakeProfileRepository()),
    ],
  );
  addTearDown(container.dispose);

  // The tutor's own profile is the one they "selected" — outside tutor mode the
  // active profile must equal this; inside tutor mode it must be overridden by
  // the talmid mirror.
  container
      .read(selectedProfileIdProvider.notifier)
      .select(_tutorOwnProfileId, ulid: _tutorOwnProfileUlid);

  if (tutored) {
    container
        .read(activeTutoredProfileSelectionProvider.notifier)
        .enter(_selection());
    container
        .read(resolvedTutoredLocalProfileIdProvider.notifier)
        .resolve(_talmidMirrorProfileId);
  }
  return container;
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  test(
    'BUG-NEW-2: activeProfileId resolves to the talmid mirror id in a tutored '
    'session (not 0, not the tutor own profile id)',
    () {
      final container = _container(tutored: true);

      final activeId = container.read(activeProfileIdProvider);

      expect(activeId, _talmidMirrorProfileId);
      expect(activeId, isNot(0));
      expect(activeId, isNot(_tutorOwnProfileId));
    },
  );

  test('BUG-NEW-2: activeProfile identity reflects the TALMID (name "Tttt"), '
      'not the tutor ("Daniel Niasoff"), in a tutored session', () async {
    final container = _container(tutored: true);

    final profile = await container.read(activeProfileProvider.future);

    expect(profile, isNotNull);
    expect(profile!.displayName, 'Tttt');
    expect(profile.id, _talmidMirrorProfileId);
  });

  test(
    'outside a tutored session, activeProfileId + activeProfile fall back to '
    "the user's own selected profile",
    () async {
      final container = _container(tutored: false);

      expect(container.read(activeProfileIdProvider), _tutorOwnProfileId);
      final profile = await container.read(activeProfileProvider.future);
      expect(profile!.displayName, 'Daniel Niasoff');
    },
  );

  test(
    'Bug B: after deleting the ACTIVE profile, re-selecting the remaining '
    'profile (what deleteProfileFlow does) makes activeProfile resolve to that '
    'profile — the greeting shows "Daniel", not the generic "Learner" fallback',
    () async {
      final container = ProviderContainer(
        overrides: [
          profileRepositoryProvider.overrideWithValue(_FakeProfileRepository()),
        ],
      );
      addTearDown(container.dispose);

      // Active profile was the just-created child mirror (deleted below).
      container
          .read(selectedProfileIdProvider.notifier)
          .select(_talmidMirrorProfileId, ulid: _talmidMirrorProfileUlid);

      // deleteProfileFlow, on deleting the active profile, auto-switches the
      // selection to a REMAINING profile (here the "Daniel" adult) rather than
      // clearing to null. Emulate that selection move.
      container
          .read(selectedProfileIdProvider.notifier)
          .select(_tutorOwnProfileId, ulid: _tutorOwnProfileUlid);

      expect(container.read(activeProfileIdProvider), _tutorOwnProfileId);
      final profile = await container.read(activeProfileProvider.future);
      expect(profile, isNotNull);
      expect(
        profile!.displayName,
        'Daniel Niasoff',
        reason:
            'greeting must show the now-active profile name immediately, not '
            'the generic "Learner" fallback (id 0 → null)',
      );
    },
  );

  test(
    'Bug B regression: if the active-profile delete clears the selection to '
    'null (old behaviour), activeProfile resolves to null → the greeting falls '
    'back to the generic label; the auto-switch above is what avoids that',
    () async {
      final container = ProviderContainer(
        overrides: [
          profileRepositoryProvider.overrideWithValue(_FakeProfileRepository()),
        ],
      );
      addTearDown(container.dispose);

      container
          .read(selectedProfileIdProvider.notifier)
          .select(_talmidMirrorProfileId, ulid: _talmidMirrorProfileUlid);
      // Old (buggy) delete behaviour: clear instead of selecting next.
      container.read(selectedProfileIdProvider.notifier).clear();

      expect(container.read(activeProfileIdProvider), 0);
      final profile = await container.read(activeProfileProvider.future);
      expect(
        profile,
        isNull,
        reason:
            'documents the failure mode the deleteProfileFlow fix prevents: a '
            'null active profile forces the generic "Learner" greeting',
      );
    },
  );

  test('on-device repro (tutor HAS own profile): with a non-null tutor '
      'selectedProfileId AND an active tutored selection, activeProfileId/'
      'activeProfile resolve to the talmid mirror — driving the dashboard '
      'greeting, the projection/carousel scope (activeProfileIdProvider) and the '
      'TutorModeIndicatorBar name (activeProfileProvider.displayName) to the '
      'CHILD, never the tutor', () async {
    // This is the exact failing on-device state: the tutor has selected
    // their OWN profile (_tutorOwnProfileId is non-null), then entered a
    // tutored session. Previously the view stayed pointed at the tutor.
    final container = _container(tutored: true);

    // selectedProfileIdProvider still tracks the tutor's own profile…
    expect(
      container.read(selectedProfileIdProvider),
      _tutorOwnProfileId,
      reason: 'the tutor own selection is untouched (non-tutored path safe)',
    );

    // …but every dashboard/projection provider scopes on activeProfileId,
    // which now resolves to the child's mirror id.
    expect(container.read(activeProfileIdProvider), _talmidMirrorProfileId);

    // The banner + greeting both read activeProfileProvider.displayName.
    final active = await container.read(activeProfileProvider.future);
    expect(active, isNotNull);
    expect(
      active!.displayName,
      'Tttt',
      reason: 'banner "Tutor mode · <name>" + greeting name the CHILD',
    );
    expect(active.id, _talmidMirrorProfileId);
  });

  test(
    'BUG-NEW-2 guard: while the tutored mirror pull is still in progress '
    '(resolved id null), activeProfileId is the 0 sentinel, never the tutor',
    () {
      final container = ProviderContainer(
        overrides: [
          profileRepositoryProvider.overrideWithValue(_FakeProfileRepository()),
        ],
      );
      addTearDown(container.dispose);

      container
          .read(selectedProfileIdProvider.notifier)
          .select(_tutorOwnProfileId, ulid: _tutorOwnProfileUlid);
      // Tutored selection active but mirror NOT yet resolved.
      container
          .read(activeTutoredProfileSelectionProvider.notifier)
          .enter(_selection());

      final activeId = container.read(activeProfileIdProvider);
      expect(
        activeId,
        0,
        reason:
            'must not leak the tutor own profile id before the mirror '
            'resolves',
      );
      expect(activeId, isNot(_tutorOwnProfileId));
    },
  );
}
