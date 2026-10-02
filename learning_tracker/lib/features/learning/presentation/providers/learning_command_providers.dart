/// Riverpod access to [LearningCommands], its [CaptureGate] and its
/// [LearningAnalytics] seam.
///
/// C0 (DNI-524) fixes the names and types; DNI-469 (1.7) fills the stubs.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/domain/learner_state/c0_stub.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_gate.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_analytics.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_commands.dart';

/// The capture gate every command runs first. DNI-469 fills
/// [LockWindowCaptureGate.check].
final captureGateProvider = Provider<CaptureGate>(
  (ref) => const LockWindowCaptureGate(),
);

/// The learning analytics seam.
///
/// C0 stub, filled by DNI-469 (1.7).
final learningAnalyticsProvider = Provider<LearningAnalytics>(
  (ref) => c0Stub('DNI-469', 'learningAnalyticsProvider'),
);

/// The commands bound to the active learner's scope and session actor, or
/// null while no learner is active.
///
/// C0 stub, filled by DNI-469 (1.7).
final learningCommandsProvider = FutureProvider<LearningCommands?>(
  (ref) => c0Stub('DNI-469', 'learningCommandsProvider'),
  retry: (retryCount, error) => null,
);
