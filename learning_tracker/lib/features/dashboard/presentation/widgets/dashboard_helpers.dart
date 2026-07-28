import 'package:flutter/material.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/features/scheduler/scheduler.dart';

/// Color constants shared across dashboard widgets.

/// Primary blue for active-track CTA (design spec).
Color kActiveTrackPrimaryBlue(BuildContext context) => context.colors.brandBlue;

/// Green completion bar (self-paced card).
Color kActiveTrackCompletionGreen(BuildContext context) =>
    context.colors.statusSuccess;

/// Grey pill behind next-task / current-focus content.
Color kActiveTrackFocusPillBg(BuildContext context) =>
    context.colors.brandCreamSoft;

/// Lifetime bar on the "all caught up" dashboard stats card (design spec).
///
/// AUD-dashboard-darkmode: this progress-bar FILL sits on the card's own
/// blue gradient (`blueMedium`/`blueLight`/`blueDeepNavy`), which STAYS a
/// deep, saturated blue in both themes (hero-fill role — see those tokens'
/// doc comments). [goldTrophy] darkens to a near-brown in dark mode — right
/// for ink on a FIXED WHITE surface, but on this coloured card it measures
/// ~1.29:1 against the card's dark-navy track (WCAG non-text needs ≥3:1) —
/// the fill was effectively invisible. [goldOnColouredSurface] is the token
/// already split out for exactly this "ink/fill painted on a surface that
/// stays coloured" role (see `dashboard_level_points_card.dart`, which uses
/// it for its own sibling lifetime-progress fill) — ~11.96:1 on this card
/// once used here. Light mode is pixel-identical: both tokens' light value
/// is `0xFFFFC94A`.
Color kAllCaughtUpProgressFill(BuildContext context) =>
    context.colors.goldOnColouredSurface;

/// Child dashboard — points & rewards hero (design spec).
Color kChildRewardsCardBlueTop(BuildContext context) =>
    context.colors.blueMedium;
Color kChildRewardsCardBlueDeep(BuildContext context) =>
    context.colors.blueDeepNavy;
Color kChildRewardsProgressTrack(BuildContext context) =>
    context.colors.blueNavy;
Color kChildRewardsProgressFill(BuildContext context) =>
    context.colors.statusSuccess;

class DashboardTaskGroups {
  const DashboardTaskGroups({
    required this.todayTasks,
    required this.overdueTasks,
    required this.reviewTasks,
  });

  final List<DailyTask> todayTasks;
  final List<DailyTask> overdueTasks;
  final List<DailyTask> reviewTasks;
}

DashboardTaskGroups groupTasks(List<DailyTask> tasks) {
  final todayTasks = <DailyTask>[];
  final overdueTasks = <DailyTask>[];
  final reviewTasks = <DailyTask>[];

  bool isReview(DailyTask task) =>
      task.priority == DailyTaskPriority.overdueChazara ||
      task.priority == DailyTaskPriority.scheduledChazara;

  for (final task in tasks) {
    if (isReview(task)) {
      reviewTasks.add(task);
      continue;
    }

    if (task.isOverdue) {
      overdueTasks.add(task);
      continue;
    }

    todayTasks.add(task);
  }

  return DashboardTaskGroups(
    todayTasks: todayTasks,
    overdueTasks: overdueTasks,
    reviewTasks: reviewTasks,
  );
}

class TrackTaskBuckets {
  const TrackTaskBuckets({
    required this.missedProgram,
    required this.dueTodayLane,
    required this.review,
  });

  /// Missed program days (non-review overdue), aligned with dashboard lanes.
  final List<DailyTask> missedProgram;

  /// On-time program + new learning (not chazara).
  final List<DailyTask> dueTodayLane;

  /// All chazara / review tasks for this track.
  final List<DailyTask> review;

  int get total => missedProgram.length + dueTodayLane.length + review.length;
}

TrackTaskBuckets bucketTrackTasks(List<DailyTask> tasks) {
  final missedProgram = <DailyTask>[];
  final dueTodayLane = <DailyTask>[];
  final review = <DailyTask>[];

  bool isReview(DailyTask t) =>
      t.priority == DailyTaskPriority.overdueChazara ||
      t.priority == DailyTaskPriority.scheduledChazara;

  for (final t in tasks) {
    if (isReview(t)) {
      review.add(t);
    } else if (t.isOverdue) {
      missedProgram.add(t);
    } else {
      dueTodayLane.add(t);
    }
  }

  return TrackTaskBuckets(
    missedProgram: missedProgram,
    dueTodayLane: dueTodayLane,
    review: review,
  );
}

/// Task to highlight on the active-track card for calendar-linked programs.
///
/// [allTasks] is sorted with [DailyTaskPriority.overdueProgram] before
/// [DailyTaskPriority.todayProgram], so the first row is backlog — not
/// "today's" assignment. Prefer an explicit today row when present.
DailyTask? programTrackFocusTask(List<DailyTask> tasks) {
  if (tasks.isEmpty) return null;
  for (final t in tasks) {
    if (t.priority == DailyTaskPriority.todayProgram) return t;
  }
  return tasks.first;
}

/// Breadcrumb segment separator emitted by the curriculum-label renderer
/// (space + U+203A + space).
const String kBreadcrumbSep = ' › ';

