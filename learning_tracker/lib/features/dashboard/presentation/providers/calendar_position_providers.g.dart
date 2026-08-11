// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'calendar_position_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provides calendar-relative position for a program track.
///
/// Uses the enrolled program + selected starting anchor (today or offset) to
/// compute expected progress and compare against completed learn items.
///
/// AD-25: [curriculumId] IS the track — there is no separate per-device
/// track id to resolve any more.

@ProviderFor(programCalendarPosition)
final programCalendarPositionProvider = ProgramCalendarPositionFamily._();

/// Provides calendar-relative position for a program track.
///
/// Uses the enrolled program + selected starting anchor (today or offset) to
/// compute expected progress and compare against completed learn items.
///
/// AD-25: [curriculumId] IS the track — there is no separate per-device
/// track id to resolve any more.

final class ProgramCalendarPositionProvider
    extends
        $FunctionalProvider<
          AsyncValue<CalendarPosition>,
          CalendarPosition,
          FutureOr<CalendarPosition>
        >
    with $FutureModifier<CalendarPosition>, $FutureProvider<CalendarPosition> {
  /// Provides calendar-relative position for a program track.
  ///
  /// Uses the enrolled program + selected starting anchor (today or offset) to
  /// compute expected progress and compare against completed learn items.
  ///
  /// AD-25: [curriculumId] IS the track — there is no separate per-device
  /// track id to resolve any more.
  ProgramCalendarPositionProvider._({
    required ProgramCalendarPositionFamily super.from,
    required CurriculumId super.argument,
  }) : super(
         retry: null,
         name: r'programCalendarPositionProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$programCalendarPositionHash();

  @override
  String toString() {
    return r'programCalendarPositionProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<CalendarPosition> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<CalendarPosition> create(Ref ref) {
    final argument = this.argument as CurriculumId;
    return programCalendarPosition(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ProgramCalendarPositionProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$programCalendarPositionHash() =>
    r'b2692f86990b62a39396596fd06f3a0a074674f9';

/// Provides calendar-relative position for a program track.
///
/// Uses the enrolled program + selected starting anchor (today or offset) to
/// compute expected progress and compare against completed learn items.
///
/// AD-25: [curriculumId] IS the track — there is no separate per-device
/// track id to resolve any more.

final class ProgramCalendarPositionFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<CalendarPosition>, CurriculumId> {
  ProgramCalendarPositionFamily._()
    : super(
        retry: null,
        name: r'programCalendarPositionProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Provides calendar-relative position for a program track.
  ///
  /// Uses the enrolled program + selected starting anchor (today or offset) to
  /// compute expected progress and compare against completed learn items.
  ///
  /// AD-25: [curriculumId] IS the track — there is no separate per-device
  /// track id to resolve any more.

  ProgramCalendarPositionProvider call(CurriculumId curriculumId) =>
      ProgramCalendarPositionProvider._(argument: curriculumId, from: this);

  @override
  String toString() => r'programCalendarPositionProvider';
}
