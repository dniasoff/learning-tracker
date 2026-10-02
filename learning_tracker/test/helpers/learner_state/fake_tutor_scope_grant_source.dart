/// Test doubles for the Story 4.2a (DNI-523) grant-scoped tutor read seam:
/// a scriptable [TutorScopeGrantSource] and per-scope learner-state streams.
/// DNI-511 / DNI-512 tests can wire them in with
/// [tutorScopeReadOverrides].
library;

import 'dart:async';

import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:learning_tracker/data/firestore/tutor_scope_grant_providers.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/domain/learner_state/ports/tutor_scope_grant_source.dart';
import 'package:learning_tracker/features/learner_state/presentation/providers/learner_state_provider.dart';

/// A [TutorScopeGrantSource] whose verdict per scope the test sets.
///
/// A scope with no verdict yet is loading (its stream emits nothing).
final class FakeTutorScopeGrantSource implements TutorScopeGrantSource {
  final Map<LearnerScope, TutorScopeGrantVerdict> _verdicts = {};
  final Map<LearnerScope, StreamController<TutorScopeGrantVerdict>>
  _controllers = {};

  /// Every scope [watch] was called for, in order.
  final List<LearnerScope> watched = [];

  StreamController<TutorScopeGrantVerdict> _controller(LearnerScope scope) =>
      _controllers.putIfAbsent(scope, StreamController.broadcast);

  /// Grants [scope] through [grantId].
  void grant(LearnerScope scope, [String grantId = 'grant']) =>
      _set(scope, TutorScopeGranted(grantId));

  /// Denies [scope] for [reason].
  void deny(LearnerScope scope, TutorScopeDenialReason reason) =>
      _set(scope, TutorScopeDenied(reason));

  /// Emits a listener failure for [scope].
  void fail(LearnerScope scope, Object error) =>
      _controller(scope).addError(error, StackTrace.current);

  void _set(LearnerScope scope, TutorScopeGrantVerdict verdict) {
    _verdicts[scope] = verdict;
    _controller(scope).add(verdict);
  }

  @override
  Stream<TutorScopeGrantVerdict> watch(LearnerScope scope) {
    watched.add(scope);
    return _replayCurrent(scope);
  }

  Stream<TutorScopeGrantVerdict> _replayCurrent(LearnerScope scope) async* {
    final current = _verdicts[scope];
    if (current != null) yield current;
    yield* _controller(scope).stream;
  }
}

/// Per-scope learner-state streams for overriding [learnerStateProvider].
final class ScopedLearnerStateStreams {
  final Map<LearnerScope, StreamController<LearnerState>> _controllers = {};

  /// How many times each scope's stream was listened to.
  final Map<LearnerScope, int> listens = {};

  /// How many times each scope's stream subscription was cancelled.
  final Map<LearnerScope, int> cancels = {};

  /// The stream for [scope].
  Stream<LearnerState> stream(LearnerScope scope) => _controllers
      .putIfAbsent(
        scope,
        () => StreamController<LearnerState>.broadcast(
          onListen: () =>
              listens.update(scope, (n) => n + 1, ifAbsent: () => 1),
          onCancel: () =>
              cancels.update(scope, (n) => n + 1, ifAbsent: () => 1),
        ),
      )
      .stream;

  /// Emits [state] for [scope].
  void emit(LearnerScope scope, LearnerState state) =>
      _controllers[scope]!.add(state);

  /// Emits a read failure for [scope].
  void fail(LearnerScope scope, Object error) =>
      _controllers[scope]!.addError(error, StackTrace.current);
}

/// Overrides that route the grant-scoped read seam to [source] (null means
/// no signed-in account) and [learnerStateProvider] to [states].
List<Override> tutorScopeReadOverrides({
  required FakeTutorScopeGrantSource? source,
  required ScopedLearnerStateStreams states,
}) => [
  tutorScopeGrantSourceProvider.overrideWith((ref) async => source),
  learnerStateProvider.overrideWith((ref, scope) => states.stream(scope)),
];
