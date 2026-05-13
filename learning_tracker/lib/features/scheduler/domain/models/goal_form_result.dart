/// Result returned from the goal setup flow.
///
/// Domain-layer model — safe to import from domain services without
/// crossing into presentation.
class GoalFormResult {
  final double targetPercent;
  final DateTime? targetDate;
  final String description;
  final String dateType;
  final String goalType;
  final int? paceValue;
  final String? paceUnit;

  /// Learning unit for Bavli/Yerushalmi: 'amud' or 'daf'. Null for other curricula.
  final String? learningUnit;

  const GoalFormResult({
    required this.targetPercent,
    this.targetDate,
    this.description = '',
    this.dateType = 'gregorian',
    this.goalType = 'deadline',
    this.paceValue,
    this.paceUnit,
    this.learningUnit,
  });
}
