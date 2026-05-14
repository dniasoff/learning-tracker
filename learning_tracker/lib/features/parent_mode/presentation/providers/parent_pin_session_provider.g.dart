// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'parent_pin_session_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Profile id for which the parent PIN was verified in this app session.
///
/// When this equals the active profile id, the parent is treated as acting
/// for that (child) profile — e.g. manual lifetime completions in Settings.

@ProviderFor(ParentPinAuthenticatedProfileId)
final parentPinAuthenticatedProfileIdProvider =
    ParentPinAuthenticatedProfileIdProvider._();

/// Profile id for which the parent PIN was verified in this app session.
///
/// When this equals the active profile id, the parent is treated as acting
/// for that (child) profile — e.g. manual lifetime completions in Settings.
final class ParentPinAuthenticatedProfileIdProvider
    extends $NotifierProvider<ParentPinAuthenticatedProfileId, int?> {
  /// Profile id for which the parent PIN was verified in this app session.
  ///
  /// When this equals the active profile id, the parent is treated as acting
  /// for that (child) profile — e.g. manual lifetime completions in Settings.
  ParentPinAuthenticatedProfileIdProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'parentPinAuthenticatedProfileIdProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$parentPinAuthenticatedProfileIdHash();

  @$internal
  @override
  ParentPinAuthenticatedProfileId create() => ParentPinAuthenticatedProfileId();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int?>(value),
    );
  }
}

String _$parentPinAuthenticatedProfileIdHash() =>
    r'005e9cd3f8082dc57916b6afec6c053ebeab9827';

/// Profile id for which the parent PIN was verified in this app session.
///
/// When this equals the active profile id, the parent is treated as acting
/// for that (child) profile — e.g. manual lifetime completions in Settings.

abstract class _$ParentPinAuthenticatedProfileId extends $Notifier<int?> {
  int? build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<int?, int?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<int?, int?>,
              int?,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
