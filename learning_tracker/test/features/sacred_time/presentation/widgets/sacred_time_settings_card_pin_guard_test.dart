/// AUD-sacred_time-08 regression test: SacredTimeSettingsCard must gate its
/// escalating location actions (Detect / Choose City) behind a Parent PIN
/// challenge when `pinGuardRequired` is true — mirroring
/// ProfileSwitcherSheet's AN-2 `_guardEscalating` pattern
/// (`an2_switcher_pin_guard_test.dart`).
///
/// Why this card needs its own gate: DEC-26 made Sacred Time / location a
/// DEVICE-scoped setting, so the card renders in Settings' DEVICE section for
/// every profile — including children — and `SettingsRoute` itself carries no
/// route-level PIN/child-mode guard (app_router.dart: `/` → `settings` has
/// only `authGuard`, unlike the PIN-guarded `/parent-mode/*` routes). Without
/// an in-card gate, a child on a shared device could trigger GPS detection or
/// pick a new city with no parent authentication.
///
/// RED -> GREEN cycle:
///   RED:  tapping Detect/Choose City while pinGuardRequired=true fires the
///         action directly — no PIN dialog shown.
///   GREEN: the same taps show the Parent PIN verification dialog first, and
///          the underlying action does not run until it succeeds.
@Tags(['sacred_time', 'settings_card', 'pin_guard', 'regression'])
library;

import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings.dart';
import 'package:learning_tracker/features/profiles/profiles.dart';
import 'package:learning_tracker/features/sacred_time/data/services/location_service.dart';
import 'package:learning_tracker/features/sacred_time/domain/models/location_fetch_result.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/learner_settings_editor_provider.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/sacred_time_location_access_provider.dart';
import 'package:learning_tracker/features/sacred_time/presentation/widgets/sacred_time_settings_card.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/learner_state_fixtures.dart';
import '../../../../helpers/pump_app.dart';

class _MockStackRouter extends Mock implements StackRouter {}

class _FakePageRouteInfo extends Fake implements PageRouteInfo {}

/// Skips real GPS I/O — the guard is what's under test, not the detect
/// flow itself.
class _FakeLocationService extends LocationService {
  const _FakeLocationService();

  @override
  Future<LocationFetchResult> detectCurrent() async =>
      const LocationFetchServiceDisabled();
}

Widget _buildCard({
  bool pinGuardRequired = false,
  AsyncValue<bool>? pinGuard,
  StackRouter? router,
  List<Override> overrides = const [],
}) {
  final mockRouter = router ?? _MockStackRouter();
  return pumpApp(
    overrides: [
      ...overrides,
      activeLearnerSettingsProvider.overrideWithValue(
        const AsyncData(
          LearnerSettings(profileId: profileUlid, timeZone: 'UTC'),
        ),
      ),
      learnerSettingsEditorProvider.overrideWithValue(
        LearnerSettingsEditor(
          commands: () async => null,
          scope: () async => null,
          locationService: const _FakeLocationService(),
          deviceTimeZone: () async => null,
        ),
      ),
    ],
    child: StackRouterScope(
      controller: mockRouter,
      stateHash: 0,
      child: Scaffold(
        body: SacredTimeSettingsCard(
          pinGuard: pinGuard ?? AsyncData(pinGuardRequired),
          activeProfileId: '01JQ3K5M8N2P4R6T7V9X0Z1AB',
        ),
      ),
    ),
  );
}

class _MockPinService extends Mock implements PinService {}

const _adult = '01ARZ3NDEKTSV4RRFFQ69G5FA1';
const _child = '01ARZ3NDEKTSV4RRFFQ69G5FC1';
const _otherChild = '01ARZ3NDEKTSV4RRFFQ69G5FC2';

LearnerProfileEntity _learner(String id, ProfileMode mode) =>
    LearnerProfileEntity(
      profileId: id,
      displayName: id,
      mode: mode,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );

final _account = [
  _learner(_adult, ProfileMode.adult),
  _learner(_child, ProfileMode.child),
  _learner(_otherChild, ProfileMode.child),
];

/// The [ButtonStyleButton] labelled [label] (Detect / Choose city).
ButtonStyleButton _button(WidgetTester tester, String label) =>
    tester.widget<ButtonStyleButton>(
      find.ancestor(
        of: find.text(label),
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
      ),
    );

