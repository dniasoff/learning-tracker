/// Tests for [BatchPlan] sealed type — W4.25 regression suite.
///
/// Verifies that [BatchPlan.classify] correctly creates the right plan type
/// for each [CompletionSource], and that the credit-tier predicates delegate
/// correctly to [CompletionSourceX].
///
/// Pure tests — no DB, no Flutter, no Riverpod.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/learning/domain/entities/batch_plan.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_source.dart';

// ── Helpers ──────────────────────────────────────────────────────────────────

// BatchPlan only stores commands; CompletionCommand requires a Freezed import
// that transitions through broken user_database.g.dart — avoid instantiating
// real commands here. Pass an empty list; the classification logic is
// independent of command content.
const _kEmptyCommands = <dynamic>[];

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  // ── BatchPlan.classify factory ────────────────────────────────────────────
  group('BatchPlan.classify', () {
    test('live source → LiveBatchPlan', () {
      final plan = BatchPlan.classify(
        commands: const [],
        source: CompletionSource.live,
      );
      expect(plan, isA<LiveBatchPlan>());
    });

    test('bulkInTrack source → BulkInTrackPlan', () {
      final plan = BatchPlan.classify(
        commands: const [],
        source: CompletionSource.bulkInTrack,
      );
      expect(plan, isA<BulkInTrackPlan>());
    });

    test('lifetimeOnly source → LifetimeOnlyPlan', () {
      final plan = BatchPlan.classify(
        commands: const [],
        source: CompletionSource.lifetimeOnly,
      );
      expect(plan, isA<LifetimeOnlyPlan>());
    });

    test('classify round-trips source through plan.source', () {
      for (final source in CompletionSource.values) {
        final plan = BatchPlan.classify(commands: const [], source: source);
        expect(
          plan.source,
          source,
          reason: '$source must round-trip through BatchPlan.classify',
        );
      }
    });
  });

  // ── Credit-tier predicates ────────────────────────────────────────────────
  group('BatchPlan credit-tier predicates', () {
    test('LiveBatchPlan: all tiers enabled', () {
      final plan = const LiveBatchPlan(commands: []);
      expect(plan.creditsEngagement, isTrue);
      expect(plan.creditsAchievement, isTrue);
      expect(plan.creditsLifetime, isTrue);
    });

    test(
      'BulkInTrackPlan: engagement suppressed; achievement + lifetime enabled',
      () {
        final plan = const BulkInTrackPlan(commands: []);
        expect(plan.creditsEngagement, isFalse);
        expect(plan.creditsAchievement, isTrue);
        expect(plan.creditsLifetime, isTrue);
      },
    );

    test('LifetimeOnlyPlan: only lifetime enabled', () {
      final plan = const LifetimeOnlyPlan(commands: []);
      expect(plan.creditsEngagement, isFalse);
      expect(plan.creditsAchievement, isFalse);
      expect(plan.creditsLifetime, isTrue);
    });

    test('creditsLifetime always true for all plan types (invariant)', () {
      for (final source in CompletionSource.values) {
        final plan = BatchPlan.classify(commands: const [], source: source);
        expect(
          plan.creditsLifetime,
          isTrue,
          reason: '$source plan must always credit lifetime',
        );
      }
    });
  });

  // ── Pattern-matching exhaustiveness ──────────────────────────────────────
  group('BatchPlan sealed exhaustiveness', () {
    test('switch exhausts all cases without default', () {
      // This test compiles only if Dart can verify exhaustiveness — if a new
      // leaf is added to [BatchPlan] without updating this switch the
      // compile-time warning turns the test red.
      for (final source in CompletionSource.values) {
        final plan = BatchPlan.classify(commands: const [], source: source);
        // Pattern-match all leaves — if any are missing the analyzer warns.
        final label = switch (plan) {
          LiveBatchPlan() => 'live',
          BulkInTrackPlan() => 'bulk',
          LifetimeOnlyPlan() => 'lifetime',
        };
        expect(label, isNotEmpty);
      }
    });
  });

  // ── toString ──────────────────────────────────────────────────────────────
  group('BatchPlan.toString', () {
    test('LiveBatchPlan toString includes count', () {
      expect(const LiveBatchPlan(commands: []).toString(), contains('0'));
    });

    test('BulkInTrackPlan toString mentions bulk', () {
      expect(
        const BulkInTrackPlan(commands: []).toString(),
        contains('BulkInTrackPlan'),
      );
    });

    test('LifetimeOnlyPlan toString mentions lifetime', () {
      expect(
        const LifetimeOnlyPlan(commands: []).toString(),
        contains('LifetimeOnlyPlan'),
      );
    });
  });
}
