import 'package:learning_tracker/core/exceptions/app_exception.dart';

/// Exception thrown when attempting to add a stage beyond the maximum limit.
class StageLimitExceededException extends ValidationException {
  StageLimitExceededException({required this.maxStages})
    : super('Maximum of $maxStages stages allowed per curriculum');

  final int maxStages;

  String get userMessage => message;
}
