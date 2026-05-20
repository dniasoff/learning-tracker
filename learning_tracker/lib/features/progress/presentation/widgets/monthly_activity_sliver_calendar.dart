import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Pure-Dart companion value object for the Drift-generated
/// [MonthlyActivityRollup] row class.
///
/// This mirrors the shape of the `monthly_activity_rollups` table
/// (`lib/core/database/tables/monthly_activity_rollups.dart`) without
/// requiring code generation, so the spike widget and its tests compile without
/// running `build_runner`. When the table is wired into [UserDatabase] and
/// `build_runner` generates the companion, replace usages of this class with
/// the generated one.
class MonthlyActivityRollup {
  const MonthlyActivityRollup({
    required this.profileId,
    required this.yearMonth,
    required this.activeDays,
    required this.totalCompletions,
    required this.totalChazaros,
    this.firstActivityDate,
    this.lastActivityDate,
    required this.activeDaysList,
  });

  final int profileId;

  /// ISO month string, e.g. `'2026-05'`.
  final String yearMonth;

  /// Number of distinct calendar days with at least one live completion.
  final int activeDays;

  /// Total live completions (stage 1) in this month.
  final int totalCompletions;

  /// Total chazara completions (stage > 1) in this month.
  final int totalChazaros;

  /// UTC timestamp of the earliest completion in this month (nullable).
  final DateTime? firstActivityDate;

  /// UTC timestamp of the most recent completion in this month (nullable).
  final DateTime? lastActivityDate;

  /// Space-separated day numbers with activity, e.g. `'1 4 15 28'`.
  final String activeDaysList;
}

/// Spike prototype — virtualized monthly activity calendar.
///
/// Replaces the flat [StreakCalendar] widget for "All Time" ranges.
/// Instead of building one Flutter widget per day (which freezes the device
/// when the range is ~9 000 days), this widget:
///
///   - Accepts a pre-aggregated [List<MonthlyActivityRollup>] (one row per
///     month from the `monthly_activity_rollups` Drift table).
///   - Renders a [CustomScrollView] so off-screen months are never built.
///   - For each month shows a sticky header (month name + active-day count)
///     and a compact summary card by default.
///   - Tapping a month's header/card **expands** it into a full 7-column
///     daily grid for that month only — keeping the widget count bounded
///     at max 31 cells per expanded month.
///
/// ## Spike status
///
/// This widget is **not wired into any screen yet** — it is a layout proof of
/// concept. It can be dropped in as a replacement for [StreakCalendar] once
/// the rollup table is populated by a background aggregation job.
class MonthlyActivitySliverCalendar extends StatefulWidget {
  /// Pre-aggregated rollup data, sorted oldest-first (ascending by yearMonth).
  final List<MonthlyActivityRollup> rollups;

  /// Locale string forwarded to [DateFormat] for month header labels.
  /// Defaults to the system locale when null.
  final String? locale;

  const MonthlyActivitySliverCalendar({
    super.key,
    required this.rollups,
    this.locale,
  });

  @override
  State<MonthlyActivitySliverCalendar> createState() =>
      _MonthlyActivitySliverCalendarState();
}

