/// Learner-state ports (AD-35).
///
/// Abstract interfaces the pure learner-state engine and `LearningCommands`
/// depend on. They are declared here and implemented outside `lib/domain/`
/// (`lib/data/repositories/**`). Like the rest of `lib/domain/**`, this
/// directory must never import Firestore, Firebase, Flutter, Riverpod or
/// `learning_tracker/data/**` — `tool/check_dependency_direction.dart`
/// enforces it as a hard gate.
library;

export 'change_log_repository.dart';
export 'complete_read.dart';
export 'governed_doc_reader.dart';
export 'governed_intent_repository.dart';
export 'history_page.dart';
export 'learner_scope.dart';
export 'learner_settings_reader.dart';
export 'learning_command_reads.dart';
export 'learning_event_repository.dart';
export 'learning_write_port.dart';
export 'oversized_governed_write_port.dart';
export 'sub_track_repository.dart';
export 'tutor_scope_grant_source.dart';
