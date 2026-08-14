/// Legacy acceptance-case manifest for Epic 25, Story 25.12.
///
/// RETIRED-ARCHITECTURE DISCLOSURE (2026-08-14): the imported
/// `core/sync/firestore_gateway.dart`, `pull_pipeline.dart`, and
/// `push_pipeline_impl.dart` do not exist in current production. The current
/// codebase has direct Firestore repositories under `lib/data/repositories/`
/// and documents the deleted listener/push machinery in
/// `lib/data/firestore/resilient_doc_stream.dart`. There is no current
/// `OutboxPushPipeline`, `PullPipeline`, `FirestorePage`, `MergeDispatcher`,
/// or `MergeOutcome` equivalent to test. Each original case remains below by
/// name with a specific disclosure; no pipeline assertion is silently dropped.
@Tags(['epic_25'])
library;

import 'package:test/test.dart';

void _retired(String reason) => markTestSkipped('RETIRED-SYNC-PIPELINE: $reason');

void main() {
  group('Story 25.12 — SyncEngine decomp Part 1', tags: ['story_25_12'], () {
    test(
      'firestore_gateway_impl.dart is the canonical importer; no new leaks outside the documented transition allowlist',
      () {
        // Per-case disclosure: the canonical gateway file named by this test
        // is absent; current imports are intentionally distributed through
        // data/firestore and data/repositories.
        _retired('The old importer-quarantine contract no longer describes the current repository architecture.');
      },
    );

    group('OutboxPushPipeline single-flight', () {
      test('overlapping calls for the same entity kind are serialized', () {
        // Per-case disclosure: the local outbox and its per-kind single-flight
        // pipeline were deleted; current writes go directly to Firestore.
        _retired('No current OutboxPushPipeline or Firestore-native equivalent exists.');
      });
      test('different entity kinds may push concurrently', () {
        // Per-case disclosure: this asserted concurrency between deleted
        // outbox push lanes.
        _retired('No current push-lane abstraction remains to migrate.');
      });
      test('failing push releases the single-flight slot for the next call', () {
        // Per-case disclosure: retry-slot behavior belonged to the deleted
        // outbox processor, not to a current Firestore repository method.
        _retired('No current Firestore-native equivalent exposes this slot.');
      });
    });

    group('PullPipeline pagination + dispatch', () {
      test('paginates through the gateway and dispatches each page to MergeDispatcher', () {
        // Per-case disclosure: `PullPipeline`, `FirestorePage`, and
        // `MergeDispatcher` were all deleted with the merge engine.
        _retired('Current repositories own their Firestore reads; no shared pull/merge dispatcher exists.');
      });
      test('pull stops cleanly when the dispatcher signals halt', () {
        // Per-case disclosure: the halt signal was part of deleted pull/merge
        // orchestration.
        _retired('No current dispatcher or halt contract exists.');
      });
      test(
        'AUD-core-analytics-01 (PV-1): merge_router_halt analytics fires without a profile_id',
        () {
          // Per-case disclosure: `AnalyticsEvent.syncMergeRouterHalt` remains
          // catalogued, but no current producer named merge_router_halt exists
          // after the pull/merge engine removal.
          _retired('The old analytics acceptance premise has no live producer to exercise.');
        },
      );
    });
  });
}
