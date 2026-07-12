// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'gamification_screen.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(streakCalendar)
final streakCalendarProvider = StreakCalendarProvider._();

final class StreakCalendarProvider
    extends
        $FunctionalProvider<
          AsyncValue<Set<DateTime>>,
          Set<DateTime>,
          FutureOr<Set<DateTime>>
        >
    with $FutureModifier<Set<DateTime>>, $FutureProvider<Set<DateTime>> {
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

String _$streakCalendarHash() => r'c815e6d2ad3f4052077ea2e07215b28e39f784e7';
