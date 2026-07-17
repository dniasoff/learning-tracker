// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sacred_windows_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 6-month rolling list of pre-computed Sacred Time block windows. Recomputed
/// whenever the user's location or in-Israel flag changes.
// keepAlive: read by both the lock overlay and CurrentSacredWindow's per-30s timer; dropping it on last-listener-loss would force a recompute on every screen navigation.

@ProviderFor(sacredWindows)
final sacredWindowsProvider = SacredWindowsProvider._();

/// 6-month rolling list of pre-computed Sacred Time block windows. Recomputed
/// whenever the user's location or in-Israel flag changes.
// keepAlive: read by both the lock overlay and CurrentSacredWindow's per-30s timer; dropping it on last-listener-loss would force a recompute on every screen navigation.

final class SacredWindowsProvider
    extends
        $FunctionalProvider<
          List<SacredWindow>,
          List<SacredWindow>,
          List<SacredWindow>
        >
    with $Provider<List<SacredWindow>> {
  /// 6-month rolling list of pre-computed Sacred Time block windows. Recomputed
  /// whenever the user's location or in-Israel flag changes.
  // keepAlive: read by both the lock overlay and CurrentSacredWindow's per-30s timer; dropping it on last-listener-loss would force a recompute on every screen navigation.
  SacredWindowsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sacredWindowsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sacredWindowsHash();

  @$internal
  @override
  $ProviderElement<List<SacredWindow>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  List<SacredWindow> create(Ref ref) {
    return sacredWindows(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<SacredWindow> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<SacredWindow>>(value),
    );
  }
}

String _$sacredWindowsHash() => r'c20beb5cbb41b482ca0f1447057b1dcf0cebae0d';

/// Currently-active window (the one whose [start, end] contains "now"), or
/// null if not currently in Sacred Time.
///
/// Recomputed every minute via an internal timer so the lock screen drops
/// without manual invalidation when tzais passes.
// keepAlive: owns a running Timer that must keep firing even while no widget is watching, so the lock screen drops the instant tzais passes, not just on the next rebuild.

@ProviderFor(CurrentSacredWindow)
final currentSacredWindowProvider = CurrentSacredWindowProvider._();

/// Currently-active window (the one whose [start, end] contains "now"), or
/// null if not currently in Sacred Time.
///
/// Recomputed every minute via an internal timer so the lock screen drops
/// without manual invalidation when tzais passes.
// keepAlive: owns a running Timer that must keep firing even while no widget is watching, so the lock screen drops the instant tzais passes, not just on the next rebuild.
final class CurrentSacredWindowProvider
    extends $NotifierProvider<CurrentSacredWindow, SacredWindow?> {
  /// Currently-active window (the one whose [start, end] contains "now"), or
  /// null if not currently in Sacred Time.
  ///
  /// Recomputed every minute via an internal timer so the lock screen drops
  /// without manual invalidation when tzais passes.
  // keepAlive: owns a running Timer that must keep firing even while no widget is watching, so the lock screen drops the instant tzais passes, not just on the next rebuild.
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
    r'cdbd0a66551f3f62b7cfc2940c2bd8218da3ca62';

/// Currently-active window (the one whose [start, end] contains "now"), or
/// null if not currently in Sacred Time.
///
/// Recomputed every minute via an internal timer so the lock screen drops
/// without manual invalidation when tzais passes.
// keepAlive: owns a running Timer that must keep firing even while no widget is watching, so the lock screen drops the instant tzais passes, not just on the next rebuild.

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
