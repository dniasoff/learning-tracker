/// Story acceptance tests for Story 25.21 — Multi-account threading.
///
/// Story 25.21 acceptance coverage for the current multi-account seam and
/// tier-aware offline UX.
///
/// RETIRED-API DISCLOSURE (2026-08-14): the auth-derived integer
/// `currentAccountIdProvider` and the Drift `UserProfileDao` were removed.
/// Current production uses the explicit String-valued
/// `activeAccountIdProvider` in `lib/data/firestore/active_account_providers.dart`;
/// the account picker sets it when the user selects an account. The first
/// group below therefore migrates the same selection/clear assertions to that
/// live provider. The source-scan and widget assertions remain unchanged.
// ignore_for_file: deprecated_member_use
@Tags(['epic_25', 'story_25_21'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/data/firestore/active_account_providers.dart';
import 'package:learning_tracker/features/account/domain/models/auth_state.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_state_provider.dart';
import 'package:learning_tracker/features/account/presentation/widgets/offline_top_banner.dart';

import '../helpers/pump_app.dart';

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
AuthState _signedIn(String profileId, Tier tier) => AuthState.signedIn(
  user: AuthUser(
    uid: profileId,
    email: 'test@example.com',
    displayName: 'Test User',
  ),
  tier: tier,
);

/// Forces [authStateProvider] into a fixed state without triggering its real
/// initialization. Bypasses code generation by extending the generated
/// notifier directly via override.
class _FakeAuthStateNotifier extends AuthStateNotifier {
  _FakeAuthStateNotifier(this._initial);
  final AuthState _initial;

  @override
  AuthState build() => _initial;
}

void main() {
  // ── AC: explicit active-account selection is String-valued ────────────

  group('Story 25.21 — activeAccountIdProvider', () {
    test(
      'returns the selected account id for a cloud-born account',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        container.read(activeAccountIdProvider.notifier).set('account-7');
        expect(container.read(activeAccountIdProvider), 'account-7');
      },
    );

    test(
      'returns the selected account id for a local-born account',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        container.read(activeAccountIdProvider.notifier).set('local-account-42');
        expect(container.read(activeAccountIdProvider), 'local-account-42');
      },
    );

    test('is null until an account is selected', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(activeAccountIdProvider), isNull);
    });

    test('emits the newly selected value and clears on sign-out/removal', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(activeAccountIdProvider.notifier);
      notifier.set('account-3');
      expect(container.read(activeAccountIdProvider), 'account-3');

      notifier.set(null);
      expect(container.read(activeAccountIdProvider), isNull);
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
        pumpApp(
          overrides: [
            authStateProvider.overrideWith(
              () => _FakeAuthStateNotifier(authState),
            ),
          ],
          child: Scaffold(body: child),
        );

    testWidgets('OfflineTopBanner renders nothing when visible == false', (
      tester,
    ) async {
      // The widget is now pure: it renders only what the `visible` flag
      // says. The tier + connectivity gate moved to AppShellScreen (the
      // single source of truth that also sizes the appBar's PreferredSize
      // from the same decision). The localBorn-hides-banner semantics is
      // therefore enforced by AppShellScreen passing `visible: false` for
      // anyone except cloud-born offline users.
      await tester.pumpWidget(
        wrap(
          authState: _signedIn('local-account-1', Tier.local),
          child: const OfflineTopBanner(visible: false),
        ),
      );
      await tester.pump();
      expect(find.byIcon(Icons.cloud_off), findsNothing);
    });

    testWidgets('OfflineTopBanner renders the banner when visible == true', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          authState: const AuthState.signedOut(),
          child: const OfflineTopBanner(visible: true),
        ),
      );
      await tester.pump();
      expect(find.byIcon(Icons.cloud_off), findsOneWidget);
    });
  });
}
