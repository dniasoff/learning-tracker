import 'package:flutter/material.dart';
import 'package:learning_tracker/core/enums/user_mode.dart';

/// Result of a completion that feeds the animation sequence.
class CompletionFeedbackData {
  final int pointsAwarded;
  final double progressBefore;
  final double progressAfter;
  final int? streakBefore;
  final int? streakAfter;
  final UserMode userMode;

  const CompletionFeedbackData({
    required this.pointsAwarded,
    required this.progressBefore,
    required this.progressAfter,
    this.streakBefore,
    this.streakAfter,
    required this.userMode,
  });

  /// Whether the streak was incremented by this completion.
  bool get isStreakIncrement =>
      streakBefore != null &&
      streakAfter != null &&
      streakAfter! > streakBefore!;
}

/// Orchestrates the completion feedback animation sequence.
///
/// Phases (child mode):
///   1. Checkmark burst + confetti particles
///   2. Points popup (+X pts)
///   3. Progress bar fill
///   4. Streak counter bump (if applicable)
///
/// Phases (adult mode):
///   1. Brief checkmark fade
///   2. Progress bar fill (no popup, no confetti)
class CompletionFeedbackController extends ChangeNotifier {
  CompletionFeedbackPhase _phase = CompletionFeedbackPhase.idle;
  CompletionFeedbackData? _data;

  CompletionFeedbackPhase get phase => _phase;
  CompletionFeedbackData? get data => _data;
  bool get isActive => _phase != CompletionFeedbackPhase.idle;

  /// Starts the feedback sequence for the given completion data.
  void start(CompletionFeedbackData data) {
    _data = data;
    _phase = CompletionFeedbackPhase.checkmark;
    notifyListeners();
  }

  /// Advances to the next phase. Called by animation widgets on completion.
  void advance() {
    if (_data == null) return;

    switch (_phase) {
      case CompletionFeedbackPhase.checkmark:
        if (_data!.userMode == UserMode.child && _data!.pointsAwarded > 0) {
          _phase = CompletionFeedbackPhase.pointsPopup;
        } else {
          _phase = CompletionFeedbackPhase.progressFill;
        }
      case CompletionFeedbackPhase.pointsPopup:
        _phase = CompletionFeedbackPhase.progressFill;
      case CompletionFeedbackPhase.progressFill:
        if (_data!.userMode == UserMode.child && _data!.isStreakIncrement) {
          _phase = CompletionFeedbackPhase.streakBump;
        } else {
          _phase = CompletionFeedbackPhase.idle;
          _data = null;
        }
      case CompletionFeedbackPhase.streakBump:
        _phase = CompletionFeedbackPhase.idle;
        _data = null;
      case CompletionFeedbackPhase.idle:
        break;
    }
    notifyListeners();
  }

  /// Immediately cancels any running feedback sequence.
  void cancel() {
    _phase = CompletionFeedbackPhase.idle;
    _data = null;
    notifyListeners();
  }
}

enum CompletionFeedbackPhase {
  idle,
  checkmark,
  pointsPopup,
  progressFill,
  streakBump,
}
