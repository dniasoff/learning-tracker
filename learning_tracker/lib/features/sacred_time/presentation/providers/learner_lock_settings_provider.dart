/// The learner-settings history the lock overlay and capture gate read
/// (AD-36, AD-37), keyed by [LearnerScope] (ruling B10).
///
/// C0 (DNI-524) fixes the name and type; DNI-470 (1.8) owns and fills it
/// (ruling B4(d)).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/domain/learner_state/c0_stub.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings_history.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';

/// The [LearnerSettingsHistory] of [LearnerScope], live.
///
/// C0 stub, filled by DNI-470 (1.8).
final learnerLockSettingsProvider = StreamProvider.autoDispose
    .family<LearnerSettingsHistory, LearnerScope>(
      (ref, scope) => c0Stub('DNI-470', 'learnerLockSettingsProvider'),
      retry: (retryCount, error) => null,
    );
