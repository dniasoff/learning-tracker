/// Learner-state ports (AD-35) — placeholder library.
///
/// Abstract interfaces the pure learner-state engine depends on are
/// declared here and implemented outside `lib/domain/` (story 1.2 adds the
/// real port declarations). Like the rest of `lib/domain/**`, this
/// directory must never import Firestore, Firebase, Flutter, Riverpod or
/// `learning_tracker/data/**` — `tool/check_dependency_direction.dart`
/// enforces it as a hard gate.
library;
