/// Exception thrown when attempting to deactivate the last active curriculum
/// for a profile.
///
/// The app enforces a minimum-1 invariant: every profile must have at least one
/// active curriculum at all times.
class LastActiveCurriculumException implements Exception {
  const LastActiveCurriculumException();

  @override
  String toString() =>
      'LastActiveCurriculumException: Cannot deactivate the last active '
      'curriculum — at least one curriculum must remain active.';
}
