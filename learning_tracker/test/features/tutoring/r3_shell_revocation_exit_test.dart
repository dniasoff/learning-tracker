// R3-fix regression test: shell-level revocation detection
//
// Verifies that when a tutored session is active and the CF result from
// incomingTutorGrantsProvider no longer contains the active grant (revoked),
// the existing reconciliation inside the provider fires exit() and clears
// activeTutoredProfileSelectionProvider — even when the tutor is deep in a
// non-grants screen.
//
// Implementation guarantee being tested:
//   app_shell.dart _AppShellScreenState.build() calls
//     ref.watch(incomingTutorGrantsProvider)
//   when hasActiveTutoredProfiles — keeping the provider subscribed for the
//   duration of the tutored session so the wipe+exit runs on the next CF result.
//
// This test exercises the provider layer only (no widgets / no router needed):
//   1. Seed a mirror row for the active grant.
//   2. Start a tutored session (enter the selection).
//   3. Read incomingTutorGrantsProvider with a CF result that omits the grant.
//   4. Assert activeTutoredProfileSelectionProvider → null (exit fired).

@Tags(['tutoring', 'r3_revocation'])
library;

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/account/domain/models/auth_state.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_state_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart'
    show currentAccountIdProvider;
import 'package:learning_tracker/features/tutoring/domain/models/session_role.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_grant_aggregate.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_permissions.dart';
import 'package:learning_tracker/features/tutoring/domain/use_cases/tutor_invite_use_cases.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/active_tutored_profile_provider.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/manage_tutors_providers.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/tutor_grant_providers.dart'
    show tutorGrantRepositoryProvider;

import '../../helpers/drift_memory.dart';

// ── Minimal fake repository ──────────────────────────────────────────────────

class _FakeRepo extends Fake implements TutorGrantRepository {
  _FakeRepo({required this.grants, required this.ok});
  final List<TutorGrant> grants;
  final bool ok;

  @override
  Future<({List<TutorGrant> grants, bool ok})>
  listIncomingGrantsWithStatus() async => (grants: grants, ok: ok);

  @override
  Future<List<TutorGrant>> listIncomingGrants() async => grants;
}

// ── Fixtures ──────────────────────────────────────────────────────────────────

const _activeGrantId = 'g-active-session';
const _ownerUid = 'parent-uid';

const _activeSelection = TutoredProfileSelection(
  profileId: 'remote-child-1',
  ownerUid: _ownerUid,
  grantId: _activeGrantId,
  permissions: TutorPermissions(canViewProgress: true, canViewContent: true),
);

