// Public surface of the scheduler feature.
//
// Import this barrel (features/scheduler/scheduler.dart) from outside this
// feature. Do NOT import deep paths directly.
//
// AUD-scheduler-14: scheduler is a heavily cross-cut feature (17 files
// deep-imported across 10+ other features and lib/core/ before this fix).
// The exports below are the feature's actual public surface — every file
// already deep-imported from outside features/scheduler/, per the `make
// audit` check 15/15 cross-feature-deep-import grep. All prior deep-import
// call sites have been migrated to this barrel; new cross-feature consumers
// MUST import this barrel instead of a deep path.
//
// ignore_for_file: directives_ordering — exports are grouped by semantic
// section (repositories, domain models, domain services, providers,
// screens, widgets) rather than alphabetically.
library scheduler;

// ── Domain repositories ────────────────────────────────────────────────
export 'data/repositories/goal_repository_impl.dart';
export 'domain/repositories/goal_repository.dart';

// ── Domain models ──────────────────────────────────────────────────────
export 'domain/models/daily_task.dart';
export 'domain/models/goal_entity.dart';
export 'domain/models/pace_status.dart';

// ── Domain labels ───────────────────────────────────────────────────────
export 'domain/labels/program_label_resolver.dart';

// ── Domain services ────────────────────────────────────────────────────
export 'domain/services/calendar_program_registry.dart';
export 'domain/services/calendar_program_service.dart';
export 'domain/services/cross_curriculum_aggregator.dart';
export 'domain/services/learning_program_service.dart';
export 'domain/services/local_calendar_engine.dart';
export 'domain/services/pace_calculator.dart';

// ── Presentation providers ─────────────────────────────────────────────
export 'presentation/providers/scheduler_providers.dart';

// ── Presentation screens ───────────────────────────────────────────────
export 'presentation/screens/goal_setup_screen.dart';
export 'presentation/screens/scheduler_screen.dart';
export 'presentation/screens/study_day_config_screen.dart';

// ── Presentation widgets ───────────────────────────────────────────────
export 'presentation/widgets/hebrew_date_picker.dart';
