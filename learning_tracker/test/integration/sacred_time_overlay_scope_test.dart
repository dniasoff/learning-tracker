// integration/sacred_time_overlay_scope_test.dart
//
// DNI-481 (Story 1.19) AC-1 + the multi-learner / tutor edge rows.
// Supersedes the DNI-368 AppShell-only scope: the overlay now wraps the
// WHOLE router output (MaterialApp.router builder slot), and what keeps
// sign-in / onboarding reachable is that a signed-out device has no learner
// whose lock drives it.
//
//   (a) Locked: the opaque lock screen shows the existing greeting; the app
//       behind it is offstage — not painted, not hit-testable, absent from
//       semantics.
//   (b) Unlocked: the app is shown and keeps its state across a lock.
//   (c) Everything the router renders is covered, including pushed routes
//       and dialogs.
//   (d) The union: any locked learner of the signed-in account locks the
//       device; signed out, nothing does.
//   (e) A tutored talmid never drives the device overlay; a tutored
//       session showing a locked talmid covers only the talmid's screens
//       and keeps the tutor's exit reachable.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/time/local_day_clock.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/features/profiles/profiles.dart';
import 'package:learning_tracker/features/sacred_time/data/repositories/learner_lock_settings_sources.dart';
import 'package:learning_tracker/features/sacred_time/domain/models/sacred_window.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/learner_lock_settings_provider.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/sacred_windows_provider.dart';
import 'package:learning_tracker/features/sacred_time/presentation/widgets/sacred_time_lock_overlay.dart';
import 'package:learning_tracker/features/tutoring/domain/models/session_role.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_permissions.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/active_tutored_profile_provider.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

import '../helpers/learner_state/lock_fixtures.dart';
import '../helpers/learner_state_fixtures.dart';

/// Pins the greeting to the Ashkenazi English form ("Good Shabbos").
final List<Override> _ashkenaziEnglishTerms = [
  useHebrewTermsProvider.overrideWithValue(false),
  currentTransliterationVariantProvider.overrideWithValue(
    TransliterationVariant.ashkenazi,
  ),
];

SacredWindow _activeShabbosWindow() => SacredWindow(
  startUtc: DateTime.utc(2026, 5, 15, 18),
  endUtc: DateTime.utc(2026, 5, 16, 20),
  kind: SacredWindowKind.shabbos,
);

const _owner = 'owner-uid';
const _sibling = '01ARZ3NDEKTSV4RRFFQ69G5FB2';
const _talmid = '01ARZ3NDEKTSV4RRFFQ69G5FB3';

/// Saturday 2026-09-05 20:00Z: 16:00 in Lakewood (locked), 23:00 in
/// Jerusalem (Shabbos is out there, so unlocked).
final _saturdayEvening = DateTime.utc(2026, 9, 5, 20);

LearnerProfileEntity _profile(String id) => LearnerProfileEntity(
  profileId: id,
  displayName: id,
  mode: ProfileMode.child,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

class _Tutored extends ActiveTutoredProfileSelection {
  @override
  TutoredProfileSelection? build() => const TutoredProfileSelection(
    profileId: _talmid,
    ownerUid: 'parent-uid',
    grantId: 'grant-1',
    permissions: TutorPermissions(),
  );
}

/// The real provider chain from the account's learners to the overlay:
/// [locked] learners hold a Lakewood history (locked on [_saturdayEvening]);
/// the others a Jerusalem one (unlocked then).
List<Override> _account({
  String? uid = _owner,
  List<String> profiles = const [profileUlid, _sibling],
  Set<String> locked = const {},
  bool tutored = false,
  DateTime? now,
}) {
  final unlocked = constantHistory(jerusalem);
  final lockedH = constantHistory(lakewood);
  LearnerScope scopeOf(String owner, String id) =>
      LearnerScope(ownerUid: owner, profileId: id);
  return [
    ..._ashkenaziEnglishTerms,
    localDayClockProvider.overrideWithValue(
      FakeLocalDayClock(now ?? _saturdayEvening),
    ),
    ownAccountPathUidProvider.overrideWith((ref) async => uid),
    profileListStreamProvider.overrideWith(
      (ref) => Stream.value([for (final id in profiles) _profile(id)]),
    ),
    if (tutored)
      activeTutoredProfileSelectionProvider.overrideWith(_Tutored.new),
    for (final id in [...profiles])
      learnerLockSettingsProvider(
        scopeOf(_owner, id),
      ).overrideWithValue(AsyncData(locked.contains(id) ? lockedH : unlocked)),
    learnerLockSettingsProvider(
      scopeOf('parent-uid', _talmid),
    ).overrideWithValue(
      AsyncData(locked.contains(_talmid) ? lockedH : unlocked),
    ),
  ];
}

Future<void> _pumpApp(
  WidgetTester tester, {
  required List<Override> overrides,
  Widget home = const Text('DASHBOARD'),
  VoidCallback? onExit,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        // As in learning_tracker_app.dart: the overlay wraps the router
        // output in the builder slot.
        builder: (context, child) => SacredTimeLockOverlay(
          child: TutoredLearnerLockOverlay(
            onExit: onExit ?? () {},
            child: child!,
          ),
        ),
        home: home,
      ),
    ),
  );
  // Let the account's profile stream and path uid resolve.
  for (var i = 0; i < 5; i++) {
    await tester.pump();
  }
}

class _Counter extends StatefulWidget {
  const _Counter();

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int taps = 0;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: () => setState(() => taps++),
    child: Text('TAPS $taps'),
  );
}