ProviderContainer _makeContainer(_FakeRepo repo, UserDatabase db) {
  final c = ProviderContainer(
    overrides: [
      userDatabaseProvider.overrideWithValue(db),
      currentAccountIdProvider.overrideWithValue(1),
      authStateProvider.overrideWithValue(
        const AuthState.signedIn(
          user: AuthUser(
            profileId: 1,
            email: 'tutor@example.com',
            displayName: 'Tutor',
            firebaseUid: 'tutor-uid',
          ),
          tier: Tier.cloudBorn,
        ),
      ),
      tutorGrantRepositoryProvider.overrideWithValue(repo),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

Future<void> _seedActiveMirror(UserDatabase db) async {
  await db.profileDao.upsertTutoredProfile(
    accountId: 1,
    parentUid: _ownerUid,
    remoteChildProfileId: 'remote-child-1',
    grantId: _activeGrantId,
    displayName: 'Talmid',
    mode: 'child',
    now: DateTime.utc(2026, 5, 31),
  );
}

// ── Tests ────────────────────────────────────────────────────────────────────

void main() {
  group('R3-fix: shell revocation detection — incomingTutorGrantsProvider '
      'exits active session on CF success', () {
    // ── Provider-layer tests (no widgets) ────────────────────────────────

    test(
      'CF success omitting active grant → reconciliation wipes mirror and '
      'exits the tutored session (activeTutoredProfileSelectionProvider → null)',
      () async {
        final db = inMemoryDb();
        addTearDown(db.close);
        await seedProfile(db); // account 1 + learner profile 1
        await _seedActiveMirror(db);

        // CF returns ok=true with no grants — active grant was revoked.
        final container = _makeContainer(
          _FakeRepo(grants: const [], ok: true),
          db,
        );

        // Enter a tutored session so the active selection is non-null.
        container
            .read(activeTutoredProfileSelectionProvider.notifier)
            .enter(_activeSelection);

        expect(
          container.read(activeTutoredProfileSelectionProvider),
          isNotNull,
          reason: 'precondition: tutored session must be active',
        );

        // Reading the provider mirrors what the shell's ref.watch() does.
        // The reconciliation inside the provider detects the active grant is
        // absent and calls activeTutoredProfileSelectionProvider.notifier.exit().
        await container.read(incomingTutorGrantsProvider.future);

        expect(
          container.read(activeTutoredProfileSelectionProvider),
          isNull,
          reason:
              'revoked grant: reconciliation must have called exit(), '
              'clearing the active tutored selection',
        );

        final mirrors = await db.profileDao.getTutoredMirrorsForAccount(1);
        expect(
          mirrors,
          isEmpty,
          reason: 'revoked grant: mirror must be wiped on CF success',
        );
      },
    );

    test(
      'CF success with active grant still present → session is NOT exited',
      () async {
        final db = inMemoryDb();
        addTearDown(db.close);
        await seedProfile(db);
        await _seedActiveMirror(db);

        final doc = TutorGrantDoc(
          grantId: _activeGrantId,
          parentUid: _ownerUid,
          childProfileId: 'remote-child-1',
          tutorEmail: 'tutor@example.com',
          state: TutorGrantState.active,
          invitedAt: DateTime.utc(2026, 5, 1),
          updatedAt: DateTime.utc(2026, 5, 1),
          acceptedAt: DateTime.utc(2026, 5, 1),
          childName: 'Talmid',
        );
        final stillActiveGrant = TutorGrant.fromDoc(
          doc,
          permissions: TutorPermissions.defaults(),
        );

        final container = _makeContainer(
          _FakeRepo(grants: [stillActiveGrant], ok: true),
          db,
        );

        container
            .read(activeTutoredProfileSelectionProvider.notifier)
            .enter(_activeSelection);

        await container.read(incomingTutorGrantsProvider.future);

        expect(
          container.read(activeTutoredProfileSelectionProvider),
          isNotNull,
          reason: 'active grant still in CF result: session must remain active',
        );
      },
    );

    test('CF offline failure (ok=false) → mirror retained, session stays active '
        '(offline-first guarantee)', () async {
      final db = inMemoryDb();
      addTearDown(db.close);
      await seedProfile(db);
      await _seedActiveMirror(db);

      final container = _makeContainer(
        _FakeRepo(grants: const [], ok: false),
        db,
      );

      container
          .read(activeTutoredProfileSelectionProvider.notifier)
          .enter(_activeSelection);

      await container.read(incomingTutorGrantsProvider.future);

      expect(
        container.read(activeTutoredProfileSelectionProvider),
        isNotNull,
        reason:
            'offline CF failure: must not exit session — do not evict cached talmid',
      );

      final mirrors = await db.profileDao.getTutoredMirrorsForAccount(1);
      expect(
        mirrors,
        hasLength(1),
        reason: 'offline CF failure: mirror must be retained',
      );
    });

    // ── Structural tests (source-level) ──────────────────────────────────

    test('app_shell.dart subscribes to incomingTutorGrantsProvider gated on '
        'an active tutored session', () {
      final shellSrc = File('lib/app/router/app_shell.dart').readAsStringSync();

      expect(
        shellSrc,
        contains('incomingTutorGrantsProvider'),
        reason:
            'app_shell.dart must subscribe to incomingTutorGrantsProvider '
            'so revocation reconciliation fires during tutored sessions',
      );
      expect(
        shellSrc,
        contains('hasActiveTutoredProfiles'),
        reason:
            'the incomingTutorGrantsProvider subscription must be gated '
            'on hasActiveTutoredProfiles so non-tutor sessions pay no cost',
      );
      expect(
        shellSrc,
        contains('ref.watch(incomingTutorGrantsProvider)'),
        reason:
            'must use ref.watch (not ref.read) so the subscription is live '
            'and the reconciliation fires whenever the provider re-evaluates',
      );
    });
  });
}
