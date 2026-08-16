/// Shared no-op Firestore test double (AUD-t-cross-19).
///
/// Before this helper, `test/sync` files each hand-rolled the full ~46-method
/// [FirestoreGateway] interface as `class _SomeGateway implements
/// FirestoreGateway { ... }`, re-typing the same no-op boilerplate for every
/// method the test in question did not actually exercise — and re-editing
/// every copy whenever the interface grew a method (see the repeated
/// "W7.15: pushStageDefinition added" / "W6.13: fetchAuditLogEntries added"
/// comments this replaces).
///
/// [NoOpFirestoreGateway] extends `Fake` (re-exported by
/// `package:flutter_test/flutter_test.dart` from `package:test_api`), which
/// throws on any method that isn't overridden. Tests should extend this class
/// and override only the 1-3 methods they actually drive — mirroring
/// `sync_orchestrator_profile0_status_test.dart`'s original `_Gw` shape,
/// generalized here so it doesn't need to be redefined per file.
library;

import 'package:flutter_test/flutter_test.dart';

/// A generic fake whose methods throw `UnimplementedError` unless a subclass
/// overrides them. The old sync gateway interface was removed; current
/// Firestore behavior is exposed through the collection-specific repositories.
class NoOpFirestoreGateway extends Fake {}
