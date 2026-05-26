// Public surface of the tutoring feature.
//
// Import this barrel (features/tutoring/tutoring.dart) from outside this
// feature. Do NOT import deep paths directly.
//
// ignore_for_file: directives_ordering — exports are grouped by semantic
// section (models, services, use-cases, providers) rather than alphabetically.
library tutoring;

// ── Domain models (W3.38, W4.27-W4.29) ────────────────────────────────────
export 'package:learning_tracker/features/tutoring/domain/models/tutor_grant.dart';
export 'package:learning_tracker/features/tutoring/domain/models/tutor_audit_log_entry.dart';
export 'package:learning_tracker/features/tutoring/domain/models/tutor_permissions.dart';
export 'package:learning_tracker/features/tutoring/domain/models/tutor_grant_aggregate.dart';
export 'package:learning_tracker/features/tutoring/domain/models/session_role.dart';

// ── Domain services (W4.30, W6.20-W6.22, W6.25) ──────────────────────────
export 'package:learning_tracker/features/tutoring/domain/services/tutor_pin_service.dart';
export 'package:learning_tracker/features/tutoring/domain/services/tutor_audit_log_writer.dart';
export 'package:learning_tracker/features/tutoring/domain/services/tutor_notification_service.dart';

// ── Domain use cases (W4.31-W4.34) ────────────────────────────────────────
export 'package:learning_tracker/features/tutoring/domain/use_cases/tutor_invite_use_cases.dart';
export 'package:learning_tracker/features/tutoring/domain/use_cases/tutor_grant_use_cases.dart';
export 'package:learning_tracker/features/tutoring/domain/use_cases/mark_live_completion_use_case.dart';

// ── Presentation providers (W4.35, W6.7, W6.9, W6.10, T2.resolution) ─────
export 'package:learning_tracker/features/tutoring/presentation/providers/active_tutored_profile_provider.dart';
export 'package:learning_tracker/features/tutoring/presentation/providers/tutor_grant_providers.dart';
export 'package:learning_tracker/features/tutoring/presentation/providers/tutor_pin_providers.dart';

// ── Presentation screens (W6.4–W6.10) ────────────────────────────────────
export 'package:learning_tracker/features/tutoring/presentation/screens/accept_invite_screen.dart';
export 'package:learning_tracker/features/tutoring/presentation/screens/decline_invite_screen.dart';
export 'package:learning_tracker/features/tutoring/presentation/screens/invite_tutor_screen.dart';
export 'package:learning_tracker/features/tutoring/presentation/screens/tutor_pin_entry_gate.dart';
export 'package:learning_tracker/features/tutoring/presentation/screens/tutor_pin_reset_screen.dart';
export 'package:learning_tracker/features/tutoring/presentation/screens/tutor_pin_setup_screen.dart';
