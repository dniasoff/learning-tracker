/// The parent Change history filter chips (Story 4.5 / DNI-513 AC-8):
/// All · Tutor · Parent · Learning, applied on the client to the loaded
/// pages.
library;

import 'package:learning_tracker/domain/learner_state/actor.dart';
import 'package:learning_tracker/features/change_history/domain/models/history_item.dart';

/// One filter chip.
enum ChangeHistoryFilter {
  /// Every governed change and every learning record.
  all,

  /// Governed changes made by a tutor.
  tutor,

  /// Governed changes made by the parent or the child.
  parent,

  /// Learning records of any actor.
  learning;

  /// Whether a row of this kind by [role] passes the filter.
  bool accepts({required bool isLearning, required ActorRole role}) =>
      switch (this) {
        all => true,
        tutor => !isLearning && role == ActorRole.tutor,
        parent =>
          !isLearning && (role == ActorRole.parent || role == ActorRole.child),
        learning => isLearning,
      };

  /// Whether [item] passes the filter.
  bool acceptsItem(HistoryItem item) =>
      accepts(isLearning: item is LearningBatchItem, role: item.actor.role);
}