/// Drops the top-level seder segment from a breadcrumb string so the
/// curriculum chip (already visible above the active-track pill) is not
/// duplicated in the pill.
///
/// The breadcrumb separator produced by `renderedDisplayForRef` is
/// [kBreadcrumbSep] (space + U+203A + space). When there are 2+ segments,
/// the first is removed. Single-segment labels (e.g. a top-level tractate
/// with no sub-units) are returned unchanged.
///
/// Example: "קודשים › חולין › דף יד › עמוד א" → "חולין › דף יד › עמוד א"
///
/// Public (not `active_track_card.dart`-private) so it can be exercised
/// directly by unit tests instead of via a hand-copied mirror
/// (AUD-t-story-acceptance-19).
String trimSederFromBreadcrumb(String breadcrumb) {
  final idx = breadcrumb.indexOf(kBreadcrumbSep);
  if (idx == -1) return breadcrumb; // single segment — nothing to trim
  return breadcrumb.substring(idx + kBreadcrumbSep.length);
}

/// Collapses a full amud/verse breadcrumb to its day-level unit.
///
/// A Daf-Yomi day is a whole daf (both amudim), so the leaf "עמוד א" /
/// "Amud A" segment is noise — drop it so the pill reads "חולין › דף כה"
/// rather than "חולין › דף כה › עמוד א". Used only as the *fallback* when the
/// seed day-level label is missing; the seeded label is preferred.
///
/// Heuristic: when the last breadcrumb segment is an amud leaf (the renderer
/// marks amudim as "עמוד …"/"Amud …"), strip it. Otherwise the breadcrumb is
/// left untouched (already daf / perek / mishna level).
String collapseAmudToDaf(String breadcrumb) {
  final segments = breadcrumb.split(kBreadcrumbSep);
  if (segments.length < 2) return breadcrumb;
  final last = segments.last.trim();
  final isAmudLeaf =
      last.startsWith('עמוד') || last.toLowerCase().startsWith('amud');
  if (!isAmudLeaf) return breadcrumb;
  return segments.sublist(0, segments.length - 1).join(kBreadcrumbSep);
}

/// Numeric sort key for a canonical Sefaria ref so a self-paced day's refs can
/// be ordered ascending (chapter, then verse/segment) before being collapsed
/// into a range label.
///
/// Sefaria refs are canonical English with numeric components separated by
/// `:`, `.` or spaces (e.g. "Genesis 1:7", "Genesis 1.7", "Kelim 5:7"). This
/// extracts every numeric run and returns it as an ordered list so two refs
/// can be compared component-by-component. Non-numeric prefixes (the book
/// name) are ignored, so the ordering is locale-independent — it never depends
/// on the rendered Hebrew/English display string, which is not numerically
/// sortable.
List<int> sefariaRefSortKey(String ref) {
  final matches = RegExp(r'\d+').allMatches(ref);
  return [for (final m in matches) int.parse(m.group(0)!)];
}

/// Compares two Sefaria refs by their numeric components (chapter, verse, …).
///
/// Used to sort a self-paced day's tasks ascending so the collapsed range
/// label always reads low → high (e.g. "Pasuk 6 – Pasuk 7"), never reversed,
/// regardless of the order the tasks arrive in.
int compareSefariaRefs(String a, String b) {
  final ka = sefariaRefSortKey(a);
  final kb = sefariaRefSortKey(b);
  final n = ka.length < kb.length ? ka.length : kb.length;
  for (var i = 0; i < n; i++) {
    final c = ka[i].compareTo(kb[i]);
    if (c != 0) return c;
  }
  // Shared prefix equal — shorter ref (fewer components) sorts first, then
  // fall back to a stable lexical compare on the raw ref.
  final lc = ka.length.compareTo(kb.length);
  return lc != 0 ? lc : a.compareTo(b);
}

/// Collapses a set of rendered refs into a single first–last range label.
///
/// For a self-paced multi-unit day, render "<first> – <last>" using the leaf
/// segment of each end so the pill reads e.g. "משנה ה׳ – משנה ט׳" rather than
/// listing every ref or showing only the first. A single ref (or all-equal
/// leaves) is returned unchanged.
///
/// The caller is responsible for passing the rendered refs already ordered
/// ascending (see [compareSefariaRefs]); the endpoints are taken as the
/// first and last entries.
String collapseRefRange(List<String> rendered) {
  final cleaned = rendered.where((r) => r.trim().isNotEmpty).toList();
  if (cleaned.isEmpty) return '';
  if (cleaned.length == 1) return cleaned.first;
  String leaf(String b) => b.split(kBreadcrumbSep).last.trim();
  final first = leaf(cleaned.first);
  final last = leaf(cleaned.last);
  if (first == last) return cleaned.first;
  return '$first – $last';
}

/// Seed-sourced day-level unit label for [task] respecting Hebrew terms.
///
/// Returns the collapsed, type-aware unit name ("חולין דף כ״ה" / "Chullin 25",
/// "כלים 5:7-8") that was attached at generation time from the calendar seed,
/// or null when the task carries no day-level label (self-paced, or a program
/// whose seed lacked one — the caller then falls back to the breadcrumb
/// renderer). Mirrors how [renderedDisplayForRef] picks the locale: Hebrew
/// label in Hebrew-terms mode, English otherwise.
String? programUnitDayLabel(DailyTask task, {required bool useHebrew}) {
  if (useHebrew) {
    final he = task.unitDisplayHe;
    if (he != null && he.isNotEmpty) return he;
    final en = task.unitDisplayEn;
    return (en != null && en.isNotEmpty) ? en : null;
  }
  final en = task.unitDisplayEn;
  if (en != null && en.isNotEmpty) return en;
  final he = task.unitDisplayHe;
  return (he != null && he.isNotEmpty) ? he : null;
}
