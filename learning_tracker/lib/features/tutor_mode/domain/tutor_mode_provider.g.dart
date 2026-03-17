// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tutor_mode_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Tracks whether tutor mode is currently active.
///
/// When active, all data modification APIs should be blocked (read-only mode).
/// This is device-local state — tutor mode is entered by verifying the tutor PIN
/// and exited by navigating away from the tutor mode screen.

@ProviderFor(TutorMode)
final tutorModeProvider = TutorModeProvider._();

/// Tracks whether tutor mode is currently active.
///
/// When active, all data modification APIs should be blocked (read-only mode).
/// This is device-local state — tutor mode is entered by verifying the tutor PIN
/// and exited by navigating away from the tutor mode screen.
final class TutorModeProvider extends $NotifierProvider<TutorMode, bool> {
  /// Tracks whether tutor mode is currently active.
  ///
  /// When active, all data modification APIs should be blocked (read-only mode).
  /// This is device-local state — tutor mode is entered by verifying the tutor PIN
  /// and exited by navigating away from the tutor mode screen.
  TutorModeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'tutorModeProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$tutorModeHash();

  @$internal
  @override
  TutorMode create() => TutorMode();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$tutorModeHash() => r'a1f97ce03696871385afe1ff7ad39a368c1ee929';

/// Tracks whether tutor mode is currently active.
///
/// When active, all data modification APIs should be blocked (read-only mode).
/// This is device-local state — tutor mode is entered by verifying the tutor PIN
/// and exited by navigating away from the tutor mode screen.

abstract class _$TutorMode extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<bool, bool>,
              bool,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
