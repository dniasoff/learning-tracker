import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart';
import 'package:learning_tracker/features/learning/domain/services/completion_orchestrator.dart';

/// Records "this profile studied today" as a `streak_events` document.
///
/// ## Idempotent by construction — and it genuinely was not before
///
/// The document id is derived from the study day itself, NOT from a random
/// ULID. Two marks on the same local day — from a second device, a retried
/// write, or an offline write replaying on reconnect — resolve to the SAME
/// document, so the streak cannot be double-counted.
///
/// The predecessor claimed this property in a comment while calling
/// `newUlid(at)`, which is random beyond its timestamp prefix: two calls
/// produced two documents and duplicates never collapsed. The comment described
/// behaviour the code did not have.
///
/// ## Why it is a tee, and why it swallows
///
/// A streak is derived telemetry, not the completion itself. A failure here must
/// never block or roll back the primary completion write, so every exception is
/// logged rather than rethrown — see `CompletionRepositoryImpl
/// ._appendStreakEvent`'s original reasoning (AUD-learning-06 / EH-3 / EH-4).
/// The narrow `on Exception` is deliberate: an `Error` is a programming bug and
/// must keep propagating.
class FirestoreCompletionStreakRecorder implements CompletionStreakPort {
  /// Takes [Ref] rather than a repository instance so that presentation code
  /// constructing this never has to name a data-access-ring type — AD-23/AD-28
  /// forbid `features/**/presentation/**` importing that ring, and this class
  /// lives under `data/repositories/`, which the check exempts.
  FirestoreCompletionStreakRecorder({required Ref ref}) : _ref = ref;

  final Ref _ref;

  /// Stable document id for one study day.
  ///
  /// The collection is already profile-scoped by its path, so the day and the
  /// event type are the whole natural key. Deliberately contains no random
  /// component and no sub-day precision — either would defeat the point.
  static String studyDayDocId({
    required String eventType,
    required DateTime dayUtc,
  }) {
    final y = dayUtc.year.toString().padLeft(4, '0');
    final m = dayUtc.month.toString().padLeft(2, '0');
    final d = dayUtc.day.toString().padLeft(2, '0');
    return '${eventType}_$y$m$d';
  }

  @override
  Future<void> recordStudyDay({
    required int profileId,
    required DateTime at,
  }) async {
    try {
      final repository = await _ref.read(
        firestoreStreakEventRepositoryProvider.future,
      );
      if (repository == null) {
        // No active account/profile: there is nothing to record against. This
        // is a telemetry tee, so it stays silent rather than throwing — the
        // completion write itself is unaffected.
        return;
      }
      final dayUtc = DateTime.utc(at.year, at.month, at.day);
      // `eventTimestamp` is the normalised DAY, not the instant `at`.
      //
      // The deterministic doc id makes the second mark of a day an UPDATE, and
      // `streak_events` permits an update only when the payload is unchanged
      // (`firestore.rules` SR-1, `request.resource.data == resource.data`).
      // Sending the instant would make each mark's payload differ, so the
      // write would be DENIED — silently, since this tee swallows. Sending the
      // day makes every same-day write byte-identical, which is exactly the
      // idempotent re-push SR-1 exists to allow.
      //
      // No precision is lost that this tee uses: the doc id is already
      // day-granular and it answers only "did this profile study today".
      await repository.append(
        eventType: 'completion',
        eventTimestamp: dayUtc,
        ulid: studyDayDocId(eventType: 'completion', dayUtc: dayUtc),
      );
    } on Exception catch (e, stackTrace) {
      // Logged, never rethrown: this telemetry tee must not roll back the
      // completion write it hangs off.
      AppLogger.instance.error(
        event: 'completion_streak_tee_failed',
        fields: {'profileId': profileId},
        exception: e,
        stackTrace: stackTrace,
      );
    }
  }
}
