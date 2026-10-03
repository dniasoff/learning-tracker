// SacredTimeLocationGuard (DNI-481 AC-3, AUD-sacred_time-08): the city
// picker writes the active learner's lock settings, so a child holder with a
// Parent PIN reaches it only after verifying that PIN — also on a direct
// deep link, which skips the Settings card's own PIN check.
//
// Unit cases drive onNavigation with a mocked resolver; the regression case
// navigates a real router straight to `/sacred-time/city`.
@Tags(['sacred_time', 'city_picker'])
library;

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/app/router/app_router.dart';
import 'package:learning_tracker/app/router/guards/sacred_time_location_guard.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/features/profiles/domain/models/learner_profile_entity.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/sacred_time_location_access_provider.dart';
import 'package:learning_tracker/features/sacred_time/presentation/screens/city_picker_screen.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

class _MockNavigationResolver extends Mock implements NavigationResolver {}

class _MockStackRouter extends Mock implements StackRouter {}

final _epoch = DateTime.utc(2026, 1, 1);

LearnerProfileEntity _profile(String id, ProfileMode mode) =>
    LearnerProfileEntity(
      profileId: id,
      displayName: id,
      mode: mode,
      createdAt: _epoch,
      updatedAt: _epoch,
    );

final _child = _profile('child-1', ProfileMode.child);
final _adult = _profile('adult-1', ProfileMode.adult);

/// A guard over an in-memory account of [_child] and [_adult], whose
/// holder is [selected] and whose PIN-holding profiles are [withPin].
/// Records every PIN prompt in [prompts].
SacredTimeLocationGuard _guard({
  required String? selected,
  Set<String> withPin = const {},
  SacredTimeLocationAccess? access,
  bool pinCorrect = false,
  List<String>? prompts,
}) {
  final passes = access ?? SacredTimeLocationAccess();
  return SacredTimeLocationGuard(
    getSelectedProfileId: () => selected,
    getProfileById: (id) async =>
        [_child, _adult].where((p) => p.profileId == id).firstOrNull,
    hasProfilePin: (id) async => withPin.contains(id),
    consumeAccess: passes.consume,
    promptForPin: (id) async {
      prompts?.add(id);
      return pinCorrect;
    },
  );
}

/// Runs [guard] once and returns what it resolved.
Future<bool?> _run(AutoRouteGuard guard) async {
  bool? resolved;
  final resolver = _MockNavigationResolver();
  when(() => resolver.isResolved).thenAnswer((_) => resolved != null);
  when(() => resolver.next(any())).thenAnswer((invocation) {
    resolved = invocation.positionalArguments.first as bool;
  });
  await guard.onNavigation(resolver, _MockStackRouter());
  return resolved;
}

/// A minimal root router: a home page and the production city picker page
/// behind [guard], at its production path.
class _TestRouter extends RootStackRouter {
  _TestRouter(this.guard);

  final AutoRouteGuard guard;

  @override
  List<AutoRoute> get routes => [
    NamedRouteDef(
      name: 'Home',
      path: '/',
      initial: true,
      builder: (_, _) => const Scaffold(body: Text('home')),
    ),
    AutoRoute(
      path: '/sacred-time/city',
      page: CityPickerRoute.page,
      guards: [guard],
    ),
  ];
}

