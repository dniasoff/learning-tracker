// E2E-1103 — Sacred-Time lock journey on a real Android device.
//
// This deliberately mounts the production SacredTimeLockOverlay in the
// MaterialApp.router builder slot. The headless E2EHarness cannot cover that
// slot, which is why the catalog entry in test/e2e/journeys/infra_p0_test.dart
// remains a device-only skip.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/domain/learner_state/change_log_entry.dart';
import 'package:learning_tracker/domain/learner_state/governed_change.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_commands.dart';
import 'package:learning_tracker/features/profiles/domain/models/learner_profile_entity.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/sacred_time/data/services/location_service.dart';
import 'package:learning_tracker/features/sacred_time/domain/models/city.dart';
import 'package:learning_tracker/features/sacred_time/domain/models/sacred_window.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/cities_provider.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/learner_settings_editor_provider.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/sacred_windows_provider.dart';
import 'package:learning_tracker/features/sacred_time/presentation/widgets/sacred_time_lock_overlay.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

const _profileId = '01ARZ3NDEKTSV4RRFFQ69G5FB1';

const _jerusalem = City(
  id: 1103,
  name: 'Jerusalem',
  countryCode: 'IL',
  latitude: 31.7683,
  longitude: 35.2137,
  population: 900000,
  admin1: 'Jerusalem District',
  timezone: 'Asia/Jerusalem',
);

/// Mutable source used to model the provider recomputation caused by the
/// governed location correction. The initial window spans the chained
/// Shabbos/Yom Tov interval and ends Monday in the configured New York zone.
final class _MutableSacredWindow extends CurrentSacredWindow {
  _MutableSacredWindow(this.current);

  SacredWindow? current;

  @override
  SacredWindow? build() => current;

  void release() {
    current = null;
    state = null;
  }
}

final class _RecordingGovernedCommands extends Fake
    implements GovernedLearningCommands {
  _RecordingGovernedCommands(this.onApplied);

  final void Function(GovernedAction action) onApplied;
  final applied = <GovernedAction>[];

  @override
  Future<CaptureResult> applyGovernedChange(GovernedAction action) async {
    applied.add(action);
    onApplied(action);
    return const CaptureResult.success();
  }
}

final class _StaticRouterDelegate extends RouterDelegate<Object>
    with ChangeNotifier {
  @override
  Object? get currentConfiguration => null;

  @override
  Widget build(BuildContext context) => Navigator(
    pages: const [
      MaterialPage<void>(
        child: Scaffold(body: Center(child: Text('UNDER THE LOCK'))),
      ),
    ],
    onDidRemovePage: (_) {},
  );

  @override
  Future<void> setNewRoutePath(Object? configuration) async {}

  @override
  Future<bool> popRoute() async => false;
}

Future<void> _pumpJourney(
  WidgetTester tester,
  IntegrationTestWidgetsFlutterBinding binding,
) async {
  final window = SacredWindow(
    // 2026-05-15 18:00 in New York.
    startUtc: DateTime.utc(2026, 5, 15, 22),
    // 2026-05-18 16:00 in New York: the final end of the chained interval.
    endUtc: DateTime.utc(2026, 5, 18, 20),
    kind: SacredWindowKind.shabbosYomTov,
    profileId: _profileId,
    timeZone: 'America/New_York',
  );
  final source = _MutableSacredWindow(window);
  final commands = _RecordingGovernedCommands((_) => source.release());
  final editor = LearnerSettingsEditor.forLearner(
    governed: () async => commands,
    profileId: _profileId,
    locationService: const LocationService(),
    deviceTimeZone: () async => 'Asia/Jerusalem',
  );
  final profile = LearnerProfileEntity(
    profileId: _profileId,
    displayName: 'Device Learner',
    mode: ProfileMode.adult,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentSacredWindowProvider.overrideWith(() => source),
        profileListStreamProvider.overrideWith(
          (ref) => Stream.value([profile]),
        ),
        // The overlay's location flow remains guarded by the production
        // guard function, while this seam supplies its already-authorized
        // governed write for the device journey.
        lockLocationEditorProvider(_profileId).overrideWithValue(editor),
        citySearchProvider(
          'Je',
        ).overrideWith((ref) => Future.value(const [_jerusalem])),
        useHebrewTermsProvider.overrideWithValue(false),
        currentTransliterationVariantProvider.overrideWithValue(
          TransliterationVariant.ashkenazi,
        ),
      ],
      child: MaterialApp.router(
        routerConfig: RouterConfig<Object>(
          routerDelegate: _StaticRouterDelegate(),
        ),
        debugShowCheckedModeBanner: false,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) =>
            SacredTimeLockOverlay(child: child ?? const SizedBox.shrink()),
      ),
    ),
  );
  await tester.pump();

  expect(find.byKey(const Key('sacredTimeLockStartTime')), findsOneWidget);
  expect(find.text('Started Fri at 6:00 PM'), findsOneWidget);
  expect(find.text('Unlocks Mon at 4:00 PM'), findsOneWidget);
  expect(find.text('UNDER THE LOCK'), findsNothing);
  expect(find.byKey(const Key('sacredTimeLockChangeLocation')), findsOneWidget);
  await binding.takeScreenshot('e2e-1103-lock-covered');

  await tester.tap(find.byKey(const Key('sacredTimeLockChangeLocation')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
  expect(find.byKey(const Key('sacredTimeLockCityPicker')), findsOneWidget);
  expect(find.text('Choose a city'), findsOneWidget);
  await binding.takeScreenshot('e2e-1103-city-picker-covered');

  final field = find.byType(TextField);
  await tester.enterText(field, 'Je');
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
  expect(find.text('Jerusalem'), findsOneWidget);

  await tester.tap(find.text('Jerusalem'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));

  expect(commands.applied, hasLength(1));
  expect(
    commands.applied.single.changes.single.entity,
    GovernedEntity.learnerSettings,
  );
  expect(find.text('UNDER THE LOCK'), findsOneWidget);
  expect(find.byKey(const Key('sacredTimeLockChangeLocation')), findsNothing);
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'E2E-1103 enters chained lock, corrects location, and releases immediately',
    (tester) async {
      await binding.convertFlutterSurfaceToImage();
      await _pumpJourney(tester, binding);
    },
  );
}
