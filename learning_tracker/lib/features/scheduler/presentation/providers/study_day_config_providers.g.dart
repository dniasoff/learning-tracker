// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'study_day_config_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Firestore-backed adapter for study-day configs — **wired Phase 3, T-20**.
/// The Drift DAO-backed providers below are deprecated and will be removed in Phase 4.

@ProviderFor(studyDayConfigRepositoryAdapter)
final studyDayConfigRepositoryAdapterProvider =
    StudyDayConfigRepositoryAdapterProvider._();

/// Firestore-backed adapter for study-day configs — **wired Phase 3, T-20**.
/// The Drift DAO-backed providers below are deprecated and will be removed in Phase 4.

final class StudyDayConfigRepositoryAdapterProvider
    extends
        $FunctionalProvider<
          FirestoreStudyDayConfigRepositoryAdapter,
          FirestoreStudyDayConfigRepositoryAdapter,
          FirestoreStudyDayConfigRepositoryAdapter
        >
    with $Provider<FirestoreStudyDayConfigRepositoryAdapter> {
  /// Firestore-backed adapter for study-day configs — **wired Phase 3, T-20**.
  /// The Drift DAO-backed providers below are deprecated and will be removed in Phase 4.
  StudyDayConfigRepositoryAdapterProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'studyDayConfigRepositoryAdapterProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$studyDayConfigRepositoryAdapterHash();

  @$internal
  @override
  $ProviderElement<FirestoreStudyDayConfigRepositoryAdapter> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  FirestoreStudyDayConfigRepositoryAdapter create(Ref ref) {
    return studyDayConfigRepositoryAdapter(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FirestoreStudyDayConfigRepositoryAdapter value) {
    return $ProviderOverride(
      origin: this,
      providerOverride:
          $SyncValueProvider<FirestoreStudyDayConfigRepositoryAdapter>(value),
    );
  }
}

String _$studyDayConfigRepositoryAdapterHash() =>
    r'2d57915b84be7095936a9987bc84d37955e747f7';

/// Watch study day configs for a curriculum reactively as domain models.
///
/// **Firestore-backed** via [studyDayConfigRepositoryAdapterProvider] (Phase 3, T-20).

@ProviderFor(studyDayConfigs)
final studyDayConfigsProvider = StudyDayConfigsFamily._();

/// Watch study day configs for a curriculum reactively as domain models.
///
/// **Firestore-backed** via [studyDayConfigRepositoryAdapterProvider] (Phase 3, T-20).

final class StudyDayConfigsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<StudyDayConfigEntry>>,
          List<StudyDayConfigEntry>,
          Stream<List<StudyDayConfigEntry>>
        >
    with
        $FutureModifier<List<StudyDayConfigEntry>>,
        $StreamProvider<List<StudyDayConfigEntry>> {
  /// Watch study day configs for a curriculum reactively as domain models.
  ///
  /// **Firestore-backed** via [studyDayConfigRepositoryAdapterProvider] (Phase 3, T-20).
  StudyDayConfigsProvider._({
    required StudyDayConfigsFamily super.from,
    required CurriculumId super.argument,
  }) : super(
         retry: null,
         name: r'studyDayConfigsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$studyDayConfigsHash();

  @override
  String toString() {
    return r'studyDayConfigsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<StudyDayConfigEntry>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<StudyDayConfigEntry>> create(Ref ref) {
    final argument = this.argument as CurriculumId;
    return studyDayConfigs(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is StudyDayConfigsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$studyDayConfigsHash() => r'f5fcd8b947d21bfb44cfd92d8cc31db7b5326036';

/// Watch study day configs for a curriculum reactively as domain models.
///
/// **Firestore-backed** via [studyDayConfigRepositoryAdapterProvider] (Phase 3, T-20).

final class StudyDayConfigsFamily extends $Family
    with
        $FunctionalFamilyOverride<
          Stream<List<StudyDayConfigEntry>>,
          CurriculumId
        > {
  StudyDayConfigsFamily._()
    : super(
        retry: null,
        name: r'studyDayConfigsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Watch study day configs for a curriculum reactively as domain models.
  ///
  /// **Firestore-backed** via [studyDayConfigRepositoryAdapterProvider] (Phase 3, T-20).

  StudyDayConfigsProvider call(CurriculumId curriculumId) =>
      StudyDayConfigsProvider._(argument: curriculumId, from: this);

  @override
  String toString() => r'studyDayConfigsProvider';
}

/// Check if today is a study day for a curriculum.
///
/// **Firestore-backed** via [studyDayConfigRepositoryAdapterProvider] (Phase 3, T-20).

@ProviderFor(isStudyDay)
final isStudyDayProvider = IsStudyDayFamily._();

/// Check if today is a study day for a curriculum.
///
/// **Firestore-backed** via [studyDayConfigRepositoryAdapterProvider] (Phase 3, T-20).

final class IsStudyDayProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, FutureOr<bool>>
    with $FutureModifier<bool>, $FutureProvider<bool> {
  /// Check if today is a study day for a curriculum.
  ///
  /// **Firestore-backed** via [studyDayConfigRepositoryAdapterProvider] (Phase 3, T-20).
  IsStudyDayProvider._({
    required IsStudyDayFamily super.from,
    required CurriculumId super.argument,
  }) : super(
         retry: null,
         name: r'isStudyDayProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$isStudyDayHash();

  @override
  String toString() {
    return r'isStudyDayProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<bool> create(Ref ref) {
    final argument = this.argument as CurriculumId;
    return isStudyDay(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is IsStudyDayProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$isStudyDayHash() => r'6090f2a949b4c370a4fadf1db3eec8354c030b95';

/// Check if today is a study day for a curriculum.
///
/// **Firestore-backed** via [studyDayConfigRepositoryAdapterProvider] (Phase 3, T-20).

final class IsStudyDayFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<bool>, CurriculumId> {
  IsStudyDayFamily._()
    : super(
        retry: null,
        name: r'isStudyDayProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Check if today is a study day for a curriculum.
  ///
  /// **Firestore-backed** via [studyDayConfigRepositoryAdapterProvider] (Phase 3, T-20).

  IsStudyDayProvider call(CurriculumId curriculumId) =>
      IsStudyDayProvider._(argument: curriculumId, from: this);

  @override
  String toString() => r'isStudyDayProvider';
}

/// Get count of study days per week for a curriculum.
///
/// **Firestore-backed** via [studyDayConfigRepositoryAdapterProvider] (Phase 3, T-20).

@ProviderFor(studyDaysPerWeek)
final studyDaysPerWeekProvider = StudyDaysPerWeekFamily._();

/// Get count of study days per week for a curriculum.
///
/// **Firestore-backed** via [studyDayConfigRepositoryAdapterProvider] (Phase 3, T-20).

final class StudyDaysPerWeekProvider
    extends $FunctionalProvider<AsyncValue<int>, int, FutureOr<int>>
    with $FutureModifier<int>, $FutureProvider<int> {
  /// Get count of study days per week for a curriculum.
  ///
  /// **Firestore-backed** via [studyDayConfigRepositoryAdapterProvider] (Phase 3, T-20).
  StudyDaysPerWeekProvider._({
    required StudyDaysPerWeekFamily super.from,
    required CurriculumId super.argument,
  }) : super(
         retry: null,
         name: r'studyDaysPerWeekProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$studyDaysPerWeekHash();

  @override
  String toString() {
    return r'studyDaysPerWeekProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<int> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<int> create(Ref ref) {
    final argument = this.argument as CurriculumId;
    return studyDaysPerWeek(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is StudyDaysPerWeekProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$studyDaysPerWeekHash() => r'e63d8c4a16b1d90ed23b9b923bd8684f9289b881';

/// Get count of study days per week for a curriculum.
///
/// **Firestore-backed** via [studyDayConfigRepositoryAdapterProvider] (Phase 3, T-20).

final class StudyDaysPerWeekFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<int>, CurriculumId> {
  StudyDaysPerWeekFamily._()
    : super(
        retry: null,
        name: r'studyDaysPerWeekProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Get count of study days per week for a curriculum.
  ///
  /// **Firestore-backed** via [studyDayConfigRepositoryAdapterProvider] (Phase 3, T-20).

  StudyDaysPerWeekProvider call(CurriculumId curriculumId) =>
      StudyDaysPerWeekProvider._(argument: curriculumId, from: this);

  @override
  String toString() => r'studyDaysPerWeekProvider';
}
