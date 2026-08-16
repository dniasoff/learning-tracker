/// Regression test for BUG D1 — track-creation FK failure after force-stop /
/// cold start.
///
/// Root cause: on a force-stop + cold start with a still-valid session, the app
/// skips the interactive sign-in flow (the only caller of
/// `selectedProfileIdProvider.notifier.select(...)`), leaving the in-memory
/// selection null → `activeProfileIdProvider` returns null → profile-scoped
/// writes during track creation have no active profile identity.
///
/// Fix (round 2 — the real crux): the account that actually hit this had ZERO
/// rows in `learner_profiles` (a cloud account whose profiles never
/// materialised locally), so "select the first profile" was a no-op and the id
/// stayed unset. `autoSelectedProfileIdProvider` now self-heals: when a
/// signed-in account has no profile it creates a default adult profile (via
/// `createProfile`) and selects it. These tests pin that behaviour:
/// after an auth-valid startup, `selectedProfileIdProvider` is always non-null
/// and holds a valid, non-empty ULID profile id.
///
/// AUD-profiles-21 (SM-2 — provider `build` must be pure): the self-heal
/// effect used to live directly in `autoSelectedProfileId`'s `build()`, so
/// merely watching/reading the provider silently wrote to
/// `selectedProfileIdProvider` and the database. The effect now lives in the
/// explicit `ensureSelected()` method — `build()` only mirrors the current
/// selection. These tests invoke `ensureSelected()` (never `.future`) to
/// exercise the effect, plus one test pinning that `.future` alone stays
/// inert.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/providers/active_account_id_provider.dart';
import 'package:learning_tracker/data/firestore/active_account_providers.dart'
    show ActiveAccountId;
import 'package:learning_tracker/data/firestore/repository_providers.dart'
    show activeProfileDocIdProvider;
import 'package:learning_tracker/features/account/domain/models/auth_state.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_state_provider.dart';
import 'package:learning_tracker/features/profiles/domain/models/learner_profile_entity.dart';
import 'package:learning_tracker/features/profiles/domain/repositories/profile_repository.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';

// ─── Fakes ──────────────────────────────────────────────────────────────────

final _epoch = DateTime.utc(2026, 1, 1);

LearnerProfileEntity _profile({
  required String profileId,
  ProfileMode mode = ProfileMode.adult,
}) => LearnerProfileEntity(
  profileId: profileId,
  displayName: 'Profile $profileId',
  mode: mode,
  createdAt: _epoch,
  updatedAt: _epoch,
);

/// A repository that returns a fixed profile list and records self-heal calls.
class _FakeProfileRepository implements ProfileRepository {
  _FakeProfileRepository(this._profiles);
  final List<LearnerProfileEntity> _profiles;

  /// Records how many times the self-heal path ran and the name it was given.
  int ensureCalls = 0;
  String? lastEnsureName;

  /// P2-24 (DEFECT 1 — the `_resolveSelection` "already selected" branch's
  /// unguarded post-await write): when set, [getProfileById] awaits this
  /// gate before returning for [gatedId] only — modeling "the picker /
  /// sign-in flow selects a DIFFERENT profile while this read is still in
  /// flight," the identical shape `profile_activation_heal_race_test.dart`
  /// and `profile_repository_impl_t49_activation_ordering_test.dart` use
  /// for T-49's siblings.
  Completer<void>? getProfileByIdGate;
  String? gatedId;

  @override
  Future<List<LearnerProfileEntity>> getProfiles() async => _profiles;

  @override
  Stream<List<LearnerProfileEntity>> watchProfiles() => Stream.value(_profiles);

  @override
  Future<LearnerProfileEntity?> getProfileById(String profileId) async {
    if (profileId == gatedId && getProfileByIdGate != null) {
      await getProfileByIdGate!.future;
    }
    return _profiles.where((p) => p.profileId == profileId).firstOrNull;
  }

  @override
  Future<int> countProfiles() async => _profiles.length;

  @override
  Future<LearnerProfileEntity> createProfile({
    required String displayName,
    required ProfileMode mode,
    String avatar = '',
  }) async {
    ensureCalls++;
    lastEnsureName = displayName;
    if (_profiles.isNotEmpty) return _profiles.first;
    // Simulate the heal creating + adopting profile ulid-1.
    final healed = _profile(profileId: 'ulid-1', mode: mode);
    _profiles.add(healed);
    return healed;
  }

