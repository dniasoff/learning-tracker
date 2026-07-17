import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/features/profiles/domain/models/profile_model.dart';
import 'package:learning_tracker/features/profiles/domain/services/pin_service.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'switcher_sheet_pin_guard_provider.g.dart';

/// AN-2: Whether the active profile is a child with a configured Parent PIN —
/// the guard condition that gates all escalating actions in the switcher sheet.
///
/// AUD-profiles-17: migrated from a hand-declared top-level [FutureProvider]
/// in `profile_switcher_sheet.dart` to `@riverpod` codegen (SM-1) and moved
/// under `presentation/providers/` (placement convention), matching every
/// other provider in this feature. Codegen providers are autoDispose by
/// default, so this no longer stays alive for the app's remaining lifetime
/// once read — it tears down with the switcher sheet like the rest of the
/// feature's providers. Still exposed as an overridable provider so tests
/// can inject a known result without touching [FlutterSecureStorage].
@riverpod
Future<bool> switcherSheetPinGuardRequired(Ref ref) async {
  final profiles =
      ref.watch(profileListStreamProvider).asData?.value ?? <ProfileModel>[];
  final activeId = ref.watch(activeProfileIdProvider);
  final active = profiles.where((p) => p.id == activeId).firstOrNull;
  if (active == null || active.profileMode != ProfileMode.child) return false;
  final pinService = ref.read(pinServiceProvider);
  return pinService.hasProfilePin(activeId);
}
