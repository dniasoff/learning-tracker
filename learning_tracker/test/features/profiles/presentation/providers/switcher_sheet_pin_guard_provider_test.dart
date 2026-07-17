/// AUD-profiles-17: unit tests for [switcherSheetPinGuardRequiredProvider]
/// (AG-5 mirror of `lib/features/profiles/presentation/providers/
/// switcher_sheet_pin_guard_provider.dart`).
///
/// Exercises the actual provider body (no active profile, adult active
/// profile, child active profile with/without a configured PIN) through a
/// real [ProviderContainer] with [pinServiceProvider] and
/// [activeProfileIdProvider] overridden — the widget-level PIN-dialog
/// behavior is covered separately by `an2_switcher_pin_guard_test.dart`.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/profiles/domain/models/profile_model.dart';
import 'package:learning_tracker/features/profiles/domain/services/pin_service.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/switcher_sheet_pin_guard_provider.dart';
import 'package:mocktail/mocktail.dart';

class _MockPinService extends Mock implements PinService {}

/// Fixes [activeProfileIdProvider] to a constant id for the container.
class _FixedActiveProfileId extends ActiveProfileId {
  _FixedActiveProfileId(this._id);
  final int _id;
  @override
  int build() => _id;
}

ProfileModel _profile({required int id, required String mode}) => ProfileModel(
  id: id,
  accountId: 1,
  displayName: 'Test $id',
  mode: mode,
  avatarIndex: 0,
  createdAt: DateTime(2024),
  updatedAt: DateTime(2024),
);

/// Builds a container with [profileListStreamProvider] seeded and its first
/// value already resolved — [switcherSheetPinGuardRequiredProvider] reads
/// `profileListStreamProvider`'s synchronous `.asData` snapshot on its very
/// first (synchronous-up-to-the-early-return) build, so the stream must have
/// already emitted before the guard provider is read, exactly as the
/// widget-level test achieves via `tester.pump()`.
Future<ProviderContainer> _makeContainer({
  required List<ProfileModel> profiles,
  required int activeProfileId,
  required PinService pinService,
}) async {
  final container = ProviderContainer(
    overrides: [
      profileListStreamProvider.overrideWith((ref) => Stream.value(profiles)),
      activeProfileIdProvider.overrideWith(
        () => _FixedActiveProfileId(activeProfileId),
      ),
      pinServiceProvider.overrideWithValue(pinService),
    ],
  );
  addTearDown(container.dispose);
  // Keep the autoDispose profileListStreamProvider alive across the await
  // below — container.read(...future) alone has no listener, so Riverpod
  // can schedule-dispose it before its (overridden) Stream's first value is
  // delivered, throwing "disposed during loading" (see the identical
  // workaround in streak_alert_service_family_test.dart).
  final sub = container.listen(profileListStreamProvider, (_, _) {});
  addTearDown(sub.close);
  await container.read(profileListStreamProvider.future);
  return container;
}

void main() {
  late _MockPinService pinService;

  setUp(() {
    pinService = _MockPinService();
  });

  test('returns false when no profile matches the active profile id', () async {
    final container = await _makeContainer(
      profiles: [_profile(id: 1, mode: 'adult')],
      activeProfileId: 999,
      pinService: pinService,
    );

    final result = await container.read(
      switcherSheetPinGuardRequiredProvider.future,
    );

    expect(result, isFalse);
    verifyNever(() => pinService.hasProfilePin(any()));
  });

  test('returns false when the active profile is adult', () async {
    final container = await _makeContainer(
      profiles: [_profile(id: 1, mode: 'adult')],
      activeProfileId: 1,
      pinService: pinService,
    );

    final result = await container.read(
      switcherSheetPinGuardRequiredProvider.future,
    );

    expect(result, isFalse);
    // Short-circuits before ever consulting PinService for an adult profile.
    verifyNever(() => pinService.hasProfilePin(any()));
  });

  test(
    'returns true when the active profile is a child with a configured PIN',
    () async {
      when(() => pinService.hasProfilePin(2)).thenAnswer((_) async => true);
      final container = await _makeContainer(
        profiles: [_profile(id: 2, mode: 'child')],
        activeProfileId: 2,
        pinService: pinService,
      );

      final result = await container.read(
        switcherSheetPinGuardRequiredProvider.future,
      );

      expect(result, isTrue);
      verify(() => pinService.hasProfilePin(2)).called(1);
    },
  );

  test(
    'returns false when the active profile is a child with no PIN configured',
    () async {
      when(() => pinService.hasProfilePin(2)).thenAnswer((_) async => false);
      final container = await _makeContainer(
        profiles: [_profile(id: 2, mode: 'child')],
        activeProfileId: 2,
        pinService: pinService,
      );

      final result = await container.read(
        switcherSheetPinGuardRequiredProvider.future,
      );

      expect(result, isFalse);
      verify(() => pinService.hasProfilePin(2)).called(1);
    },
  );
}
