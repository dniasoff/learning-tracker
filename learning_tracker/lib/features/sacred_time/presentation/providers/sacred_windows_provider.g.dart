// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sacred_windows_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The device lock in force now (AD-36), or null when the app is open.
///
/// The union of `lockWindows` over every learner whose lock drives this
/// device ([accountLockHistoriesProvider]), judged by [sacredWindowAt] —
/// the overlay, notification suppression and the Mishna history all read
/// this one value. A learner whose settings are loading or unreadable is
/// judged fail-closed. Re-judged at the next lock boundary (exactly) and
/// at least every [sacredWindowRecheck], so the overlay appears at the
/// lock's start and lifts just after its end without any other input
/// changing.
// keepAlive: owns a running Timer that must keep firing even while no widget is watching, so the lock appears and lifts on time, not just on the next rebuild.

@ProviderFor(CurrentSacredWindow)
final currentSacredWindowProvider = CurrentSacredWindowProvider._();

/// The device lock in force now (AD-36), or null when the app is open.
///
/// The union of `lockWindows` over every learner whose lock drives this
/// device ([accountLockHistoriesProvider]), judged by [sacredWindowAt] —
/// the overlay, notification suppression and the Mishna history all read
/// this one value. A learner whose settings are loading or unreadable is
/// judged fail-closed. Re-judged at the next lock boundary (exactly) and
/// at least every [sacredWindowRecheck], so the overlay appears at the
/// lock's start and lifts just after its end without any other input
/// changing.
// keepAlive: owns a running Timer that must keep firing even while no widget is watching, so the lock appears and lifts on time, not just on the next rebuild.
final class CurrentSacredWindowProvider
    extends $NotifierProvider<CurrentSacredWindow, SacredWindow?> {
  /// The device lock in force now (AD-36), or null when the app is open.
  ///
  /// The union of `lockWindows` over every learner whose lock drives this
  /// device ([accountLockHistoriesProvider]), judged by [sacredWindowAt] —
  /// the overlay, notification suppression and the Mishna history all read
  /// this one value. A learner whose settings are loading or unreadable is
  /// judged fail-closed. Re-judged at the next lock boundary (exactly) and
  /// at least every [sacredWindowRecheck], so the overlay appears at the
  /// lock's start and lifts just after its end without any other input
  /// changing.
  // keepAlive: owns a running Timer that must keep firing even while no widget is watching, so the lock appears and lifts on time, not just on the next rebuild.
  CurrentSacredWindowProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'currentSacredWindowProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$currentSacredWindowHash();

  @$internal
  @override
  CurrentSacredWindow create() => CurrentSacredWindow();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SacredWindow? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SacredWindow?>(value),
    );
  }
}

String _$currentSacredWindowHash() =>
    r'09215f9eb96ba568ea3fe32f090a6f8851b938fe';

/// The device lock in force now (AD-36), or null when the app is open.
///
/// The union of `lockWindows` over every learner whose lock drives this
/// device ([accountLockHistoriesProvider]), judged by [sacredWindowAt] —
/// the overlay, notification suppression and the Mishna history all read
/// this one value. A learner whose settings are loading or unreadable is
/// judged fail-closed. Re-judged at the next lock boundary (exactly) and
/// at least every [sacredWindowRecheck], so the overlay appears at the
/// lock's start and lifts just after its end without any other input
/// changing.
// keepAlive: owns a running Timer that must keep firing even while no widget is watching, so the lock appears and lifts on time, not just on the next rebuild.

abstract class _$CurrentSacredWindow extends $Notifier<SacredWindow?> {
  SacredWindow? build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<SacredWindow?, SacredWindow?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<SacredWindow?, SacredWindow?>,
              SacredWindow?,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
