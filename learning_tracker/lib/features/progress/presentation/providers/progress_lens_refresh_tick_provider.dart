import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Refresh-tick provider that lens-screen providers can watch so a pull-to-
/// refresh on the Progress hub propagates into the deeper lens trees
/// (Recent Activity, Siyumim & Milestones, Lifetime Knowledge).
///
/// ### Why a tick instead of enumerating provider invalidations
///
/// Each lens screen owns its own provider tree:
///
///   - Recent Activity → `lib/features/progress/presentation/providers/
///     recent_activity_providers.dart` (W7-D)
///   - Lifetime Knowledge → `lib/features/progress/presentation/providers/
///     lifetime_knowledge_providers.dart` (W7-B)
///   - Siyumim & Milestones → `lib/features/progress/presentation/providers/
///     journey_providers.dart`
///
/// A pragmatic refresh handler in the Progress hub could enumerate every
/// provider on those trees and `ref.invalidate` each one. That works but:
///
///   - It couples the hub to private members of every lens tree.
///   - Adding a new lens provider requires editing the hub.
///   - Tests of the hub have to mock all the lens providers.
///
/// The tick approach is loose-coupled: the hub bumps a single int, and any
/// lens provider that wants to participate can `ref.watch` the tick and
/// re-fetch when it changes. The hub doesn't need to know who's listening.
///
/// ### Wiring contract
///
/// Bumping the tick on its own does NOT refresh anything. A lens provider
/// participates by calling `ref.watch(progressLensRefreshTickProvider)` —
/// once it does, every `ref.invalidate(progressLensRefreshTickProvider)`
/// (or equivalently `bump()`) will cause the lens provider to rebuild.
///
/// ### Owner coordination (W7 wave handoff)
///
/// The lens-provider files are owned by sibling waves (W7-B, W7-D) and
/// cannot be modified in this pass. The new `ref.watch(...)` lines will
/// land in their follow-up pass — see the W7-E handoff notes.
/// Meanwhile the hub already bumps the tick on pull-to-refresh; once the
/// lens providers wire their `ref.watch`, the refresh propagation lights
/// up automatically with no further hub-side change.
///
/// As a safety net, the hub also keeps invalidating the providers it
/// directly composes (streak, journey, lifetime totals) so user-facing
/// refresh is never less effective than before this change — just more
/// reach when the lens providers come online.
class ProgressLensRefreshTick extends Notifier<int> {
  @override
  int build() => 0;

  /// Increment the tick. Any provider that `ref.watch`es this notifier
  /// rebuilds — the natural Riverpod refresh path. The value itself is
  /// irrelevant; only the change matters.
  void bump() => state = state + 1;
}

/// Application-wide refresh tick for the Progress hub's lens providers.
///
/// Usage from the hub:
///
/// ```dart
/// onRefresh: () async {
///   ref.read(progressLensRefreshTickProvider.notifier).bump();
///   // ... and invalidate hub-owned providers directly as a safety net.
/// }
/// ```
///
/// Usage from a lens provider (added in a follow-up pass — see docstring):
///
/// ```dart
/// @riverpod
/// Future<MyLensData> myLensProvider(MyLensProviderRef ref) async {
///   ref.watch(progressLensRefreshTickProvider);
///   return _fetch();
/// }
/// ```
final progressLensRefreshTickProvider =
    NotifierProvider<ProgressLensRefreshTick, int>(
      ProgressLensRefreshTick.new,
    );
