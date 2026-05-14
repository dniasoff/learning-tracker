// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'optimistic_completion_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Holds a set of completion keys that have been optimistically marked as
/// complete but not yet persisted to the database.
///
/// This enables sub-100ms perceived response when tapping "Mark Complete":
/// the UI reads from this set first, then falls back to the DB query.

@ProviderFor(OptimisticCompletionState)
final optimisticCompletionStateProvider = OptimisticCompletionStateProvider._();

/// Holds a set of completion keys that have been optimistically marked as
/// complete but not yet persisted to the database.
///
/// This enables sub-100ms perceived response when tapping "Mark Complete":
/// the UI reads from this set first, then falls back to the DB query.
final class OptimisticCompletionStateProvider
    extends $NotifierProvider<OptimisticCompletionState, Set<String>> {
  /// Holds a set of completion keys that have been optimistically marked as
  /// complete but not yet persisted to the database.
  ///
  /// This enables sub-100ms perceived response when tapping "Mark Complete":
  /// the UI reads from this set first, then falls back to the DB query.
  OptimisticCompletionStateProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'optimisticCompletionStateProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$optimisticCompletionStateHash();

  @$internal
  @override
  OptimisticCompletionState create() => OptimisticCompletionState();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Set<String> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Set<String>>(value),
    );
  }
}

String _$optimisticCompletionStateHash() =>
    r'bd666074256231ccb69ea839e95f2fd25188ff1e';

/// Holds a set of completion keys that have been optimistically marked as
/// complete but not yet persisted to the database.
///
/// This enables sub-100ms perceived response when tapping "Mark Complete":
/// the UI reads from this set first, then falls back to the DB query.

abstract class _$OptimisticCompletionState extends $Notifier<Set<String>> {
  Set<String> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<Set<String>, Set<String>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<Set<String>, Set<String>>,
              Set<String>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
