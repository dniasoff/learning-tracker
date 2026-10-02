// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'gamification_screen.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The streak calendar's active days: the last 30 days with counted
/// learning in the curriculum in view (DNI-479; AD-40 has no profile-wide
/// streak).

@ProviderFor(streakCalendar)
final streakCalendarProvider = StreakCalendarProvider._();

/// The streak calendar's active days: the last 30 days with counted
/// learning in the curriculum in view (DNI-479; AD-40 has no profile-wide
/// streak).

final class StreakCalendarProvider
    extends
        $FunctionalProvider<
          AsyncValue<Set<DateTime>>,
          Set<DateTime>,
          FutureOr<Set<DateTime>>
        >
    with $FutureModifier<Set<DateTime>>, $FutureProvider<Set<DateTime>> {
  /// The streak calendar's active days: the last 30 days with counted
  /// learning in the curriculum in view (DNI-479; AD-40 has no profile-wide
  /// streak).
  StreakCalendarProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'streakCalendarProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$streakCalendarHash();

  @$internal
  @override
  $FutureProviderElement<Set<DateTime>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<Set<DateTime>> create(Ref ref) {
    return streakCalendar(ref);
  }
}

String _$streakCalendarHash() => r'1459c14a57fec867056b5be29c4598d6da444ea9';
