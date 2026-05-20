/// Public surface of the `tracks` feature cluster.
///
/// Merges: track_setup, learning_order, track_learning_order, stages.
/// All external consumers MUST import via this barrel — deep imports into
/// tracks/* sub-packages are forbidden (no_feature_cross_import lint).

// ── track setup / track creation ────────────────────────────────────────────
export 'setup/domain/entities/add_track_result.dart';
export 'setup/domain/services/track_creation_service.dart';
export 'setup/domain/services/track_edit_service.dart';
export 'setup/presentation/controllers/add_track_controller.dart';
export 'setup/presentation/controllers/add_track_flow_state.dart';
export 'setup/presentation/providers/add_track_providers.dart';
export 'setup/presentation/providers/after_track_change_invalidation.dart';
export 'setup/presentation/providers/track_edit_providers.dart';
export 'setup/presentation/providers/track_management_providers.dart';
export 'setup/presentation/screens/add_track_flow_screen.dart';
export 'setup/presentation/screens/edit_track_screen.dart';
export 'setup/presentation/screens/track_detail_screen.dart';
export 'setup/presentation/screens/track_management_hub_screen.dart';

// ── stages ───────────────────────────────────────────────────────────────────
export 'stages/domain/models/schedule_type.dart';
export 'stages/domain/models/stage_definition.dart';
export 'stages/domain/repositories/stage_definition_repository.dart';
export 'stages/domain/services/stage_validator.dart';
export 'stages/presentation/providers/stage_providers.dart';

// ── whole-curriculum ordering ─────────────────────────────────────────────────
export 'whole_curriculum_order/domain/models/learning_order_item.dart';
export 'whole_curriculum_order/domain/repositories/learning_order_repository.dart';
export 'whole_curriculum_order/presentation/providers/learning_order_providers.dart';
export 'whole_curriculum_order/presentation/screens/learning_order_screen.dart';

// ── per-track ordering ────────────────────────────────────────────────────────
export 'track_order/domain/repositories/track_learning_order_repository.dart';
export 'track_order/presentation/providers/track_learning_order_providers.dart';
export 'track_order/presentation/screens/track_learning_order_screen.dart';

// ── domain services ───────────────────────────────────────────────────────────
export 'domain/services/curriculum_activation_service.dart';
