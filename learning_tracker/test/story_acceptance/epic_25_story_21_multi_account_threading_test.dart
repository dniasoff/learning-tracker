/// Story acceptance tests for Story 25.21 — Multi-account threading.
///
/// Replaces 8+ hardcoded `currentAccountId = 1` sites with a provider
/// backed by [authStateProvider] and the `DeviceAccounts` table. Also
/// preserves Epic 19's tier-aware offline UX (banner / no-backup badge).
@Tags(['epic_25', 'story_25_21'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: unused_import — UserTier alias is re-exported by auth_state.dart.
import 'package:learning_tracker/core/database/daos/user_profile_dao.dart';
import 'package:learning_tracker/features/auth/domain/models/auth_state.dart';
import 'package:learning_tracker/features/auth/presentation/providers/auth_state_provider.dart';
import 'package:learning_tracker/features/auth/presentation/widgets/no_backup_badge.dart';
import 'package:learning_tracker/features/auth/presentation/widgets/offline_top_banner.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';

/// Resolves the repo root from the `learning_tracker/` sub-directory so the
/// grep test can scan all of `lib/` without depending on the cwd.
Directory _libDir() {
  for (final candidate in [
    Directory('lib'),
    Directory('learning_tracker/lib'),
  ]) {
    if (candidate.existsSync()) return candidate;
  }
  throw StateError('Could not locate learning_tracker/lib');
}

Iterable<File> _dartFiles(Directory dir) => dir
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart') && !f.path.endsWith('.g.dart'));

/// A minimal [AuthState] override for widget tests — we don't need a real
/// per-user database to assert tier-gated UI.
AuthState _signedIn(int profileId, Tier tier) => AuthState.signedIn(
  user: AuthUser(
    profileId: profileId,
    email: 'test@example.com',
    displayName: 'Test User',
    userMode: 'adult',
  ),
  tier: tier,
);

/// Forces [authStateProvider] into a fixed state without triggering its real
/// `_init()` (which would open a Drift database). Bypasses code generation by
/// extending the generated notifier directly via override.
class _FakeAuthStateNotifier extends AuthStateNotifier {
  _FakeAuthStateNotifier(this._initial);
  final AuthState _initial;

  @override
  AuthState build() => _initial;
}

void main() {
  // ── AC: provider exists and reads active account from auth state ──────

  group('Story 25.21 — currentAccountIdProvider', () {
    test(
      'returns AuthState.currentUser.profileId when signed-in (cloudBorn)',
      () async {
        final container = ProviderContainer(
          overrides: [
            authStateProvider.overrideWith(
              () => _FakeAuthStateNotifier(_signedIn(7, Tier.cloudBorn)),
            ),
          ],
        );
        addTearDown(container.dispose);

        expect(container.read(currentAccountIdProvider), 7);
      },
    );

    test(
      'returns AuthState.currentUser.profileId when signed-in (localBorn)',
      () async {
        final container = ProviderContainer(
          overrides: [
            authStateProvider.overrideWith(
              () => _FakeAuthStateNotifier(_signedIn(42, Tier.localBorn)),
            ),
          ],
        );
        addTearDown(container.dispose);

        expect(container.read(currentAccountIdProvider), 42);
      },
    );

    test('falls back to 1 when no user is signed in', () async {
      // Backwards-compatible default for transient signed-out windows
      // (signup → onboarding) so the provider never throws.
      final container = ProviderContainer(
        overrides: [
          authStateProvider.overrideWith(
            () => _FakeAuthStateNotifier(const AuthState.signedOut()),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(currentAccountIdProvider), 1);
    });

    test('emits new value when auth state flips', () async {
      final container = ProviderContainer(
        overrides: [
          authStateProvider.overrideWith(
            () => _FakeAuthStateNotifier(_signedIn(3, Tier.cloudBorn)),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(currentAccountIdProvider), 3);

      container.read(authStateProvider.notifier).signOut();
      expect(container.read(currentAccountIdProvider), 1);
    });
  });

  // ── AC: grep -rn 'currentAccountId.*=.*1\b' lib/ returns zero hits ────

  group('Story 25.21 — no hardcoded accountId = 1 in lib/', () {
    test('no `currentAccountId = 1` assignment survives', () {
      final libDir = _libDir();
      final offenders = <String>[];
      // The provider itself defines `int currentAccountId(Ref ref) => …`. The
      // banned pattern is an ASSIGNMENT, not a declaration — match `=` followed
      // by `1` but exclude the provider declaration via the `(Ref` prefix.
      final assign = RegExp(r'currentAccountId\s*=\s*1\b');
      for (final f in _dartFiles(libDir)) {
        final lines = f.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          if (assign.hasMatch(lines[i])) {
            offenders.add('${f.path}:${i + 1}: ${lines[i].trim()}');
          }
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'Hardcoded `currentAccountId = 1` assignments remain:\n'
            '${offenders.join('\n')}',
      );
    });

    test('no `accountId: 1` named-arg or `accountId = 1` hardcode survives', () {
      final libDir = _libDir();
      final offenders = <String>[];
      // Match accountId passed as a literal 1, either as a named argument
      // (`accountId: 1`) or an assignment (`accountId = 1`). Skip generated
      // freezed/drift files and DAO/repo signatures (which take `int accountId`
      // as a real parameter).
      final namedArg = RegExp(r'\baccountId\s*:\s*1\b');
      final assign = RegExp(r'\baccountId\s*=\s*1\b');
      for (final f in _dartFiles(libDir)) {
        if (f.path.contains('.freezed.dart')) continue;
        final lines = f.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          // Skip parameter declarations like `int accountId = 1`
          // (none currently exist, but be safe).
          if (line.contains('int accountId')) continue;
          if (namedArg.hasMatch(line) || assign.hasMatch(line)) {
            offenders.add('${f.path}:${i + 1}: ${line.trim()}');
          }
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'Hardcoded `accountId: 1` literals remain:\n'
            '${offenders.join('\n')}',
      );
    });

    test(
      'no `getProfilesByAccount(1)` or `countProfilesForAccount(1)` hardcode',
      () {
        final libDir = _libDir();
        final offenders = <String>[];
        final pat = RegExp(
          r'\b(getProfilesByAccount|countProfilesForAccount|watchProfilesByAccount|profileExistsByName)\s*\(\s*1\b',
        );
        for (final f in _dartFiles(libDir)) {
          if (f.path.contains('.freezed.dart')) continue;
          final lines = f.readAsLinesSync();
          for (var i = 0; i < lines.length; i++) {
            if (pat.hasMatch(lines[i])) {
              offenders.add('${f.path}:${i + 1}: ${lines[i].trim()}');
            }
          }
        }
        expect(
          offenders,
          isEmpty,
          reason:
              'Hardcoded profile-DAO call with literal `1` accountId remains:\n'
              '${offenders.join('\n')}',
        );
      },
    );
  });

  // ── AC: tier-aware offline UX preserved ────────────────────────────────

  group('Story 25.21 — tier-aware offline UX', () {
    Widget wrap({required AuthState authState, required Widget child}) =>
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith(
              () => _FakeAuthStateNotifier(authState),
            ),
          ],
          child: MaterialApp(home: Scaffold(body: child)),
        );

    testWidgets('OfflineTopBanner renders nothing for localBorn tier', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          authState: _signedIn(1, Tier.localBorn),
          child: const OfflineTopBanner(),
        ),
      );
      await tester.pump();
      // localBorn always hides the banner — see widget early-return.
      expect(find.byIcon(Icons.cloud_off), findsNothing);
    });

    testWidgets('OfflineTopBanner renders nothing for signed-out users', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          authState: const AuthState.signedOut(),
          child: const OfflineTopBanner(),
        ),
      );
      await tester.pump();
      expect(find.byIcon(Icons.cloud_off), findsNothing);
    });

    testWidgets('NoBackupBadge renders for localBorn tier', (tester) async {
      await tester.pumpWidget(
        wrap(
          authState: _signedIn(1, Tier.localBorn),
          child: const NoBackupBadge(),
        ),
      );
      await tester.pump();
      expect(find.text('No backup'), findsOneWidget);
    });

    testWidgets('NoBackupBadge hidden for cloudBorn tier', (tester) async {
      await tester.pumpWidget(
        wrap(
          authState: _signedIn(1, Tier.cloudBorn),
          child: const NoBackupBadge(),
        ),
      );
      await tester.pump();
      expect(find.text('No backup'), findsNothing);
    });

    testWidgets('NoBackupBadge hidden when signed out', (tester) async {
      await tester.pumpWidget(
        wrap(
          authState: const AuthState.signedOut(),
          child: const NoBackupBadge(),
        ),
      );
      await tester.pump();
      expect(find.text('No backup'), findsNothing);
    });
  });
}