  @override
  Future<LearnerProfileEntity> updateProfile({
    required String profileId,
    String? displayName,
    ProfileMode? mode,
    String? avatar,
  }) => throw UnimplementedError();

  @override
  Future<void> deleteProfile(String profileId, {bool allowLast = false}) =>
      throw UnimplementedError();
}

class _FixedActiveAccountId extends ActiveAccountId {
  @override
  String? build() => 'account-1';
}

const _signedIn = AuthState.signedIn(
  user: AuthUser(uid: 'account-1', email: 't@t.com', displayName: 'Test'),
  tier: Tier.local,
);

({ProviderContainer container, _FakeProfileRepository repo}) _container({
  required AuthState authState,
  required List<LearnerProfileEntity> profiles,
}) {
  final repo = _FakeProfileRepository(profiles);
  final container = ProviderContainer(
    overrides: [
      authStateProvider.overrideWithValue(authState),
      profileRepositoryProvider.overrideWithValue(repo),
      activeAccountIdProvider.overrideWith(() => _FixedActiveAccountId()),
    ],
  );
  addTearDown(container.dispose);
  return (container: container, repo: repo);
}

void main() {
  group('autoSelectedProfileId (BUG D1)', () {
    test('AUD-profiles-21: build() is a pure read — merely awaiting `.future` '
        'must NOT self-heal or select a profile (SM-2)', () async {
      final result = _container(authState: _signedIn, profiles: []);
      final container = result.container;

      // A widget doing a plain `ref.watch(autoSelectedProfileIdProvider)`
      // exercises exactly this path. Before AUD-profiles-21 this alone
      // triggered `createProfile` (a DB write) and
      // `selectedProfileIdProvider.notifier.select(...)` (a sibling-
      // provider write) from inside build().
      await container.read(autoSelectedProfileIdProvider.future);

      expect(result.repo.ensureCalls, 0);
      expect(container.read(selectedProfileIdProvider), isNull);
    });

    test(
      'auth-valid cold start with null selection selects the first profile',
      () async {
        final container = _container(
          authState: _signedIn,
          profiles: [
            _profile(profileId: 'ulid-7'),
            _profile(profileId: 'ulid-8'),
          ],
        ).container;

        // Pre-condition: nothing selected (simulates the force-stop cold start
        // where the sign-in flow never ran).
        expect(container.read(selectedProfileIdProvider), isNull);

        final selected = await container
            .read(autoSelectedProfileIdProvider.notifier)
            .ensureSelected();

        // The effect selected the account's first profile…
        expect(selected, 'ulid-7');
        // …and the canonical selection state is now non-null & valid.
        expect(container.read(selectedProfileIdProvider), 'ulid-7');
        // …so the active profile id is a non-empty ULID (which is required
        // for profile-scoped Firestore writes).
        expect(container.read(selectedProfileIdProvider), isNotEmpty);
      },
    );

    test('does not clobber an already-selected profile', () async {
      final container = _container(
        authState: _signedIn,
        profiles: [
          _profile(profileId: 'ulid-7'),
          _profile(profileId: 'ulid-8'),
        ],
      ).container;

      // The picker / sign-in flow already chose profile 8.
      container.read(selectedProfileIdProvider.notifier).select('ulid-8');

      final selected = await container
          .read(autoSelectedProfileIdProvider.notifier)
          .ensureSelected();

      expect(selected, 'ulid-8');
      expect(container.read(selectedProfileIdProvider), 'ulid-8');
    });

    test('signed-out startup leaves selection null', () async {
      final container = _container(
        authState: const AuthState.signedOut(),
        profiles: [_profile(profileId: 'ulid-7')],
      ).container;

      final selected = await container
          .read(autoSelectedProfileIdProvider.notifier)
          .ensureSelected();

      expect(selected, isNull);
      expect(container.read(selectedProfileIdProvider), isNull);
    });

    test('signed-in account with NO profiles self-heals: creates + selects a '
        'valid non-empty ULID profile (the BUG D1 crux)', () async {
      final result = _container(authState: _signedIn, profiles: []);
      final container = result.container;

      // Pre-condition: nothing selected and the account owns no profile —
      // the exact state that made createTrack insert profile_id=0 and
      // FK-fail.
      expect(container.read(selectedProfileIdProvider), isNull);

      final selected = await container
          .read(autoSelectedProfileIdProvider.notifier)
          .ensureSelected();

      // The self-heal ran exactly once and created a profile.
      expect(result.repo.ensureCalls, 1);
      // A valid, non-empty ULID profile id is now selected.
      expect(selected, isNotNull);
      expect(selected, isNotEmpty);
      expect(container.read(selectedProfileIdProvider), selected);
      // Default display name was derived from the signed-in account.
      expect(result.repo.lastEnsureName, 'Test');
    });

    test(
      'FK-CONSTRAINT-ONBOARDING-01: stale selected id that does not exist in '
      'the current account DB is cleared and a valid profile is (re-)selected',
      () async {
        // Simulate switching from Account A (had profile id ulid-42) to
        // Account B (a fresh account whose DB only has profile id ulid-99).
        // The in-memory selectedProfileId still holds ulid-42 from Account A's
        // session (the clear() that should have been called was either not
        // reached or arrived after autoSelected ran). If the provider
        // early-returns 42 without checking existence, any write scoped to
        // profile_id=42 in Account B's DB will fail with
        // SqliteException(787): FOREIGN KEY constraint failed.
        final result = _container(
          authState: _signedIn,
          profiles: [
            _profile(profileId: 'ulid-99'),
          ], // Account B has only profile ulid-99
        );
        final container = result.container;

        // Pre-condition: stale id ulid-42 is held from a previous account session.
        container.read(selectedProfileIdProvider.notifier).select('ulid-42');
        expect(container.read(selectedProfileIdProvider), 'ulid-42');

        final selected = await container
            .read(autoSelectedProfileIdProvider.notifier)
            .ensureSelected();

        // After self-healing, the stale id must NOT be returned.
        expect(selected, isNot('ulid-42'));
        // A valid profile that actually exists must be selected.
        expect(selected, 'ulid-99');
        expect(container.read(selectedProfileIdProvider), 'ulid-99');
      },
    );

    test('P2-24 (DEFECT 1): a late-settling "already selected" re-activation '
        'read does not clobber activeProfileDocIdProvider after a DIFFERENT '
        'profile has since been selected', () async {
      // Profile ulid-7 is already selected when ensureSelected() starts its
      // re-check read (`repo.getProfileById('ulid-7')`). While that read is
      // still in flight, the picker / sign-in flow selects profile ulid-8
      // instead — the same "select something else during the await"
      // shape T-49 closed for the create/heal paths, but here the await
      // is a local Drift read, not a Firestore write, so the window is
      // smaller but the defect shape is identical: the sibling branch 43
      // lines below this one in `_resolveSelection` already carries the
      // guard this one lacked.
      final result = _container(
        authState: _signedIn,
        profiles: [
          _profile(profileId: 'ulid-7'),
          _profile(profileId: 'ulid-8'),
        ],
      );
      final container = result.container;
      final gate = Completer<void>();
      result.repo
        ..gatedId = 'ulid-7'
        ..getProfileByIdGate = gate;

      container.read(selectedProfileIdProvider.notifier).select('ulid-7');
      expect(container.read(activeProfileDocIdProvider), 'ulid-7');

      final ensureFuture = container
          .read(autoSelectedProfileIdProvider.notifier)
          .ensureSelected();

      // Let ensureSelected() reach the gated getProfileById(7) read.
      await pumpEventQueue();

      // Meanwhile a different profile becomes the one actually selected.
      container.read(selectedProfileIdProvider.notifier).select('ulid-8');
      expect(
        container.read(activeProfileDocIdProvider),
        'ulid-8',
        reason: 'sanity: still 8 while the profile-7 re-check is in flight',
      );

      // Now let the delayed read for 7 finally resolve.
      gate.complete();
      final selected = await ensureFuture;
      await pumpEventQueue();

      expect(
        container.read(selectedProfileIdProvider),
        'ulid-8',
        reason: 'sanity: 8 is still the selection',
      );
      expect(
        selected,
        'ulid-8',
        reason:
            "_resolveSelection's return value must reflect the CURRENT "
            'selection (8), not the stale one (7) it started reading.',
      );
      expect(
        container.read(activeProfileDocIdProvider),
        'ulid-8',
        reason:
            'DEFECT 1: activeProfileDocIdProvider must stay on the '
            'CURRENTLY selected profile (8). A late-settling '
            '"already selected" re-activation for 7 — a profile that is '
            'no longer selected — re-pointing it back to 7 here is '
            'exactly the clobber T-49 described for the create/heal '
            'paths, reached through this third, previously-unguarded '
            'write instead.',
      );
    });
  });
}
