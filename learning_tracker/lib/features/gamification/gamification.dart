// Public surface of the gamification feature.
//
// Import this barrel (features/gamification/gamification.dart) from outside
// this feature. Do NOT import deep paths directly.
//
// AUD-gamification-18: this file previously declared itself the feature's
// public surface but exported nothing — every external caller (dashboard,
// learning, notifications, sync, content_browsing) reached into
// features/gamification/** via deep imports instead. Populated with the
// symbols those callers actually use, per Rule 2 of coding-standards.md
// (the Y.dart barrel is the only sanctioned re-export file per feature).
library gamification;

// ── Data adapters ────────────────────────────────────────────────────────
export 'package:learning_tracker/features/gamification/data/repositories/firestore_points_balance_reader_adapter.dart';
// ── Domain models ──────────────────────────────────────────────────────
export 'package:learning_tracker/features/gamification/domain/models/reward_milestone.dart';
export 'package:learning_tracker/features/gamification/domain/models/streak_recovery_info.dart';
// ── Domain services ─────────────────────────────────────────────────────
export 'package:learning_tracker/features/gamification/domain/services/points_service.dart';
export 'package:learning_tracker/features/gamification/domain/services/reward_milestone_service.dart';
export 'package:learning_tracker/features/gamification/domain/services/streak_service.dart';
// ── Presentation providers ──────────────────────────────────────────────
// AUD-gamification-11 (SM-7): rewardMilestoneServiceProvider /
// streakStateProvider / streakServiceProvider — the sanctioned DI seams for
// RewardMilestoneService / StreakStateService / StreakService. External
// callers (e.g. features/dashboard/) must read these through this barrel
// rather than deep-importing gamification_service_providers.dart (Rule 2).
export 'package:learning_tracker/features/gamification/presentation/providers/gamification_service_providers.dart';
// ── Presentation widgets ────────────────────────────────────────────────
export 'package:learning_tracker/features/gamification/presentation/widgets/achievement_unlock_celebration.dart';
export 'package:learning_tracker/features/gamification/presentation/widgets/gamification_route_push_guard.dart';
// ── Streak read path ────────────────────────────────────────────────────
export 'package:learning_tracker/features/gamification/streak/streak_state_service.dart';
