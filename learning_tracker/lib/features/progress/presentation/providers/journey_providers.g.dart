// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'journey_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Sort mode toggle for journey screen (grouped vs chronological).

@ProviderFor(JourneySortModeNotifier)
final journeySortModeProvider = JourneySortModeNotifierProvider._();

/// Sort mode toggle for journey screen (grouped vs chronological).
final class JourneySortModeNotifierProvider
    extends $NotifierProvider<JourneySortModeNotifier, JourneySortModeValue> {
  /// Sort mode toggle for journey screen (grouped vs chronological).
  JourneySortModeNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'journeySortModeProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$journeySortModeNotifierHash();

  @$internal
  @override
  JourneySortModeNotifier create() => JourneySortModeNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(JourneySortModeValue value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<JourneySortModeValue>(value),
    );
  }
}

String _$journeySortModeNotifierHash() =>
    r'8adc83e7baa4c71124ab4dc3b4b140bec4647e8b';

/// Sort mode toggle for journey screen (grouped vs chronological).

abstract class _$JourneySortModeNotifier
    extends $Notifier<JourneySortModeValue> {
  JourneySortModeValue build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<JourneySortModeValue, JourneySortModeValue>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<JourneySortModeValue, JourneySortModeValue>,
              JourneySortModeValue,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

/// Computes the full JourneyViewModel for a given profile.

@ProviderFor(journeyViewModel)
final journeyViewModelProvider = JourneyViewModelFamily._();

/// Computes the full JourneyViewModel for a given profile.

final class JourneyViewModelProvider
    extends
        $FunctionalProvider<
          AsyncValue<JourneyViewModel>,
          JourneyViewModel,
          FutureOr<JourneyViewModel>
        >
    with $FutureModifier<JourneyViewModel>, $FutureProvider<JourneyViewModel> {
  /// Computes the full JourneyViewModel for a given profile.
  JourneyViewModelProvider._({
    required JourneyViewModelFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'journeyViewModelProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$journeyViewModelHash();

  @override
  String toString() {
    return r'journeyViewModelProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<JourneyViewModel> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<JourneyViewModel> create(Ref ref) {
    final argument = this.argument as int;
    return journeyViewModel(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is JourneyViewModelProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$journeyViewModelHash() => r'fc6b2588b5d98e976e5d99cbb3c9920f2f8102a5';

/// Computes the full JourneyViewModel for a given profile.

final class JourneyViewModelFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<JourneyViewModel>, int> {
  JourneyViewModelFamily._()
    : super(
        retry: null,
        name: r'journeyViewModelProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Computes the full JourneyViewModel for a given profile.

  JourneyViewModelProvider call(int profileId) =>
      JourneyViewModelProvider._(argument: profileId, from: this);

  @override
  String toString() => r'journeyViewModelProvider';
}
