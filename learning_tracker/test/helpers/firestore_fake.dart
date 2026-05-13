/// `fake_cloud_firestore` configuration helper (DNI-377 / 27.1).
///
/// Tests should call [createFakeFirestore] rather than constructing
/// `FakeFirebaseFirestore` directly so that:
///   1. When opted in via `strictRules: true`, the project's real
///      `firestore.rules` are mounted in the fake — security-rule
///      violations fail the test the same way they would fail a write
///      to the emulator (NFR12). The companion `fake_firebase_security_rules`
///      library does NOT support `request.resource`, `resource`, or
///      `functions`; clauses using those construct evaluate to deny in
///      the fake, which is honestly stricter than production. For most
///      sync-layer tests the default (`strictRules: false`) is the right
///      choice — it leaves the fake permissive so tests can populate
///      arbitrary state without recreating a full emulator.
///   2. The caller's uid is pre-seeded into the authObject stream so
///      uid-scoped collection ids (e.g. `accounts/{uid}`,
///      `completion_events/{uid}_{profileId}_…`) work without per-test
///      auth boilerplate.
///
/// Usage:
///
///   // Permissive (default) — for the common case where the test is
///   // exercising application code, not the rules themselves.
///   final fake = createFakeFirestore(authenticatedUid: 'uid_abc');
///
///   // Strict — for rules-focused tests. Failing writes raise.
///   final fake = createFakeFirestore(
///     authenticatedUid: 'uid_abc',
///     strictRules: true,
///   );
library;

import 'dart:async';
import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

/// Returns a `FakeFirebaseFirestore` configured with the project's
/// security rules and an optional pre-authenticated user identity.
///
/// [authenticatedUid] is wired into the authObject stream so the rules
/// can branch on `request.auth.uid`. Pass `null` (the default) to leave
/// the caller unauthenticated.
///
/// [strictRules] selects whether to mount the real `firestore.rules`
/// (true) or a permissive allow-all profile (false, default). See the
/// library doc above for the trade-offs.
FakeFirebaseFirestore createFakeFirestore({
  String? authenticatedUid,
  bool strictRules = false,
}) {
  // FakeFirebaseFirestore listens to this stream and snapshots the
  // latest value into its own BehaviorSubject — a one-shot `Stream.value`
  // is therefore sufficient to seed the auth context.
  final auth = Stream<Map<String, dynamic>?>.value(
    authenticatedUid == null ? null : {'uid': authenticatedUid},
  );

  return FakeFirebaseFirestore(
    securityRules: strictRules ? _projectRules : null,
    authObject: auth,
  );
}

/// The project's `firestore.rules`, read once at load time so each call
/// to [createFakeFirestore] does not re-hit the filesystem.
///
/// Tests run with the cwd as either the repo root or `learning_tracker/`
/// depending on the launcher; we try both.
final String _projectRules = _loadProjectRules();

String _loadProjectRules() {
  // Repo-root layout: <root>/firestore.rules ; tests usually run from
  // learning_tracker/ so we look one level up first.
  const candidates = ['../firestore.rules', 'firestore.rules'];
  for (final path in candidates) {
    final file = File(path);
    if (file.existsSync()) return file.readAsStringSync();
  }
  throw StateError(
    'firestore.rules not found. Tried: ${candidates.join(", ")}. '
    'Run tests from learning_tracker/ or the repo root.',
  );
}
