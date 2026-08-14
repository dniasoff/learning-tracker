/// Legacy integration-case manifest for Bugs B6/B8 and Finding 8.
///
/// RETIRED-IMPLEMENTATION DISCLOSURE (2026-08-14): the old cases exercised
/// `UserDatabase`, `completion_events`, `prior_completion_imports`, integer
/// profile FKs, and `CompletionWriter`. Those local Drift mechanisms are gone.
/// Current production is the Firestore-native `CompletionRepository` contract
/// in `lib/features/learning/domain/repositories/completion_repository.dart`
/// and `BulkPriorCompletionService` in
/// `lib/features/onboarding/domain/services/bulk_prior_completion_service.dart`.
/// The equivalent B6/B8 behavior is covered at that current seam by
/// `test/features/onboarding/domain/services/bulk_prior_completion_service_test.dart`.
/// These named cases remain registered below so no coverage case disappears
/// silently; each skip identifies exactly which old local premise is gone.
library;

import 'package:test/test.dart';

void _retired(String reason) => markTestSkipped('RETIRED-LOCAL-DRIFT: $reason');

void main() {
  group('B6 — execute writes all configured stages for prior-marked items', () {
    test(
      'AC1: 2 items × 3 configured stages → 6 completion_events rows even when caller passes stageIds: [1]',
      () {
        // Per-case disclosure: `completion_events` rows and the local DB
        // constructor were removed. Current B6 equivalent: bulk_prior_completion_service_test.dart, B6 group.
        _retired('The assertion is migrated to the repository-seam B6 tests; local completion_events rows no longer exist.');
      },
    );
    test(
      'AC2: completion_events for all stages carry the sentinel timestamp (DateTime.utc(2000, 1, 1)) — not today',
      () {
        // Per-case disclosure: sentinel timestamps are now `CompletionEntity.completedAt` in Firestore, not Drift rows.
        _retired('The old row-level timestamp assertion has no local table to inspect; current sentinel behavior is owned by BulkPriorCompletionService.execute.');
      },
    );
  });

  group('B8 — expungePriorCompletions tombstones only sentinel-dated rows', () {
    test(
      'AC1: sets purgedAt on all sentinel-dated rows for the given sefariaRef',
      () {
        // Per-case disclosure: current B8 identifies `CompletionSource.bulkInTrack` documents, not sentinel-dated Drift rows.
        _retired('The equivalent current purge assertion is in bulk_prior_completion_service_test.dart; prior_completion_imports was deleted.');
      },
    );
    test('AC2: does NOT touch rows for a different sefariaRef', () {
      // Per-case disclosure: the old cross-ref row scan was a local-DB detail; Firestore filtering is tested at the current repository seam.
      _retired('The old completion_events/prior_completion_imports fixture has no current table equivalent.');
    });
    test('AC3: does NOT touch live-learning rows (non-sentinel timestamp) for the same sefariaRef', () {
      // Per-case disclosure: live-vs-prior is now `source == live` versus `bulkInTrack`, per BulkPriorCompletionService.expungePriorCompletions.
      _retired('The timestamp-based local assertion is replaced by current source/provenance coverage.');
    });
    test('AC4: expunge is idempotent — calling twice does not throw and purgedAt remains set', () {
      // Per-case disclosure: idempotency now belongs to Firestore tombstones and the D-M ledger epoch rule.
      _retired('The current idempotency coverage is in bulk_prior_completion_service_test.dart; the old Drift purgedAt row is retired.');
    });
    test('AC5: expunge on a sefariaRef with no prior rows is a no-op (does not throw)', () {
      // Per-case disclosure: no-prior-row is no longer a query against `prior_completion_imports`.
      _retired('The old local no-op premise is retired; current expunge requires its Firestore retraction collaborators.');
    });
    test('AC6: does NOT touch rows belonging to a different profileId', () {
      // Per-case disclosure: integer profileId isolation was replaced by the active Firestore profile/session scope.
      _retired('The integer profile-FK fixture cannot be migrated without inventing a second current session.');
    });
  });

  group('Finding 8 — per-curriculum expunge isolation', () {
    test('Test 1: untick under curriculum A leaves curriculum B completions intact', () {
      // Per-case disclosure: old per-curriculum Drift rows are not the current storage model.
      _retired('Current curriculum isolation is expressed by CompletionRepository.purgeCompletion(curriculumId: ...), covered by the current service tests.');
    });
    test('Test 2: prior-marking under both A and B creates separate active rows', () {
      // Per-case disclosure: separate active `completion_events` rows were an implementation detail of UserDatabase.
      _retired('The current Firestore document identity and curriculum field replace the old two-track local fixture.');
    });
    test('Test 3: untick leaves live-learning row intact (non-sentinel timestamp)', () {
      // Per-case disclosure: this case depended on the deleted sentinel timestamp convention.
      _retired('Current source filtering is covered in bulk_prior_completion_service_test.dart; no local row remains to inspect.');
    });
    test(
      'Test 4 (live-learning row survival): prior-mark then real-learning then expunge — row must survive because priorMarkOnly is upgraded to false',
      () {
        // Per-case disclosure: `priorMarkOnly`/CompletionWriter upgrade logic was deleted; Firestore uses immutable source/provenance documents.
        _retired('The old upgrade premise has no current Firestore-native equivalent in this integration fixture.');
      },
    );
  });
}
