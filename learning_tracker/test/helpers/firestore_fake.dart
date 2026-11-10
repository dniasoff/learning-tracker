/// `fake_cloud_firestore` configuration helper (DNI-377 / 27.1).
///
/// Tests should call [createFakeFirestore] rather than constructing
/// `FakeFirebaseFirestore` directly so that:
///   1. When opted in via `strictRules: true`, the helper attempts to mount
///      the project's real `firestore.rules`. The companion
///      `fake_firebase_security_rules` parser does not support several real
///      rule constructs, including custom functions. If it cannot compile
///      the rules, strict mode falls back to a deny-all ruleset; it never
///      substitutes a permissive policy. Use `make test-rules` for real
///      allow/deny verification. For most sync-layer tests the default
///      (`strictRules: false`) is the right choice — it leaves the fake
///      permissive so tests can populate arbitrary state.
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

/// Returns a `FakeFirebaseFirestore` configured with strict or permissive
/// fake rules and an optional pre-authenticated user identity.
///
/// [authenticatedUid] is wired into the authObject stream so the rules
/// can branch on `request.auth.uid`. Pass `null` (the default) to leave
/// the caller unauthenticated.
///
/// [strictRules] attempts to mount the real `firestore.rules` (true),
/// falling back to a deny-all policy if the fake parser cannot compile it,
/// or uses no rules (false, default). See the library doc above.
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

  if (!strictRules) {
    return FakeFirebaseFirestore(authObject: auth);
  }

  if (_projectRulesSupportedByFake == false ||
      RegExp(r'\bfunction\s+\w+\s*\(').hasMatch(_projectRules)) {
    // The pinned fake parser does not implement custom rule functions. Skip
    // its noisy parse attempt and fail closed; the emulator evaluates the
    // actual project rules in make test-rules.
    _projectRulesSupportedByFake = false;
    return FakeFirebaseFirestore(
      securityRules: _denyAllRules,
      authObject: auth,
    );
  }

  try {
    final firestore = FakeFirebaseFirestore(
      securityRules: _projectRules,
      authObject: auth,
    );
    _projectRulesSupportedByFake = true;
    return firestore;
  } on UnsupportedError catch (error) {
    if (!error.message.toString().contains(
      'Only Binary functions are supported',
    )) {
      rethrow;
    }
    _projectRulesSupportedByFake = false;
    return FakeFirebaseFirestore(
      securityRules: _denyAllRules,
      authObject: auth,
    );
  }
}

/// Whether the fake parser successfully compiled the real project rules.
/// A `false` result is cached so each strict fake does not repeat the known
/// parser failure before using the fail-closed ruleset.
bool? _projectRulesSupportedByFake;

const _denyAllRules = '''
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
''';

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