void main() {
  group('SacredTimeLockOverlay (DNI-481 AC-1)', () {
    testWidgets('(a) locked: greeting shown, the app offstage — no paint, '
        'no touch, no semantics', (tester) async {
      final semantics = tester.ensureSemantics();
      var tapped = false;
      await _pumpApp(
        tester,
        overrides: [
          ..._ashkenaziEnglishTerms,
          currentSacredWindowProvider.overrideWithValue(_activeShabbosWindow()),
        ],
        home: Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => tapped = true,
              child: const Text('DASHBOARD'),
            ),
          ),
        ),
      );

      expect(find.text('Good Shabbos'), findsOneWidget);
      expect(find.text('DASHBOARD'), findsNothing);
      expect(find.text('DASHBOARD', skipOffstage: false), findsOneWidget);
      await tester.tapAt(tester.getCenter(find.byType(MaterialApp)));
      expect(tapped, isFalse);
      expect(find.bySemanticsLabel('DASHBOARD'), findsNothing);
      expect(find.bySemanticsLabel(RegExp('Good Shabbos')), findsOneWidget);
      final greetingNode = tester.getSemantics(
        find.ancestor(
          of: find.text('Good Shabbos'),
          matching: find.byWidgetPredicate(
            (w) => w is Semantics && (w.properties.liveRegion ?? false),
          ),
        ),
      );
      expect(greetingNode.flagsCollection.isLiveRegion, isTrue);
      semantics.dispose();
    });

    testWidgets('(b) unlocked: the app is shown and keeps its state across a '
        'lock', (tester) async {
      final container = ProviderContainer(
        overrides: [
          ..._ashkenaziEnglishTerms,
          currentSacredWindowProvider.overrideWithValue(null),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => SacredTimeLockOverlay(child: child!),
            home: const Scaffold(body: Center(child: _Counter())),
          ),
        ),
      );
      await tester.tap(find.text('TAPS 0'));
      await tester.pump();
      expect(find.text('TAPS 1'), findsOneWidget);
      expect(find.text('Good Shabbos'), findsNothing);

      container.updateOverrides([
        ..._ashkenaziEnglishTerms,
        currentSacredWindowProvider.overrideWithValue(_activeShabbosWindow()),
      ]);
      await tester.pump();
      expect(find.text('Good Shabbos'), findsOneWidget);

      container.updateOverrides([
        ..._ashkenaziEnglishTerms,
        currentSacredWindowProvider.overrideWithValue(null),
      ]);
      await tester.pump();
      expect(find.text('Good Shabbos'), findsNothing);
      expect(find.text('TAPS 1'), findsOneWidget, reason: 'state kept');
    });

    testWidgets('(c) pushed routes and dialogs are covered too', (
      tester,
    ) async {
      await _pumpApp(
        tester,
        overrides: [
          ..._ashkenaziEnglishTerms,
          currentSacredWindowProvider.overrideWithValue(_activeShabbosWindow()),
        ],
        home: Builder(
          builder: (context) {
            unawaited(
              Future.microtask(() {
                if (!context.mounted) return;
                unawaited(
                  showDialog<void>(
                    context: context,
                    builder: (_) => const AlertDialog(content: Text('DIALOG')),
                  ),
                );
              }),
            );
            return const Text('HOME');
          },
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('DIALOG', skipOffstage: false), findsOneWidget);
      expect(find.text('DIALOG'), findsNothing);
      expect(find.text('Good Shabbos'), findsOneWidget);
    });
  });

  group('the union of the account learners (AD-36)', () {
    testWidgets('(d) one locked learner locks the device', (tester) async {
      await _pumpApp(tester, overrides: _account(locked: {_sibling}));
      expect(find.text('Good Shabbos'), findsOneWidget);
      expect(find.text('DASHBOARD'), findsNothing);
    });

    testWidgets('(d) no locked learner: the app is open', (tester) async {
      await _pumpApp(tester, overrides: _account());
      expect(find.text('Good Shabbos'), findsNothing);
      expect(find.text('DASHBOARD'), findsOneWidget);
    });

    testWidgets('(d) signed out: sign-in and onboarding stay reachable on '
        'Shabbos', (tester) async {
      await _pumpApp(
        tester,
        overrides: _account(uid: null, locked: {profileUlid, _sibling}),
        home: const Text('SIGN IN'),
      );
      expect(find.text('SIGN IN'), findsOneWidget);
      expect(find.text('Good Shabbos'), findsNothing);
    });

    testWidgets('(e) a locked talmid does not lock the tutor outside a '
        'tutored session', (tester) async {
      await _pumpApp(tester, overrides: _account(locked: {_talmid}));
      expect(find.text('Good Shabbos'), findsNothing);
    });

    testWidgets("(e) a tutored session covers the locked talmid's screens "
        "but not the tutor's way out, and drives no device lock", (
      tester,
    ) async {
      var exits = 0;
      await _pumpApp(
        tester,
        overrides: _account(locked: {_talmid}, tutored: true),
        onExit: () => exits++,
      );
      expect(find.text('Good Shabbos'), findsOneWidget);
      expect(find.text('DASHBOARD'), findsNothing);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );
      expect(container.read(currentSacredWindowProvider), isNull);

      await tester.tap(find.byKey(const Key('tutoredLearnerLockExit')));
      expect(exits, 1);
    });

    testWidgets('(e) the device lock shows no tutor exit', (tester) async {
      await _pumpApp(tester, overrides: _account(locked: {_sibling}));
      expect(find.text('Good Shabbos'), findsOneWidget);
      expect(find.byKey(const Key('tutoredLearnerLockExit')), findsNothing);
    });

    testWidgets('(e) a tutored session with an unlocked talmid is open', (
      tester,
    ) async {
      await _pumpApp(tester, overrides: _account(tutored: true));
      expect(find.text('Good Shabbos'), findsNothing);
      expect(find.text('DASHBOARD'), findsOneWidget);
    });
  });
}