/// Asserts the card's three settings actions are disabled and that tapping
/// them neither prompts, nor runs the action, nor navigates.
Future<void> _expectActionsLockedShut(
  WidgetTester tester, {
  StackRouter? router,
}) async {
  expect(_button(tester, 'Detect').onPressed, isNull);
  expect(_button(tester, 'Choose city').onPressed, isNull);
  expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNull);

  await tester.tap(find.text('Detect'), warnIfMissed: false);
  await tester.tap(find.text('Choose city'), warnIfMissed: false);
  await tester.tap(find.byType(Switch), warnIfMissed: false);
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));

  expect(find.text('Enter Parent PIN'), findsNothing);
  expect(find.byType(SnackBar), findsNothing);
  if (router != null) verifyNever(() => router.push<Object?>(any()));
}

class _Selected extends SelectedProfileId {
  _Selected(this._id);

  final String? _id;

  @override
  String? build() => _id;

  /// Switches the device holder (a profile switch), without the real
  /// notifier's active-profile-doc side effect.
  @override
  void select(String profileId) => state = profileId;
}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakePageRouteInfo());
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AUD-sacred_time-08 PIN guard for Sacred Time location actions', () {
    testWidgets('Detect shows Parent PIN dialog when pinGuardRequired=true', (
      tester,
    ) async {
      await tester.pumpWidget(_buildCard(pinGuardRequired: true));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Detect'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.text('Enter Parent PIN'),
        findsOneWidget,
        reason:
            'AUD-sacred_time-08: tapping Detect while pinGuardRequired is '
            'true must show the Parent PIN verification dialog first.',
      );
    });

    testWidgets(
      'Choose city shows Parent PIN dialog when pinGuardRequired=true',
      (tester) async {
        await tester.pumpWidget(_buildCard(pinGuardRequired: true));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Choose city'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(
          find.text('Enter Parent PIN'),
          findsOneWidget,
          reason:
              'AUD-sacred_time-08: tapping Choose city while '
              'pinGuardRequired is true must show the Parent PIN '
              'verification dialog first, not navigate directly.',
        );
      },
    );

    testWidgets(
      'DNI-481: the Israel switch (a learner setting) shows the Parent PIN '
      'dialog when pinGuardRequired=true',
      (tester) async {
        await tester.pumpWidget(_buildCard(pinGuardRequired: true));
        await tester.pumpAndSettle();

        await tester.tap(find.byType(Switch));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('Enter Parent PIN'), findsOneWidget);
      },
    );

    testWidgets(
      'no PIN dialog and Detect proceeds when pinGuardRequired=false',
      (tester) async {
        await tester.pumpWidget(_buildCard(pinGuardRequired: false));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Detect'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(
          find.text('Enter Parent PIN'),
          findsNothing,
          reason:
              'AUD-sacred_time-08: when the guard is not required, Detect '
              'must fire immediately with no PIN prompt.',
        );
        // The fake notifier's detect() resolves to ServiceDisabled — its
        // SnackBar confirms the action actually ran, not just that no dialog
        // appeared.
        await tester.pump(const Duration(seconds: 1));
        expect(find.byType(SnackBar), findsOneWidget);
      },
    );

    testWidgets(
      'no PIN dialog and Choose city navigates when pinGuardRequired=false',
      (tester) async {
        final mockRouter = _MockStackRouter();
        when(
          () => mockRouter.push<Object?>(any()),
        ).thenAnswer((_) async => null);

        await tester.pumpWidget(
          _buildCard(pinGuardRequired: false, router: mockRouter),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Choose city'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('Enter Parent PIN'), findsNothing);
        verify(() => mockRouter.push<Object?>(any())).called(1);
      },
    );

    testWidgets(
      'DNI-481: Choose city with the correct Parent PIN hands the city '
      'picker route guard a one-shot pass for the verified profile, so the '
      'holder is not asked twice',
      (tester) async {
        const verifiedId = '01JQ3K5M8N2P4R6T7V9X0Z1AB';
        final pinService = _MockPinService();
        when(
          () => pinService.verifyProfilePin(any(), any()),
        ).thenAnswer((_) async => true);
        final access = SacredTimeLocationAccess();
        final mockRouter = _MockStackRouter();
        when(
          () => mockRouter.push<Object?>(any()),
        ).thenAnswer((_) async => null);

        await tester.pumpWidget(
          _buildCard(
            pinGuardRequired: true,
            router: mockRouter,
            overrides: [
              pinServiceProvider.overrideWithValue(pinService),
              sacredTimeLocationAccessProvider.overrideWithValue(access),
            ],
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Choose city'));
        await tester.pumpAndSettle();
        expect(find.text('Enter Parent PIN'), findsOneWidget);
        for (final digit in '1234'.split('')) {
          await tester.tap(find.text(digit).last);
          await tester.pump();
        }
        await tester.pumpAndSettle();

        verify(() => mockRouter.push<Object?>(any())).called(1);
        expect(access.consume(verifiedId), isTrue);
      },
    );
  });

  group('fail closed while the PIN guard is unresolved (cold start, '
      'transient profile-read failure)', () {
    testWidgets('a loading guard disables Detect, Choose city and the '
        'Israel switch', (tester) async {
      final router = _MockStackRouter();
      await tester.pumpWidget(
        _buildCard(pinGuard: const AsyncLoading(), router: router),
      );
      await tester.pumpAndSettle();
      await _expectActionsLockedShut(tester, router: router);
    });

    testWidgets('an errored guard disables Detect, Choose city and the '
        'Israel switch', (tester) async {
      final router = _MockStackRouter();
      await tester.pumpWidget(
        _buildCard(
          pinGuard: AsyncError<bool>(StateError('read'), StackTrace.empty),
          router: router,
        ),
      );
      await tester.pumpAndSettle();
      await _expectActionsLockedShut(tester, router: router);
    });

    /// Composes the provider with the card as `SettingsScreen` does.
    Widget composed({
      required Stream<List<LearnerProfileEntity>> profiles,
      required Object? selected,
      required PinService pinService,
    }) => pumpApp(
      overrides: [
        selectedProfileIdProvider.overrideWith(
          () =>
              selected is _Selected ? selected : _Selected(selected as String?),
        ),
        profileListStreamProvider.overrideWith((ref) => profiles),
        pinServiceProvider.overrideWithValue(pinService),
        activeLearnerSettingsProvider.overrideWithValue(
          const AsyncData(
            LearnerSettings(profileId: profileUlid, timeZone: 'UTC'),
          ),
        ),
        learnerSettingsEditorProvider.overrideWithValue(
          LearnerSettingsEditor(
            commands: () async => null,
            scope: () async => null,
            locationService: const _FakeLocationService(),
            deviceTimeZone: () async => null,
          ),
        ),
      ],
      child: Scaffold(
        body: Consumer(
          builder: (context, ref, _) => SacredTimeSettingsCard(
            pinGuard: ref.watch(sacredTimeLocationPinGuardRequiredProvider),
            activeProfileId: ref.watch(selectedProfileIdProvider),
          ),
        ),
      ),
    );

    testWidgets('a child with a Parent PIN on a cold start: no access while '
        'the profile list loads; the PIN is asked for once it resolves', (
      tester,
    ) async {
      final pinService = _MockPinService();
      when(() => pinService.hasProfilePin(any())).thenAnswer((_) async => true);
      final profiles = StreamController<List<LearnerProfileEntity>>();
      addTearDown(profiles.close);

      await tester.pumpWidget(
        composed(
          profiles: profiles.stream,
          selected: _child,
          pinService: pinService,
        ),
      );
      await tester.pump();
      await _expectActionsLockedShut(tester);

      profiles.add(_account);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Detect'));
      await tester.pumpAndSettle();
      expect(find.text('Enter Parent PIN'), findsOneWidget);
    });

    testWidgets('switching the holder from an adult to a guarded child: '
        'no access while the guard re-resolves (the adult\'s "no guard" is '
        'never borrowed)', (tester) async {
      final childPin = Completer<bool>();
      final pinService = _MockPinService();
      when(
        () => pinService.hasProfilePin(_child),
      ).thenAnswer((_) => childPin.future);
      final selected = _Selected(_adult);

      await tester.pumpWidget(
        composed(
          profiles: Stream.value(_account),
          selected: selected,
          pinService: pinService,
        ),
      );
      await tester.pumpAndSettle();
      expect(_button(tester, 'Detect').onPressed, isNotNull);

      selected.select(_child);
      await tester.pump();
      await _expectActionsLockedShut(tester);

      childPin.complete(true);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Detect'));
      await tester.pumpAndSettle();
      expect(find.text('Enter Parent PIN'), findsOneWidget);
    });

    testWidgets('a child with a Parent PIN when the profile read fails: '
        'no access', (tester) async {
      final pinService = _MockPinService();
      when(() => pinService.hasProfilePin(any())).thenAnswer((_) async => true);

      await tester.pumpWidget(
        composed(
          profiles: Stream.error(StateError('transient')),
          selected: _child,
          pinService: pinService,
        ),
      );
      await tester.pumpAndSettle();
      await _expectActionsLockedShut(tester);
    });

    testWidgets('a device holder missing from the loaded profiles: no '
        'access', (tester) async {
      final pinService = _MockPinService();
      when(() => pinService.hasProfilePin(any())).thenAnswer((_) async => true);

      await tester.pumpWidget(
        composed(
          profiles: Stream.value(_account),
          selected: '01ARZ3NDEKTSV4RRFFQ69G5FZZ',
          pinService: pinService,
        ),
      );
      await tester.pumpAndSettle();
      await _expectActionsLockedShut(tester);
    });

    testWidgets('an adult holder: the actions run with no PIN once the '
        'guard resolves', (tester) async {
      final pinService = _MockPinService();
      when(() => pinService.hasProfilePin(any())).thenAnswer((_) async => true);

      await tester.pumpWidget(
        composed(
          profiles: Stream.value(_account),
          selected: _adult,
          pinService: pinService,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Detect'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Enter Parent PIN'), findsNothing);
      expect(find.byType(SnackBar), findsOneWidget);
    });
  });

  group('DNI-481 after-lock prompt: the PIN of the TARGET learner', () {
    Future<List<String>?> challenges({
      required String? selected,
      required String target,
      Set<String> withPin = const {_child, _otherChild},
    }) => learnerLocationPromptPinChallenges(
      selectedProfileId: selected,
      targetProfileId: target,
      profiles: _account,
      hasProfilePin: (id) async => withPin.contains(id),
    );

    test('adult holder, guarded child target: the CHILD PIN is asked for '
        '(an adult selection never vouches for the target)', () async {
      expect(await challenges(selected: _adult, target: _child), [_child]);
    });

    test('guarded child holder, adult target: the holder PIN is asked for '
        '(leaving the child context escalates)', () async {
      expect(await challenges(selected: _child, target: _adult), [_child]);
    });

    test('guarded child holder, guarded sibling target: both PINs', () async {
      expect(await challenges(selected: _child, target: _otherChild), [
        _child,
        _otherChild,
      ]);
    });

    test('the active learner itself: the existing holder rule', () async {
      expect(await challenges(selected: _child, target: _child), [_child]);
      expect(await challenges(selected: _adult, target: _adult), isEmpty);
    });

    test('no PIN configured, adult target: nothing to ask', () async {
      expect(
        await challenges(selected: _child, target: _adult, withPin: {}),
        isEmpty,
      );
    });

    test('a target outside the loaded account is refused', () async {
      expect(
        await challenges(selected: _adult, target: 'not-on-account'),
        isNull,
      );
    });

    testWidgets('guardLearnerLocationPromptAccess: adult selected, guarded '
        'child target — the Parent PIN dialog for the child; cancelling '
        'refuses (no picker, no governed write)', (tester) async {
      final pinService = _MockPinService();
      when(() => pinService.hasProfilePin(any())).thenAnswer(
        (invocation) async => invocation.positionalArguments.first == _child,
      );
      bool? granted;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            pinServiceProvider.overrideWithValue(pinService),
            selectedProfileIdProvider.overrideWith(() => _Selected(_adult)),
            profileListStreamProvider.overrideWith(
              (ref) => Stream.value(_account),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Consumer(
              builder: (context, ref, _) => TextButton(
                onPressed: () async =>
                    granted = await guardLearnerLocationPromptAccess(
                      context,
                      ref,
                      _child,
                    ),
                child: const Text('SET LOCATION'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('SET LOCATION'));
      await tester.pumpAndSettle();

      expect(find.text('Enter Parent PIN'), findsOneWidget);
      verify(() => pinService.hasProfilePin(_child)).called(1);

      Navigator.of(
        tester.element(find.text('Enter Parent PIN')),
        rootNavigator: true,
      ).pop(false);
      await tester.pumpAndSettle();
      expect(granted, isFalse);
    });

    testWidgets('guardLearnerLocationPromptAccess: adult selected, unguarded '
        'adult target — granted with no dialog', (tester) async {
      final pinService = _MockPinService();
      when(() => pinService.hasProfilePin(any())).thenAnswer((_) async => true);
      const otherAdult = '01ARZ3NDEKTSV4RRFFQ69G5FA2';
      bool? granted;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            pinServiceProvider.overrideWithValue(pinService),
            selectedProfileIdProvider.overrideWith(() => _Selected(_adult)),
            profileListStreamProvider.overrideWith(
              (ref) => Stream.value([
                ..._account,
                _learner(otherAdult, ProfileMode.adult),
              ]),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Consumer(
              builder: (context, ref, _) => TextButton(
                onPressed: () async =>
                    granted = await guardLearnerLocationPromptAccess(
                      context,
                      ref,
                      otherAdult,
                    ),
                child: const Text('SET LOCATION'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('SET LOCATION'));
      await tester.pumpAndSettle();
      expect(find.text('Enter Parent PIN'), findsNothing);
      expect(granted, isTrue);
    });

    testWidgets('guardLearnerLocationPromptAccess: the correct child PIN '
        'grants the city picker route guard a one-shot pass for the TARGET '
        '(the holder once the picker opens)', (tester) async {
      final pinService = _MockPinService();
      when(() => pinService.hasProfilePin(any())).thenAnswer(
        (invocation) async => invocation.positionalArguments.first == _child,
      );
      when(
        () => pinService.verifyProfilePin(any(), any()),
      ).thenAnswer((_) async => true);
      final access = SacredTimeLocationAccess();
      bool? granted;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            pinServiceProvider.overrideWithValue(pinService),
            selectedProfileIdProvider.overrideWith(() => _Selected(_adult)),
            profileListStreamProvider.overrideWith(
              (ref) => Stream.value(_account),
            ),
            sacredTimeLocationAccessProvider.overrideWithValue(access),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Consumer(
              builder: (context, ref, _) => TextButton(
                onPressed: () async =>
                    granted = await guardLearnerLocationPromptAccess(
                      context,
                      ref,
                      _child,
                    ),
                child: const Text('SET LOCATION'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('SET LOCATION'));
      await tester.pumpAndSettle();
      expect(find.text('Enter Parent PIN'), findsOneWidget);
      for (final digit in '1234'.split('')) {
        await tester.tap(find.text(digit).last);
        await tester.pump();
      }
      await tester.pumpAndSettle();

      expect(granted, isTrue);
      expect(access.consume(_child), isTrue);
    });

    testWidgets('guardLearnerLocationPromptAccess: nothing to verify grants '
        'no pass', (tester) async {
      final pinService = _MockPinService();
      when(
        () => pinService.hasProfilePin(any()),
      ).thenAnswer((_) async => false);
      final access = SacredTimeLocationAccess();
      bool? granted;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            pinServiceProvider.overrideWithValue(pinService),
            selectedProfileIdProvider.overrideWith(() => _Selected(_adult)),
            profileListStreamProvider.overrideWith(
              (ref) => Stream.value(_account),
            ),
            sacredTimeLocationAccessProvider.overrideWithValue(access),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Consumer(
              builder: (context, ref, _) => TextButton(
                onPressed: () async =>
                    granted = await guardLearnerLocationPromptAccess(
                      context,
                      ref,
                      _child,
                    ),
                child: const Text('SET LOCATION'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('SET LOCATION'));
      await tester.pumpAndSettle();

      expect(granted, isTrue);
      expect(access.consume(_child), isFalse);
    });
  });
}
