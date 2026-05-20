// Public surface of the tutoring feature.
//
// Import this barrel (features/tutoring/tutoring.dart) from outside this
// feature. Do NOT import deep paths directly.
library tutoring;

// ── Domain models (W3.38, W4.27-W4.29) ────────────────────────────────────
export 'package:learning_tracker/features/tutoring/domain/models/tutor_grant.dart';
export 'package:learning_tracker/features/tutoring/domain/models/tutor_audit_log_entry.dart';
export 'package:learning_tracker/features/tutoring/domain/models/tutor_permissions.dart';
export 'package:learning_tracker/features/tutoring/domain/models/tutor_grant_aggregate.dart';
export 'package:learning_tracker/features/tutoring/domain/models/session_role.dart';

// ── Domain services (W4.30) ────────────────────────────────────────────────
export 'package:learning_tracker/features/tutoring/domain/services/tutor_pin_service.dart';

// ── Domain use cases (W4.31-W4.34) ────────────────────────────────────────
export 'package:learning_tracker/features/tutoring/domain/use_cases/tutor_invite_use_cases.dart';
export 'package:learning_tracker/features/tutoring/domain/use_cases/tutor_grant_use_cases.dart';
export 'package:learning_tracker/features/tutoring/domain/use_cases/mark_live_completion_use_case.dart';

// ── Presentation providers (W4.35) ────────────────────────────────────────
export 'package:learning_tracker/features/tutoring/presentation/providers/permissions_provider.dart';
