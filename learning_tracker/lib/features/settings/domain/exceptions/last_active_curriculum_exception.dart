import 'package:learning_tracker/core/exceptions/app_exception.dart';

/// Exception thrown when attempting to deactivate the last active curriculum
/// for a profile.
///
/// The app enforces a minimum-1 invariant: every profile must have at least one
/// active curriculum at all times.
class LastActiveCurriculumException extends ValidationException {
  const LastActiveCurriculumException()
    : super(
        'Cannot deactivate the last active curriculum — '
        'at least one curriculum must remain active.',
      );
}
