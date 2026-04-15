import 'package:learning_tracker/core/services/learning_program_service.dart';

/// Configuration for test reminders.
class TestReminderConfig {
  const TestReminderConfig({
    this.enabled = true,
    this.reminderDaysBefore = const [7, 1],
  });

  final bool enabled;

  /// Days before test date to send reminders. Default: 7 days + 1 day.
  final List<int> reminderDaysBefore;
}

/// Service for managing test reminders.
///
/// Calculates reminder dates based on upcoming test dates and configuration.
class TestReminderService {
  const TestReminderService();

  /// Returns reminder dates for a given test date based on config.
  List<DateTime> getReminderDates(
    DateTime testDate, {
    TestReminderConfig config = const TestReminderConfig(),
  }) {
    if (!config.enabled) return [];
    return config.reminderDaysBefore
        .map((days) => testDate.subtract(Duration(days: days)))
        .where((d) => d.isAfter(DateTime.now().toUtc()))
        .toList()
      ..sort();
  }

  /// Checks if a program has tests based on its LearningProgramData record.
  bool programHasTests(LearningProgramData program) => program.hasTests;
}
