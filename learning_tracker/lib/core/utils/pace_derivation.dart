/// Derives an explicit weekly pace from a deadline + scope size + study-day
/// density, so the scheduler and dashboard can project a Goal that only has
/// `targetDate` populated (no stored `paceValue` / `pacePeriod`).
///
/// Lives in `core/` so the scheduler (feature) and dashboard (feature) can
/// both call it without crossing each other's `providers.dart` surface.
///
/// Math:
///   perStudyDay = ceil(totalScopeItems / studyDaysInWindow)
///   perWeek     = perStudyDay × studyDaysPerWeek
///
/// `studyDaysInWindow` already encodes both the calendar span AND the
/// study-day density between today and the deadline, so it is the correct
/// denominator for items-per-study-day. Multiplying by `studyDaysPerWeek`
/// converts the unit back to items-per-calendar-week, which is the
/// canonical storage unit (architecture §10.3) and keeps the pace
/// meaningful if the deadline is later removed.
///
/// Falls back to `1/week` when inputs are non-positive so the caller always
/// gets a valid pace.
({int paceValue, String pacePeriod}) derivePaceFromDeadline({
  required int totalScopeItems,
  required int studyDaysInWindow,
  required int studyDaysPerWeek,
}) {
  if (studyDaysInWindow <= 0 || totalScopeItems <= 0) {
    return (paceValue: 1, pacePeriod: 'per_week');
  }
  final perStudyDay = (totalScopeItems / studyDaysInWindow).ceil().clamp(
    1,
    999999,
  );
  final perWeek = (perStudyDay * studyDaysPerWeek.clamp(1, 7)).clamp(1, 999999);
  return (paceValue: perWeek, pacePeriod: 'per_week');
}
