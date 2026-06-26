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

@ProviderFor(programCalendarPosition)
final programCalendarPositionProvider = ProgramCalendarPositionFamily._();

/// Provides calendar-relative position for a program track.
///
/// Uses the enrolled program + selected starting anchor (today or offset) to
/// compute expected progress and compare against completed learn items.

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
  ProgramCalendarPositionProvider._({
    required ProgramCalendarPositionFamily super.from,
    required int super.argument,
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
    final argument = this.argument as int;
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
    r'80fba859bc4e685f062e6800c3ef46a0165d8bc8';

/// Provides calendar-relative position for a program track.
///
/// Uses the enrolled program + selected starting anchor (today or offset) to
/// compute expected progress and compare against completed learn items.

final class ProgramCalendarPositionFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<CalendarPosition>, int> {
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

  ProgramCalendarPositionProvider call(int trackId) =>
      ProgramCalendarPositionProvider._(argument: trackId, from: this);

  @override
  String toString() => r'programCalendarPositionProvider';
}
