// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sacred_windows_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The device lock in force now (AD-36), or null when the app is open.
///
/// The union of `lockWindows` over every learner profile of the signed-in
/// account ([accountLockHistoriesProvider]), judged by [sacredWindowAt] —
/// the app-wide overlay, notification suppression and the Mishna history
/// all read this one value. A tutored talmid never drives it (see
/// [CurrentTutoredSacredWindow]). A learner whose settings are loading or
/// unreadable is judged fail-closed. Re-judged at the next lock boundary
/// (exactly) and at least every [sacredWindowRecheck], so the overlay
/// appears at the lock's start and lifts just after its end without any
/// other input changing.
// keepAlive: owns a running Timer that must keep firing even while no widget is watching, so the lock appears and lifts on time, not just on the next rebuild.

@ProviderFor(CurrentSacredWindow)
final currentSacredWindowProvider = CurrentSacredWindowProvider._();

/// The device lock in force now (AD-36), or null when the app is open.
///
/// The union of `lockWindows` over every learner profile of the signed-in
/// account ([accountLockHistoriesProvider]), judged by [sacredWindowAt] —
/// the app-wide overlay, notification suppression and the Mishna history
/// all read this one value. A tutored talmid never drives it (see
/// [CurrentTutoredSacredWindow]). A learner whose settings are loading or
/// unreadable is judged fail-closed. Re-judged at the next lock boundary
/// (exactly) and at least every [sacredWindowRecheck], so the overlay
/// appears at the lock's start and lifts just after its end without any
/// other input changing.
// keepAlive: owns a running Timer that must keep firing even while no widget is watching, so the lock appears and lifts on time, not just on the next rebuild.
final class CurrentSacredWindowProvider
    extends $NotifierProvider<CurrentSacredWindow, SacredWindow?> {
  /// The device lock in force now (AD-36), or null when the app is open.
  ///
  /// The union of `lockWindows` over every learner profile of the signed-in
  /// account ([accountLockHistoriesProvider]), judged by [sacredWindowAt] —
  /// the app-wide overlay, notification suppression and the Mishna history
  /// all read this one value. A tutored talmid never drives it (see
  /// [CurrentTutoredSacredWindow]). A learner whose settings are loading or
  /// unreadable is judged fail-closed. Re-judged at the next lock boundary
  /// (exactly) and at least every [sacredWindowRecheck], so the overlay
  /// appears at the lock's start and lifts just after its end without any
  /// other input changing.
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
    r'1b7adf968755aa68e1685a8ccf22fb8016c48e03';

/// The device lock in force now (AD-36), or null when the app is open.
///
/// The union of `lockWindows` over every learner profile of the signed-in
/// account ([accountLockHistoriesProvider]), judged by [sacredWindowAt] —
/// the app-wide overlay, notification suppression and the Mishna history
/// all read this one value. A tutored talmid never drives it (see
/// [CurrentTutoredSacredWindow]). A learner whose settings are loading or
/// unreadable is judged fail-closed. Re-judged at the next lock boundary
/// (exactly) and at least every [sacredWindowRecheck], so the overlay
/// appears at the lock's start and lifts just after its end without any
/// other input changing.
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

/// The lock of the talmid an active tutored session shows, or null when
/// no tutored session is active or that talmid is not locked (DNI-481
/// AC-1 tutor rule, AD-36).
///
/// Judged from [tutoredLearnerLockHistoryProvider] (fail-closed while the
/// talmid's settings load or cannot be read) with the same [sacredWindowAt]
/// as the device lock, and re-judged at the talmid's lock boundaries. It
/// covers only the talmid's screens: it never feeds the account lock, the
/// notification predicate or the after-lock prompt.
// keepAlive: owns a running Timer that must keep firing even while no widget is watching, so the cover appears and lifts on time.

@ProviderFor(CurrentTutoredSacredWindow)
final currentTutoredSacredWindowProvider =
    CurrentTutoredSacredWindowProvider._();

/// The lock of the talmid an active tutored session shows, or null when
/// no tutored session is active or that talmid is not locked (DNI-481
/// AC-1 tutor rule, AD-36).
///
/// Judged from [tutoredLearnerLockHistoryProvider] (fail-closed while the
/// talmid's settings load or cannot be read) with the same [sacredWindowAt]
/// as the device lock, and re-judged at the talmid's lock boundaries. It
/// covers only the talmid's screens: it never feeds the account lock, the
/// notification predicate or the after-lock prompt.
// keepAlive: owns a running Timer that must keep firing even while no widget is watching, so the cover appears and lifts on time.
final class CurrentTutoredSacredWindowProvider
    extends $NotifierProvider<CurrentTutoredSacredWindow, SacredWindow?> {
  /// The lock of the talmid an active tutored session shows, or null when
  /// no tutored session is active or that talmid is not locked (DNI-481
  /// AC-1 tutor rule, AD-36).
  ///
  /// Judged from [tutoredLearnerLockHistoryProvider] (fail-closed while the
  /// talmid's settings load or cannot be read) with the same [sacredWindowAt]
  /// as the device lock, and re-judged at the talmid's lock boundaries. It
  /// covers only the talmid's screens: it never feeds the account lock, the
  /// notification predicate or the after-lock prompt.
  // keepAlive: owns a running Timer that must keep firing even while no widget is watching, so the cover appears and lifts on time.
  CurrentTutoredSacredWindowProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'currentTutoredSacredWindowProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$currentTutoredSacredWindowHash();

  @$internal
  @override
  CurrentTutoredSacredWindow create() => CurrentTutoredSacredWindow();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SacredWindow? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SacredWindow?>(value),
    );
  }
}

String _$currentTutoredSacredWindowHash() =>
    r'e786a2ea4dcbbc315fa3e996774358e8621213ee';

/// The lock of the talmid an active tutored session shows, or null when
/// no tutored session is active or that talmid is not locked (DNI-481
/// AC-1 tutor rule, AD-36).
///
/// Judged from [tutoredLearnerLockHistoryProvider] (fail-closed while the
/// talmid's settings load or cannot be read) with the same [sacredWindowAt]
/// as the device lock, and re-judged at the talmid's lock boundaries. It
/// covers only the talmid's screens: it never feeds the account lock, the
/// notification predicate or the after-lock prompt.
// keepAlive: owns a running Timer that must keep firing even while no widget is watching, so the cover appears and lifts on time.

abstract class _$CurrentTutoredSacredWindow extends $Notifier<SacredWindow?> {
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
