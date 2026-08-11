import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/features/profiles/domain/services/pin_service.dart';
import 'package:learning_tracker/features/profiles/domain/models/learner_profile_entity.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'switcher_sheet_pin_guard_provider.g.dart';

/// AN-2: Whether the active profile is a child with a configured Parent PIN —
/// the guard condition that gates all escalating actions in the switcher sheet.
@riverpod
Future<bool> switcherSheetPinGuardRequired(Ref ref) async {
  final activeId = ref.watch(activeProfileIdProvider);
  if (activeId == null) return false;
  final profiles =
      ref.watch(profileListStreamProvider).asData?.value ??
      <LearnerProfileEntity>[];
  final active = profiles.where((p) => p.profileId == activeId).firstOrNull;
  if (active == null || active.mode != ProfileMode.child) return false;
  final pinService = ref.read(pinServiceProvider);
  return pinService.hasProfilePin(activeId);
}
