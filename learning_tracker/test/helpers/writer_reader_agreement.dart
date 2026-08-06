/// Writer/reader path-agreement test helper (Phase 1 step B2, `docs/
/// firestore-rewrite-map.md` item 10).
///
/// ## The defect class this exists to catch
///
/// Item 10 of the rewrite map records that on 2026-08-03, 144 tests passed
/// — including six custom-order regression tests — over a wiring where a
/// writer and a reader disagreed about which Firestore document tree they
/// addressed (one wrote the new ULID-keyed profile path, the other still
/// read the frozen Drift-era int-keyed path). Every one of those tests
/// still passed because each test seeded its own fixture directly into
/// whatever path the test author chose, so a writer/reader disagreement
/// was invisible: both "sides" of the test were really just the same
/// fixture, read back.
///
/// [expectWriterReaderAgree] refuses to let a test seed its own fixture.
/// It only runs a [write] closure and a [read] closure supplied by the
/// caller, and — per the hard requirement below — those closures must
/// themselves be resolved through production wiring
/// (`lib/data/firestore/repository_providers.dart` or a feature's own
/// Ref-taking adapter over it), so the *document path* comes from
/// production code on both sides. A test that passes here is a test where
/// the writer and reader genuinely agree on where the data lives, not a
/// test that agrees with itself.
///
/// ## Hard requirement — where `write`/`read` closures may come from
///
/// [expectWriterReaderAgree]'s `write` and `read` closures must NEVER
/// contain a literal `.collection(...)`/`.doc(...)` call. This cannot be
/// enforced syntactically (the closures are opaque `Function` values by
/// the time this helper sees them), so it is stated here as a hard
/// requirement instead: each closure must be one of exactly two shapes.
///
/// **Shape A — a direct provider read.**
/// ```dart
/// write: () async {
///   final repo = await container.read(firestoreGoalRepositoryProvider.future);
///   await repo!.createGoal(curriculumId: CurriculumId.mishnayos, targetPercent: 50);
/// },
/// ```
///
/// **Shape B — a Ref-taking feature adapter that itself re-resolves a
/// `repository_providers.dart` provider internally at call time** (the
/// `FirestoreLearningOrderRepositoryAdapter` pattern). Worked example, from
/// the one existing precedent,
/// `test/features/scheduler/data/repositories/
/// scheduler_learning_order_repository_impl_test.dart`:
/// ```dart
/// SchedulerFirestoreLearningOrderRepositoryAdapter buildReader(
///   ProviderContainer container,
/// ) {
///   final readerProvider =
///       Provider<SchedulerFirestoreLearningOrderRepositoryAdapter>(
///         (ref) => SchedulerFirestoreLearningOrderRepositoryAdapter(ref: ref),
///       );
///   return container.read(readerProvider);
/// }
/// // ...
/// read: () => buildReader(container).getOrder(CurriculumId.mishnayos),
/// ```
/// Either shape lets production code — not the test — decide the
/// collection path and doc-id formula. A closure that passes a literal
/// path in, or that seeds a document itself, proves only that the test is
/// self-consistent: precisely the failure mode that let 144 tests pass
/// over a broken wiring.
///
/// ## What a green run proves — and does not prove
///
/// A passing [expectWriterReaderAgree] call proves PATH AGREEMENT ONLY:
/// the writer and reader resolved to the same document tree in the fake.
/// It does NOT prove the reader's query will succeed against a real
/// deployed Firestore — `fake_cloud_firestore` performs no composite-index
/// enforcement, so a query that needs an index Firestore hasn't built yet
/// will pass here and fail in production. Do not read a green run here as
/// "this query works in production."
///
/// ## `watch()`/`.snapshots()` readers are not yet supported
///
/// Both functions below assume one-shot `.get()`-style reads, matching
/// every reference repository under `lib/data/repositories/` today. A
/// future `read` closure built on `watch()`/`.snapshots()` must drain to a
/// settled state before returning — `fake_cloud_firestore` delivers a
/// `WriteBatch` as several incremental snapshots rather than one atomic
/// update (`docs/firestore-rewrite-map.md` item 9), so a stream reader that
/// returns after the first snapshot may observe a partially-applied write.
library;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/data/firestore/account_firebase.dart';
import 'package:learning_tracker/data/firestore/active_account_providers.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart'
    show activeProfileDocIdProvider;
import 'package:mocktail/mocktail.dart';

