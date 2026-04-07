import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'active_profile_provider.g.dart';

/// Holds the active profile ID for the current session.
///
/// Derives from [selectedProfileIdProvider] so that profile selection
/// in the ProfileGuard, ProfilePicker, and onboarding all flow through
/// to every data provider that watches this value.
///
/// `keepAlive` ensures the state survives route changes.
/// Default value 0 represents the legacy/default profile.
@Riverpod(keepAlive: true)
class ActiveProfileId extends _$ActiveProfileId {
  @override
  int build() {
    final selected = ref.watch(selectedProfileIdProvider);
    return selected ?? 0;
  }
}
