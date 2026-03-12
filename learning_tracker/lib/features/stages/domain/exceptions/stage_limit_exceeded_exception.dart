/// Exception thrown when attempting to add a stage beyond the maximum limit.
class StageLimitExceededException implements Exception {
  const StageLimitExceededException({required this.maxStages});

  final int maxStages;

  String get userMessage =>
      'Maximum of $maxStages stages allowed per curriculum';

  @override
  String toString() => 'StageLimitExceededException: $userMessage';
}
