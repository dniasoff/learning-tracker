/// Shared "not ready" assertions for the scheduler feature's Firestore
/// repository adapters.
///
/// Every adapter built in the Drift→Firestore rewrite has the SAME
/// not-ready contract (see `lib/features/learning/data/repositories/
/// bookmark_repository_impl.dart`, the reference): when no device account or
/// no learner profile is active, the underlying
/// `FutureProvider<FirestoreXRepository?>` resolves to `null`, and the
/// adapter degrades within each method's existing return shape rather than
/// widening the interface — a list read yields `[]`, a nullable read yields
/// `null`, and a non-nullable write throws that adapter's own
/// `*NotReadyException`.
///
/// Because that contract is identical across adapters, asserting it inline
/// in each test file produced near-identical bodies, which
/// `tool/check_scheduler_test_duplication.dart` (TQ-7/Fowler,
/// AUD-t-scheduler-01, `make audit` check 66) correctly flags: two files
/// under `test/features/scheduler/` sharing a >=80%-similar test body under
/// the same group name. These helpers exist so the shared contract is
/// asserted in ONE place and each adapter's test states only what is
/// specific to it.
///
/// Deliberately not a mixin or a base class — plain functions keep each call
/// site readable as an ordinary `expect`, and keep the failure message
/// pointing at the caller's line rather than a shared harness.
library;

import 'package:flutter_test/flutter_test.dart';

/// Asserts a list-returning read degrades to an empty list — never throws,
/// never returns null — while the adapter is not ready.
///
/// [read] is invoked exactly once. [describe] names the method under test so
/// a failure identifies which read regressed.
Future<void> expectEmptyListWhenNotReady(
  Future<List<Object?>> Function() read, {
  required String describe,
}) async {
  final result = await read();
  expect(
    result,
    isEmpty,
    reason:
        '$describe must degrade to an empty list while no account/profile is '
        'active — returning null or throwing would break callers that render '
        'a list directly.',
  );
}

/// Asserts a nullable read degrades to `null` while the adapter is not
/// ready, matching `repository_providers.dart`'s own null-means-not-ready
/// convention.
Future<void> expectNullWhenNotReady(
  Future<Object?> Function() read, {
  required String describe,
}) async {
  expect(
    await read(),
    isNull,
    reason:
        '$describe must degrade to null while no account/profile is active, '
        'so existing null-means-loading UI keeps working unmodified.',
  );
}

/// Asserts a write throws rather than silently succeeding while the adapter
/// is not ready.
///
/// A silent no-op on a write looks like success to the user and loses their
/// data, which is why every adapter throws here instead of degrading.
Future<void> expectThrowsWhenNotReady(
  Future<void> Function() write, {
  required String describe,
  required Matcher isExpectedException,
}) async {
  await expectLater(
    write(),
    throwsA(isExpectedException),
    reason:
        '$describe must throw while no account/profile is active — silently '
        'discarding a user write would look like success.',
  );
}
