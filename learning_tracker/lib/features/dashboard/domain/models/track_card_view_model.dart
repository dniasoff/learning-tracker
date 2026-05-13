import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/dashboard/domain/models/calendar_position.dart';
import 'package:learning_tracker/features/dashboard/domain/models/chazara_status.dart';
import 'package:learning_tracker/features/dashboard/domain/models/momentum_status.dart';
import 'package:learning_tracker/features/dashboard/domain/models/track_progress.dart';
import 'package:learning_tracker/features/scheduler/domain/models/pace_status.dart';

part 'track_card_view_model.freezed.dart';

/// The 4 data shapes a track card can render.
///
/// Matches the permutation matrix in the redesign analysis:
///   [programCalendar] — track enrolled in a calendar program (Daf Yomi, etc.)
///   [deadlineGoal]    — self-paced track with a finish-by-date goal
///   [velocityGoal]    — self-paced track with a completions-per-day goal
///   [momentum]        — self-paced track with no explicit goal
///
/// This re-exports [TrackProgressVariant] for convenience so widgets only
/// need to import this file.
typedef TrackCardShape = TrackProgressVariant;

/// Data for the breadcrumb shown in [NextTaskBreadcrumb].
///
/// The label is the human-readable path to the next task
/// (e.g. "Shabbos · Perek 1 · Mishna 3"). [sefariaRef] drives navigation.
@freezed
abstract class NextTaskData with _$NextTaskData {
  const factory NextTaskData({
    /// Rendered display label (respects Hebrew Terms toggle).
    required String displayLabel,

    /// Sefaria ref for navigation — null when nothing is queued.
    String? sefariaRef,

    /// True when this comes from a calendar-program (vs. self-paced) queue.
    @Default(false) bool isProgram,
  }) = _NextTaskData;
}

/// Data for the [LifetimeLearningLine] row.
@freezed
abstract class LifetimeLearningData with _$LifetimeLearningData {
  const factory LifetimeLearningData({
    /// Fraction learned (0.0–1.0).
    required double fraction,

    /// Pre-formatted percentage string (e.g. "37%"). Null while loading.
    String? displayPercent,

    /// True when the entire curriculum has been completed.
    required bool isComplete,
  }) = _LifetimeLearningData;
}

/// Composed view model for the entire [TrackCard] widget tree.
///
/// One [TrackCardViewModel] drives [TrackCard] and all 5 sub-widgets:
///   • [TrackCardHeader]      — displayNamePrimary / displayNameSecondary / icon
///   • [NextTaskBreadcrumb]   — nextTask breadcrumb + label
///   • [TrackStatGrid]        — three stat buckets (review / today / overdue)
///   • [LifetimeLearningLine] — lifetime fraction + completion icon
///   • [TrackContinueButton]  — CTA that navigates to sefariaRef or fallback
///
/// All four shapes ([TrackCardShape]) render through the same widget tree;
/// shape-specific fields are in the corresponding optional sub-objects.
@freezed
abstract class TrackCardViewModel with _$TrackCardViewModel {
  const factory TrackCardViewModel({
    // ── Identity ─────────────────────────────────────────────────────────────
    required int trackId,
    required CurriculumId curriculumId,

    /// Which of the four data shapes this card represents.
    required TrackCardShape shape,

    // ── Header ───────────────────────────────────────────────────────────────
    /// Primary label: "{TrackType} · {CurriculumName}"
    required String displayNamePrimary,

    /// Secondary label (Hebrew name). Null when Hebrew Terms toggle is on
    /// and the primary is already in Hebrew.
    String? displayNameSecondary,

    /// Accent colour derived from the curriculum (for the book-icon circle).
    required int curriculumColorValue,

    // ── Breadcrumb ───────────────────────────────────────────────────────────
    required NextTaskData nextTask,

    /// UI label above the breadcrumb ("NEXT TASK" / "CURRENT FOCUS").
    required String breadcrumbLabel,

    // ── Stat grid ────────────────────────────────────────────────────────────
    /// Count of review (chazara) tasks due.
    required int reviewCount,

    /// Count of new-learning / on-time program tasks.
    required int dueTodayCount,

    /// Count of overdue / missed tasks.
    required int overdueCount,

    /// Human-readable label for the review (chazara) column.
    required String chazaraLabel,

    // ── Lifetime learning ────────────────────────────────────────────────────
    required LifetimeLearningData lifetime,

    // ── Shape-specific optional fields ───────────────────────────────────────
    /// Populated for [TrackCardShape.programCalendar].
    CalendarPosition? calendarPos,

    /// Populated for [TrackCardShape.deadlineGoal] and
    /// [TrackCardShape.velocityGoal].
    PaceStatus? paceStatus,

    /// Populated for [TrackCardShape.momentum].
    MomentumStatus? momentum,

    /// Populated for any shape when chazara stages are configured.
    ChazaraStatus? chazaraStatus,

    // ── Empty-queue hint ─────────────────────────────────────────────────────
    /// Shown below the stat grid when the queue is empty.
    /// Null when there are tasks queued.
    String? emptyQueueHint,
  }) = _TrackCardViewModel;

  /// Total tasks across all buckets.
  const TrackCardViewModel._();
  int get totalTasks => reviewCount + dueTodayCount + overdueCount;
}
