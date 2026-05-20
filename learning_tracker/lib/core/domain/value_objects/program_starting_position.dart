import 'package:learning_tracker/core/exceptions/validation_exception.dart';

/// Allowed look-back window in days (B2 constraint).
///
/// The user may start a program up to [kMaxLookBackDays] in the past.
/// Future start dates are never allowed.
const int kMaxLookBackDays = 30;

/// Value object representing the starting position for a calendar-driven
/// learning program (Daf Yomi, Amud Yomi, etc.).
///
/// ### B2 — Window enforcement
/// The starting date MUST be within `[today − 30 days, today]` in the user's
/// local day (not UTC). Future dates are incoherent for a structured program
/// and are refused on construction. The backward limit (30 days) allows the
/// user to say "I already started this program 30 days ago, load me with the
/// catch-up tasks I've covered."
///
/// ### B3 — Back-dated enrolment generates overdue tasks
/// When `N > 0` (i.e. `startDate < today`), [ProvisionTrackUseCase] walks
/// `[startDate, today)` against the program's schedule and emits past-dated
/// tasks that surface as overdue on the dashboard. [ProgramStartingPosition]
/// is the single source of truth for what start date was chosen — consumers
/// derive the overdue window from [startDate] directly.
///
/// ### Grammar replacement
/// Supersedes the old `offset:N|ref:<sefariaRef>` substring grammar encoded
/// in the `startingRef` string field of [AddTrackResult]. VOs are preferred
/// over encoded strings (T14 / primitive-obsession sweep).
class ProgramStartingPosition {
  /// The chosen program start date (local-day boundary at midnight local time).
  final DateTime startDate;

  /// The ref to the Sefaria content item to start at, if the user specified
  /// a content-based starting position (e.g. "Berakhot 42a").
  ///
  /// `null` when the position is purely date-based (offset from today).
  final String? sefariaRef;

  const ProgramStartingPosition._({
    required this.startDate,
    this.sefariaRef,
  });

  /// Factory that validates the date window.
  ///
  /// [startDate] is the desired program start in the user's local day (pass
  /// midnight of the desired local date). [today] is today's local midnight.
  ///
  /// Throws [StartDateWindowException] when `startDate > today` or
  /// `startDate < today − 30 days`.
  factory ProgramStartingPosition.create({
    required DateTime startDate,
    required DateTime today,
    String? sefariaRef,
  }) {
    // Normalise both to local-day midnight for day-accurate comparison.
    final todayDay = _dayOnly(today);
    final startDay = _dayOnly(startDate);

    final minDay = todayDay.subtract(const Duration(days: kMaxLookBackDays));

    if (startDay.isAfter(todayDay)) {
      throw StartDateWindowException(
        'Program start date cannot be in the future. '
        'Got: ${startDay.toIso8601String()}, today: ${todayDay.toIso8601String()}',
      );
    }
    if (startDay.isBefore(minDay)) {
      throw StartDateWindowException(
        'Program start date cannot be more than $kMaxLookBackDays days in the '
        'past. Got: ${startDay.toIso8601String()}, '
        'min: ${minDay.toIso8601String()}',
      );
    }

    return ProgramStartingPosition._(
      startDate: startDay,
      sefariaRef: sefariaRef,
    );
  }

  /// Returns a date range `[minDate, maxDate]` suitable for a UI date-picker
  /// constraint, given today's local date.
  ///
  /// Callers (program-step widget inside AddTrackFlow / EditTrackScreen) MUST
  /// use these bounds to constrain the picker. This is the single source of
  /// truth for the B2 window.
  static ({DateTime minDate, DateTime maxDate}) allowedWindow(DateTime today) {
    final todayDay = _dayOnly(today);
    final minDay = todayDay.subtract(const Duration(days: kMaxLookBackDays));
    return (minDate: minDay, maxDate: todayDay);
  }

  /// Number of days this position is back-dated from today.
  ///
  /// Returns 0 when `startDate == today`.
  /// Used by [ProvisionTrackUseCase] to determine the overdue task count (B3).
  int daysFromToday(DateTime today) {
    final todayDay = _dayOnly(today);
    final startDay = _dayOnly(startDate);
    return todayDay.difference(startDay).inDays;
  }

  /// Parse from the legacy `offset:N|ref:<sefariaRef>` grammar.
  ///
  /// Accepts:
  ///  - `null` → today's date, no sefariaRef
  ///  - `"offset:N"` → today minus N days, no sefariaRef
  ///  - `"offset:N|ref:<sefariaRef>"` → today minus N days + sefariaRef
  ///  - `"<sefariaRef>"` (no pipe) → today's date + sefariaRef
  ///
  /// [today] is used to resolve the date. Throws [StartDateWindowException]
  /// when the parsed offset is out of the allowed window.
  factory ProgramStartingPosition.fromLegacyGrammar({
    required String? rawStartingRef,
    required DateTime today,
  }) {
    if (rawStartingRef == null || rawStartingRef.isEmpty) {
      return ProgramStartingPosition._(startDate: _dayOnly(today));
    }

    int offset = 0;
    String? sefariaRef;

    if (rawStartingRef.contains('|')) {
      for (final token in rawStartingRef.split('|')) {
        if (token.startsWith('offset:')) {
          offset = int.tryParse(token.substring('offset:'.length)) ?? 0;
        }
        if (token.startsWith('ref:')) {
          final parsed = token.substring('ref:'.length);
          if (parsed.isNotEmpty) sefariaRef = parsed;
        }
      }
    } else if (rawStartingRef.startsWith('offset:')) {
      offset = int.tryParse(
            rawStartingRef.substring('offset:'.length),
          ) ??
          0;
    } else {
      // Bare sefariaRef string, no offset.
      sefariaRef = rawStartingRef;
    }

    final startDate = _dayOnly(today).subtract(Duration(days: offset.abs()));
    return ProgramStartingPosition.create(
      startDate: startDate,
      today: today,
      sefariaRef: sefariaRef,
    );
  }

  /// Encode back into the legacy grammar (for backward compatibility during
  /// the transition period before the grammar is fully retired).
  String toLegacyGrammar(DateTime today) {
    final offset = daysFromToday(today);
    final parts = <String>[];
    if (offset != 0 || sefariaRef != null) {
      parts.add('offset:$offset');
    }
    if (sefariaRef != null) {
      parts.add('ref:$sefariaRef');
    }
    return parts.isEmpty ? '' : parts.join('|');
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProgramStartingPosition &&
          other.startDate == startDate &&
          other.sefariaRef == sefariaRef);

  @override
  int get hashCode => Object.hash(startDate, sefariaRef);

  @override
  String toString() =>
      'ProgramStartingPosition(startDate: $startDate, sefariaRef: $sefariaRef)';

  /// Trim a [DateTime] to local-day midnight (year/month/day only).
  static DateTime _dayOnly(DateTime dt) =>
      DateTime(dt.year, dt.month, dt.day);
}

/// Thrown when a [ProgramStartingPosition] date falls outside
/// `[today − 30 days, today]`.
class StartDateWindowException extends ValidationException {
  const StartDateWindowException(super.message);
}
