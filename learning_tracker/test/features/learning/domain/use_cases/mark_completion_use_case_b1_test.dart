/// B1 three-tier completion credit policy — 3×3 matrix regression suite.
///
/// Verifies that [CompletionSource] correctly gates which side-effect tiers
/// fire for each source variant.
///
/// ### The 3×3 matrix
///
/// ```
/// Source        | creditsEngagement | creditsAchievement | creditsLifetime
/// ──────────────┼───────────────────┼────────────────────┼────────────────
/// live          |        ✓          |         ✓          |       ✓
/// bulkInTrack   |        ✗          |         ✓          |       ✓
/// lifetimeOnly  |        ✗          |         ✗          |       ✓
/// ```
///
/// These are **pure predicate tests** — they only import [CompletionSource]
/// (no DB, no Flutter, no Riverpod, no Drift). The routing tests for
/// [MarkCompletionUseCase] require a live DB to construct a [Completion] row
/// and are deferred until the cross-stream [user_database.g.dart] conflicts
/// are resolved by the build_runner re-run (P4 sync-point). Until then the
/// policy correctness is fully covered by the 9 predicate tests below.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_source.dart';

void main() {
  // ── CompletionSourceX — 3×3 matrix (pure predicate tests) ─────────────────
  //
  // Each cell of the 3×3 matrix is an individual test so failures are
  // precisely identified. Total: 9 tests (3 sources × 3 tiers).
  group('CompletionSourceX — tier predicates (3×3 matrix)', () {
    // ── Row: live ─────────────────────────────────────────────────────────────
    test('[live] creditsEngagement = true', () {
      expect(CompletionSource.live.creditsEngagement, isTrue);
    });
    test('[live] creditsAchievement = true', () {
      expect(CompletionSource.live.creditsAchievement, isTrue);
    });
    test('[live] creditsLifetime = true', () {
      expect(CompletionSource.live.creditsLifetime, isTrue);
    });

    // ── Row: bulkInTrack ──────────────────────────────────────────────────────
    test('[bulkInTrack] creditsEngagement = false', () {
      expect(CompletionSource.bulkInTrack.creditsEngagement, isFalse);
    });
    test('[bulkInTrack] creditsAchievement = true', () {
      expect(CompletionSource.bulkInTrack.creditsAchievement, isTrue);
    });
    test('[bulkInTrack] creditsLifetime = true', () {
      expect(CompletionSource.bulkInTrack.creditsLifetime, isTrue);
    });

    // ── Row: lifetimeOnly ─────────────────────────────────────────────────────
    test('[lifetimeOnly] creditsEngagement = false', () {
      expect(CompletionSource.lifetimeOnly.creditsEngagement, isFalse);
    });
    test('[lifetimeOnly] creditsAchievement = false', () {
      expect(CompletionSource.lifetimeOnly.creditsAchievement, isFalse);
    });
    test('[lifetimeOnly] creditsLifetime = true', () {
      expect(CompletionSource.lifetimeOnly.creditsLifetime, isTrue);
    });
  });

  // ── Tier invariants ────────────────────────────────────────────────────────
  group('CompletionSourceX — structural invariants', () {
    test('creditsLifetime is always true for all sources', () {
      // Lifetime tier must never be gated — all completions enter history.
      for (final source in CompletionSource.values) {
        expect(
          source.creditsLifetime,
          isTrue,
          reason: '$source must always credit lifetime',
        );
      }
    });

    test('creditsEngagement ⊆ creditsAchievement '
        '(engagement implies achievement)', () {
      // No source should credit engagement without also crediting achievement.
      for (final source in CompletionSource.values) {
        if (source.creditsEngagement) {
          expect(
            source.creditsAchievement,
            isTrue,
            reason:
                '$source credits engagement but not achievement — '
                'violates the tier hierarchy',
          );
        }
      }
    });

    test('exactly one source (live) credits engagement', () {
      final engagementSources = CompletionSource.values
          .where((s) => s.creditsEngagement)
          .toList();
      expect(engagementSources, [
        CompletionSource.live,
      ], reason: 'Only live completions must credit engagement');
    });

    test('live and bulkInTrack credit achievement; lifetimeOnly does not', () {
      expect(CompletionSource.live.creditsAchievement, isTrue);
      expect(CompletionSource.bulkInTrack.creditsAchievement, isTrue);
      expect(CompletionSource.lifetimeOnly.creditsAchievement, isFalse);
    });
  });
}