class _MonthlyActivitySliverCalendarState
    extends State<MonthlyActivitySliverCalendar> {
  /// Tracks which months are expanded to show the full daily grid.
  final Set<String> _expanded = {};

  void _toggleExpanded(String yearMonth) {
    setState(() {
      if (_expanded.contains(yearMonth)) {
        _expanded.remove(yearMonth);
      } else {
        _expanded.add(yearMonth);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.rollups.isEmpty) {
      return const Center(child: Text('No activity data'));
    }

    // Build the list of slivers: for each month we emit a header sliver and
    // either a compact summary sliver or a full grid sliver.
    final slivers = <Widget>[];
    for (final rollup in widget.rollups) {
      final isExpanded = _expanded.contains(rollup.yearMonth);

      // Sticky month header.
      slivers.add(
        SliverPersistentHeader(
          pinned: true,
          delegate: _MonthHeaderDelegate(
            rollup: rollup,
            isExpanded: isExpanded,
            locale: widget.locale,
            onTap: () => _toggleExpanded(rollup.yearMonth),
          ),
        ),
      );

      if (isExpanded) {
        // Full 7-column daily grid for the expanded month.
        slivers.add(_FullMonthGridSliver(rollup: rollup));
      } else {
        // Compact summary card — one widget per month.
        slivers.add(_CompactSummarySliver(rollup: rollup));
      }
    }

    slivers.add(const SliverPadding(padding: EdgeInsets.only(bottom: 24)));

    return CustomScrollView(slivers: slivers);
  }
}

// ── Sticky header ─────────────────────────────────────────────────────────────

/// Persistent header that pins the month name + active-day count to the top
/// of the viewport as the user scrolls.
class _MonthHeaderDelegate extends SliverPersistentHeaderDelegate {
  _MonthHeaderDelegate({
    required this.rollup,
    required this.isExpanded,
    required this.onTap,
    this.locale,
  });

  final MonthlyActivityRollup rollup;
  final bool isExpanded;
  final VoidCallback onTap;
  final String? locale;

  static const double _height = 40;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  bool shouldRebuild(_MonthHeaderDelegate old) =>
      old.isExpanded != isExpanded ||
      old.rollup.yearMonth != rollup.yearMonth ||
      old.rollup.activeDays != rollup.activeDays;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final theme = Theme.of(context);
    final monthLabel = _formatYearMonth(rollup.yearMonth, locale);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: _height,
        color: theme.scaffoldBackgroundColor,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '$monthLabel  —  ${rollup.activeDays} active '
                '${rollup.activeDays == 1 ? 'day' : 'days'}',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Icon(
              isExpanded
                  ? Icons.keyboard_arrow_up
                  : Icons.keyboard_arrow_down,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Compact summary card ──────────────────────────────────────────────────────

/// A single sliver containing one compact row for a month.
///
/// Shows: active-day count + a 7-cell mini heat strip from the last 7 days
/// of the month (using the pre-aggregated [MonthlyActivityRollup.activeDaysList]).
class _CompactSummarySliver extends StatelessWidget {
  const _CompactSummarySliver({required this.rollup});

  final MonthlyActivityRollup rollup;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(child: _CompactSummaryCard(rollup: rollup));
  }
}

class _CompactSummaryCard extends StatelessWidget {
  const _CompactSummaryCard({required this.rollup});

  final MonthlyActivityRollup rollup;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Parse the active-days list to a Set<int> for O(1) lookup.
    final activeDayNums = _parseActiveDaysList(rollup.activeDaysList);

    // Determine the last 7 days of the month.
    final monthDate = _yearMonthToDate(rollup.yearMonth);
    final daysInMonth =
        DateUtils.getDaysInMonth(monthDate.year, monthDate.month);
    final lastSevenStart = daysInMonth - 6; // day numbers are 1-based

    final miniCells = <Widget>[];
    for (var day = lastSevenStart; day <= daysInMonth; day++) {
      miniCells.add(_MiniDayCell(isActive: activeDayNums.contains(day)));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          Text(
            '${rollup.totalCompletions} '
            '${rollup.totalCompletions == 1 ? 'completion' : 'completions'}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          // 7-cell mini heat strip.
          Row(children: miniCells),
        ],
      ),
    );
  }
}

class _MiniDayCell extends StatelessWidget {
  const _MiniDayCell({required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      margin: const EdgeInsets.symmetric(horizontal: 1),
      decoration: BoxDecoration(
        color: isActive
            ? const Color(0xFF103BAC)
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

// ── Full month grid sliver ────────────────────────────────────────────────────

/// Expanded view: a 7-column grid of every day in the month.
///
/// Uses [SliverGrid] so the framework only builds cells that are within the
/// current viewport when multiple months are expanded simultaneously.
class _FullMonthGridSliver extends StatelessWidget {
  const _FullMonthGridSliver({required this.rollup});

  final MonthlyActivityRollup rollup;

  @override
  Widget build(BuildContext context) {
    final monthDate = _yearMonthToDate(rollup.yearMonth);
    final daysInMonth =
        DateUtils.getDaysInMonth(monthDate.year, monthDate.month);
    // Day-of-week offset so the grid starts on Monday (weekday 1).
    final firstWeekdayOffset = (monthDate.weekday - 1) % 7;
    // Total cells = leading blanks + actual days.
    final totalCells = firstWeekdayOffset + daysInMonth;

    final activeDayNums = _parseActiveDaysList(rollup.activeDaysList);

    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisExtent: 34,
        crossAxisSpacing: 2,
        mainAxisSpacing: 4,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (index < firstWeekdayOffset) {
            // Blank leading cell.
            return const SizedBox.shrink();
          }
          final dayNumber = index - firstWeekdayOffset + 1;
          final isActive = activeDayNums.contains(dayNumber);
          return _FullDayCell(dayNumber: dayNumber, isActive: isActive);
        },
        childCount: totalCells,
      ),
    );
  }
}

class _FullDayCell extends StatelessWidget {
  const _FullDayCell({required this.dayNumber, required this.isActive});

  final int dayNumber;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    const activeColor = Color(0xFF103BAC);
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: isActive ? activeColor : Colors.transparent,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          '$dayNumber',
          style: TextStyle(
            fontSize: 12,
            color: isActive
                ? Colors.white
                : Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant
                    .withValues(alpha: 0.9),
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Parses a space-separated list of day numbers stored in
/// [MonthlyActivityRollup.activeDaysList] into a [Set<int>].
///
/// Returns an empty set when the string is empty or malformed.
Set<int> _parseActiveDaysList(String raw) {
  if (raw.isEmpty) return const {};
  final result = <int>{};
  for (final token in raw.split(' ')) {
    final n = int.tryParse(token.trim());
    if (n != null) result.add(n);
  }
  return result;
}

/// Parses a `'YYYY-MM'` string into the first day of that month as a local
/// [DateTime].
DateTime _yearMonthToDate(String yearMonth) {
  final parts = yearMonth.split('-');
  if (parts.length < 2) return DateTime(2000);
  final year = int.tryParse(parts[0]) ?? 2000;
  final month = int.tryParse(parts[1]) ?? 1;
  return DateTime(year, month);
}

/// Formats a `'YYYY-MM'` string as a human-readable month label,
/// e.g. `'May 2026'`.
String _formatYearMonth(String yearMonth, String? locale) {
  final date = _yearMonthToDate(yearMonth);
  return DateFormat.yMMMM(locale).format(date);
}
