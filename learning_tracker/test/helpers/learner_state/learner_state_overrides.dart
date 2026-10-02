/// Provider overrides that wire the C0 (DNI-524) fakes into a
/// `ProviderContainer` or `pumpApp`.
library;

// `Override` is part of Riverpod's public API but is only re-exported from
// `misc.dart` (same import as `test/helpers/pump_app.dart`).
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:learning_tracker/data/firestore/learner_state_repository_providers.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings_history.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/features/learner_state/presentation/providers/learner_state_provider.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_gate.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_analytics.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_commands.dart';
import 'package:learning_tracker/features/learning/presentation/providers/learning_command_providers.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/learner_lock_settings_provider.dart';

/// Overrides for the learner-state and command providers.
///
/// [activeLearnerScopeProvider] is always overridden, to [scope] (null
/// means no active learner), so no test reaches the real account wiring.
/// Every other provider is overridden only when its argument is given:
/// [state] for [learnerStateProvider] (every scope), [commands] for
/// [learningCommandsProvider], [lockSettings] for
/// [learnerLockSettingsProvider] (every scope), [gate] for
/// [captureGateProvider] and [analytics] for [learningAnalyticsProvider].
/// A provider left out keeps its C0 body (a stub resolves to
/// `AsyncError(UnimplementedError)`).
List<Override> learnerStateOverrides({
  LearnerScope? scope,
  LearnerState? state,
  LearningCommands? commands,
  LearnerSettingsHistory? lockSettings,
  CaptureGate? gate,
  LearningAnalytics? analytics,
}) => [
  activeLearnerScopeProvider.overrideWith((ref) async => scope),
  if (state != null)
    learnerStateProvider.overrideWith((ref, _) => Stream.value(state)),
  if (commands != null)
    learningCommandsProvider.overrideWith((ref) async => commands),
  if (lockSettings != null)
    learnerLockSettingsProvider.overrideWith(
      (ref, _) => Stream.value(lockSettings),
    ),
  if (gate != null) captureGateProvider.overrideWithValue(gate),
  if (analytics != null) learningAnalyticsProvider.overrideWithValue(analytics),
];