import 'firestore_fake.dart';

class _MockFirebaseApp extends Mock implements FirebaseApp {}

class _MockFirebaseAuthHandle extends Mock implements FirebaseAuth {}

/// Builds a [FakeFirebaseFirestore] and a [ProviderContainer] wired to it
/// the same way production wires an active device account + active learner
/// profile, so every `firestoreXRepositoryProvider` in
/// `repository_providers.dart` (and every feature adapter built on one)
/// resolves against this one fake without any further overrides.
///
/// The only two seams this function touches — [activeAccountFirebaseProvider]
/// (overridden with a synthetic [AccountFirebaseHandles]) and
/// [activeProfileDocIdProvider] (set via its real public [ActiveProfileDocId.set]
/// method, never overridden) — are exactly the two seams production code
/// itself drives from account sign-in and profile selection. Everything
/// downstream of them, from `_watchActiveAccountAndProfile` through every
/// repository provider, is unmodified production code.
///
/// `strictRules` is deliberately not a parameter here and always `false`:
/// [createFakeFirestore]'s companion rules engine cannot evaluate
/// `resource.data`/`request.resource`, so a strict-mode run would produce
/// false denials that have nothing to do with path agreement — the one
/// thing this helper exists to check — and would corrupt that signal (see
/// `firestore_fake.dart`'s doc comment and `docs/
/// firestore-rewrite-map.md` item 9).
///
/// Call this exactly ONCE per test and build both the writer and the
/// reader off the returned [container]. Riverpod's per-container
/// memoization is what makes a writer-side resolution and a reader-side
/// resolution genuinely share the same resolved `(uid, profileId,
/// firestore)` triple; two separately-built rigs — even with identical
/// literal `uid`/`profileId` strings — are two different containers with
/// no shared state, which defeats the "exactly one place a divergence
/// could originate" property this helper is built around.
({FakeFirebaseFirestore firestore, ProviderContainer container})
activateAccountAndProfile({
  String uid = 'uid-1',
  String profileId = 'profile-ulid-1',
}) {
  final firestore = createFakeFirestore(strictRules: false);
  final container = ProviderContainer(
    overrides: [
      activeAccountFirebaseProvider.overrideWith(
        (ref) async => AccountFirebaseHandles(
          app: _MockFirebaseApp(),
          firestore: firestore,
          auth: _MockFirebaseAuthHandle(),
          uid: uid,
        ),
      ),
    ],
  );
  container.read(activeProfileDocIdProvider.notifier).set(profileId);
  return (firestore: firestore, container: container);
}

/// Runs [write] then [read] and asserts the value [read] observes
/// [matches] what [write] produced — proving the writer and the reader
/// agree on the same Firestore document tree.
///
/// See the library doc comment for:
/// - the hard requirement on what [write]/[read] may contain (no literal
///   `.collection(...)`/`.doc(...)`; must resolve through
///   `repository_providers.dart` or a Ref-taking adapter over it);
/// - what a green run does and does not prove;
/// - the `watch()`/`.snapshots()` caveat.
///
/// On failure, [firestore]'s entire raw document tree is printed via
/// `printOnFailure` — [FakeFirebaseFirestore.dump] walks the tree directly
/// with no `Query`/`.orderBy()`/`.limit()`/`.startAfter()` involved, so the
/// diagnostic itself cannot trip any of `fake_cloud_firestore`'s
/// query-shaped quirks (`docs/firestore-rewrite-map.md` item 9). This only
/// costs anything on a failing run.
Future<void> expectWriterReaderAgree<T>({
  required FakeFirebaseFirestore firestore,
  required String collection,
  required String writerDescription,
  required String readerDescription,
  required Future<void> Function() write,
  required Future<T> Function() read,
  required Matcher matches,
}) async {
  await write();
  final actual = await read();

  printOnFailure(
    'Raw Firestore state after the write (collection "$collection"):\n'
    '${firestore.dump()}',
  );

  expect(
    actual,
    matches,
    reason:
        'Writer/reader path disagreement on collection "$collection": '
        'the write via $writerDescription was not visible to the read via '
        '$readerDescription. This is the defect class documented in '
        'docs/firestore-rewrite-map.md item 10 — a writer and a reader '
        'silently addressing different document trees, invisible to a '
        'test suite that seeds its own fixtures instead of reading '
        'through production wiring on both sides.',
  );
}
