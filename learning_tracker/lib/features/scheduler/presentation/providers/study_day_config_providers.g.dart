// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'study_day_config_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Watch study day configs for a curriculum reactively as domain models.

@ProviderFor(studyDayConfigs)
final studyDayConfigsProvider = StudyDayConfigsFamily._();

/// Watch study day configs for a curriculum reactively as domain models.

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

String _$studyDayConfigsHash() => r'b9d02f088d9e834d2227728fd57eb775cbe0b09c';

/// Watch study day configs for a curriculum reactively as domain models.

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

  StudyDayConfigsProvider call(CurriculumId curriculumId) =>
      StudyDayConfigsProvider._(argument: curriculumId, from: this);

  @override
  String toString() => r'studyDayConfigsProvider';
}

/// Check if today is a study day for a curriculum.

@ProviderFor(isStudyDay)
final isStudyDayProvider = IsStudyDayFamily._();

/// Check if today is a study day for a curriculum.

final class IsStudyDayProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, FutureOr<bool>>
    with $FutureModifier<bool>, $FutureProvider<bool> {
  /// Check if today is a study day for a curriculum.
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

String _$isStudyDayHash() => r'8ce57b3cde9b7c898bf333372d76df56f205c878';

/// Check if today is a study day for a curriculum.

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

  IsStudyDayProvider call(CurriculumId curriculumId) =>
      IsStudyDayProvider._(argument: curriculumId, from: this);

  @override
  String toString() => r'isStudyDayProvider';
}

/// Get count of study days per week for a curriculum.

@ProviderFor(studyDaysPerWeek)
final studyDaysPerWeekProvider = StudyDaysPerWeekFamily._();

/// Get count of study days per week for a curriculum.

final class StudyDaysPerWeekProvider
    extends $FunctionalProvider<AsyncValue<int>, int, FutureOr<int>>
    with $FutureModifier<int>, $FutureProvider<int> {
  /// Get count of study days per week for a curriculum.
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

String _$studyDaysPerWeekHash() => r'6efda9d3025748ed89f558bb981cdc33ba958d9a';

/// Get count of study days per week for a curriculum.

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

  StudyDaysPerWeekProvider call(CurriculumId curriculumId) =>
      StudyDaysPerWeekProvider._(argument: curriculumId, from: this);

  @override
  String toString() => r'studyDaysPerWeekProvider';
}

/// Toggle a day between study and review.

@ProviderFor(toggleStudyDay)
final toggleStudyDayProvider = ToggleStudyDayFamily._();

/// Toggle a day between study and review.

final class ToggleStudyDayProvider
    extends $FunctionalProvider<AsyncValue<void>, void, FutureOr<void>>
    with $FutureModifier<void>, $FutureProvider<void> {
  /// Toggle a day between study and review.
  ToggleStudyDayProvider._({
    required ToggleStudyDayFamily super.from,
    required (CurriculumId, int, DayType) super.argument,
  }) : super(
         retry: null,
         name: r'toggleStudyDayProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$toggleStudyDayHash();

  @override
  String toString() {
    return r'toggleStudyDayProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<void> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<void> create(Ref ref) {
    final argument = this.argument as (CurriculumId, int, DayType);
    return toggleStudyDay(ref, argument.$1, argument.$2, argument.$3);
  }

  @override
  bool operator ==(Object other) {
    return other is ToggleStudyDayProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$toggleStudyDayHash() => r'7801f428051abfd237c0693218aa28f68538c147';

/// Toggle a day between study and review.

final class ToggleStudyDayFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<void>,
          (CurriculumId, int, DayType)
        > {
  ToggleStudyDayFamily._()
    : super(
        retry: null,
        name: r'toggleStudyDayProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Toggle a day between study and review.

  ToggleStudyDayProvider call(
    CurriculumId curriculumId,
    int dayOfWeek,
    DayType newType,
  ) => ToggleStudyDayProvider._(
    argument: (curriculumId, dayOfWeek, newType),
    from: this,
  );

  @override
  String toString() => r'toggleStudyDayProvider';
}