void main() {
  group('SacredTimeLocationGuard.onNavigation', () {
    test('no holder is refused (fail closed)', () async {
      expect(await _run(_guard(selected: null)), isFalse);
    });

    test('a holder that is not a known profile is refused', () async {
      expect(await _run(_guard(selected: 'stranger')), isFalse);
    });

    test('an adult holder passes without a PIN prompt', () async {
      final prompts = <String>[];
      final allowed = await _run(
        _guard(
          selected: _adult.profileId,
          withPin: {_adult.profileId},
          prompts: prompts,
        ),
      );
      expect(allowed, isTrue);
      expect(prompts, isEmpty);
    });

    test('a child holder with no Parent PIN passes', () async {
      expect(await _run(_guard(selected: _child.profileId)), isTrue);
    });

    test('a child holder with a Parent PIN is asked for it; a wrong or '
        'cancelled PIN refuses', () async {
      final prompts = <String>[];
      final allowed = await _run(
        _guard(
          selected: _child.profileId,
          withPin: {_child.profileId},
          prompts: prompts,
        ),
      );
      expect(allowed, isFalse);
      expect(prompts, [_child.profileId]);
    });

    test(
      'a child holder with a Parent PIN passes on the correct PIN',
      () async {
        final prompts = <String>[];
        final allowed = await _run(
          _guard(
            selected: _child.profileId,
            withPin: {_child.profileId},
            pinCorrect: true,
            prompts: prompts,
          ),
        );
        expect(allowed, isTrue);
        expect(prompts, [_child.profileId]);
      },
    );

    test('a pass for the holder, granted by an in-app PIN check, opens the '
        'picker once without a second prompt', () async {
      final access = SacredTimeLocationAccess()..grant(_child.profileId);
      final prompts = <String>[];
      final guard = _guard(
        selected: _child.profileId,
        withPin: {_child.profileId},
        access: access,
        prompts: prompts,
      );

      expect(await _run(guard), isTrue);
      expect(prompts, isEmpty);
      // Used up: the next navigation asks again.
      expect(await _run(guard), isFalse);
      expect(prompts, [_child.profileId]);
    });

    test('a pass for another profile does not open the picker', () async {
      final access = SacredTimeLocationAccess()..grant(_adult.profileId);
      final prompts = <String>[];
      final allowed = await _run(
        _guard(
          selected: _child.profileId,
          withPin: {_child.profileId},
          access: access,
          prompts: prompts,
        ),
      );
      expect(allowed, isFalse);
      expect(prompts, [_child.profileId]);
    });

    test('a pass is used up even by a navigation that needs none', () async {
      final access = SacredTimeLocationAccess()..grant(_adult.profileId);
      expect(
        await _run(_guard(selected: _adult.profileId, access: access)),
        isTrue,
      );
      expect(access.consume(_adult.profileId), isFalse);
    });

    test(
      'an error refuses the navigation and completes the resolver',
      () async {
        final guard = SacredTimeLocationGuard(
          getSelectedProfileId: () => _child.profileId,
          getProfileById: (_) async => throw StateError('profiles unavailable'),
          hasProfilePin: (_) async => true,
          consumeAccess: (_) => false,
          promptForPin: (_) async => true,
        );
        expect(await _run(guard), isFalse);
      },
    );
  });

  group('direct route (deep link) regression', () {
    Future<_TestRouter> pumpRouter(
      WidgetTester tester,
      SacredTimeLocationGuard guard,
    ) async {
      final router = _TestRouter(guard);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            routerConfig: router.config(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);
      return router;
    }

    testWidgets('a child holder with a Parent PIN who opens /sacred-time/city '
        'directly is asked for the PIN and, without it, never reaches the '
        'city picker', (tester) async {
      final prompts = <String>[];
      final router = await pumpRouter(
        tester,
        _guard(
          selected: _child.profileId,
          withPin: {_child.profileId},
          prompts: prompts,
        ),
      );

      await router.navigatePath('/sacred-time/city');
      await tester.pumpAndSettle();

      expect(prompts, [_child.profileId]);
      expect(find.byType(CityPickerScreen), findsNothing);
      expect(find.text('home'), findsOneWidget);
    });

    testWidgets('the same holder reaches the city picker with the correct '
        'PIN', (tester) async {
      final router = await pumpRouter(
        tester,
        _guard(
          selected: _child.profileId,
          withPin: {_child.profileId},
          pinCorrect: true,
        ),
      );

      await router.navigatePath('/sacred-time/city');
      await tester.pumpAndSettle();

      expect(find.byType(CityPickerScreen), findsOneWidget);
    });

    testWidgets('an adult holder opens /sacred-time/city directly with no '
        'PIN prompt', (tester) async {
      final prompts = <String>[];
      final router = await pumpRouter(
        tester,
        _guard(selected: _adult.profileId, prompts: prompts),
      );

      await router.navigatePath('/sacred-time/city');
      await tester.pumpAndSettle();

      expect(find.byType(CityPickerScreen), findsOneWidget);
      expect(prompts, isEmpty);
    });
  });
}
