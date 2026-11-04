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
import 'package:learning_tracker/domain/learner_state/learner_settings.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_commands.dart';
import 'package:learning_tracker/features/profiles/profiles.dart';
import 'package:learning_tracker/features/sacred_time/data/services/location_service.dart';
import 'package:learning_tracker/features/sacred_time/domain/models/city.dart';
import 'package:learning_tracker/features/sacred_time/domain/models/sacred_window.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/cities_provider.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/learner_settings_editor_provider.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/sacred_windows_provider.dart';
import 'package:learning_tracker/features/sacred_time/presentation/widgets/sacred_time_lock_overlay.dart';
import 'package:learning_tracker/features/sacred_time/presentation/widgets/sacred_time_settings_card.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

const _profileId = '01ARZ3NDEKTSV4RRFFQ69G5FB1';
const _pin = '1234';

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

final class _SelectedProfile extends SelectedProfileId {
  _SelectedProfile(this._id);

  final String? _id;

  @override
  String? build() => _id;

  @override
  void select(String profileId) => state = profileId;
}

final class _DeterministicPinService extends Fake implements PinService {
  final hasPinCalls = <String>[];
  final verifyCalls = <({String profileId, String pin})>[];

  @override
  Future<bool> hasProfilePin(String profileId) async {
    hasPinCalls.add(profileId);
    return profileId == _profileId;
  }

  @override
  Future<bool> verifyProfilePin(String profileId, String pin) async {
    verifyCalls.add((profileId: profileId, pin: pin));
    return profileId == _profileId && pin == _pin;
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
    if (_isJerusalemLocationAction(action)) onApplied(action);
    return const CaptureResult.success();
  }
}

bool _isJerusalemLocationAction(GovernedAction action) {
  if (action.changes.length != 1) return false;
  final change = action.changes.single;
  if (change.entity != GovernedEntity.learnerSettings ||
      change.entityId != _profileId ||
      change.docs.length != 1) {
    return false;
  }
  final doc = change.docs.single;
  return doc.mode == DocMode.update &&
      doc.docId == _profileId &&
      doc.fields.length == 4 &&
      doc.fields[LearnerSettings.kLatitude] == 31.768 &&
      doc.fields[LearnerSettings.kLongitude] == 35.214 &&
      doc.fields[LearnerSettings.kTimeZone] == 'Asia/Jerusalem' &&
      doc.fields[LearnerSettings.kInIsrael] == true;
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

Future<void> _pumpUntil(WidgetTester tester, bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 3));
  while (!condition() && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 20));
  }
  expect(condition(), isTrue);
}

Future<void> _pumpUntilFound(WidgetTester tester, Finder finder) =>
    _pumpUntil(tester, () => finder.evaluate().isNotEmpty);

Future<void> _pumpUntilGranted(WidgetTester tester, bool? Function() value) =>
    _pumpUntil(tester, () => value() != null);

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
  final pinService = _DeterministicPinService();
  final editor = LearnerSettingsEditor.forLearner(
    governed: () async => commands,
    profileId: _profileId,
    locationService: const LocationService(),
    deviceTimeZone: () async => 'Asia/Jerusalem',
  );
  final profile = LearnerProfileEntity(
    profileId: _profileId,
    displayName: 'Device Learner',
    mode: ProfileMode.child,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentSacredWindowProvider.overrideWith(() => source),
        pinServiceProvider.overrideWithValue(pinService),
        selectedProfileIdProvider.overrideWith(
          () => _SelectedProfile(_profileId),
        ),
        profileListStreamProvider.overrideWith(
          (ref) => Stream.value([profile]),
        ),
        // The overlay's location flow runs the production child PIN guard;
        // this seam supplies only the deterministic governed write afterward.
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
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
          child: SacredTimeLockOverlay(child: child ?? const SizedBox.shrink()),
        ),
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
  await _pumpUntilFound(tester, find.text('Enter Parent PIN'));
  for (final digit in _pin.split('')) {
    await tester.tap(find.text(digit).last);
    await tester.pump();
  }
  await _pumpUntilFound(
    tester,
    find.byKey(const Key('sacredTimeLockCityPicker')),
  );
  expect(pinService.hasPinCalls, contains(_profileId));
  expect(pinService.verifyCalls, contains((profileId: _profileId, pin: _pin)));
  expect(find.byKey(const Key('sacredTimeLockCityPicker')), findsOneWidget);
  expect(find.text('Choose a city'), findsOneWidget);

  final field = find.byType(TextField);
  await tester.enterText(field, 'Je');
  await _pumpUntilFound(tester, find.text('Jerusalem'));
  await binding.takeScreenshot('e2e-1103-city-picker-covered');

  await tester.tap(find.text('Jerusalem'));
  await _pumpUntilFound(tester, find.text('UNDER THE LOCK'));

  expect(commands.applied, hasLength(1));
  final change = commands.applied.single.changes.single;
  expect(change.entity, GovernedEntity.learnerSettings);
  expect(change.entityId, _profileId);
  expect(change.docs, hasLength(1));
  expect(change.docs.single.mode, DocMode.update);
  expect(change.docs.single.fields, {
    LearnerSettings.kLatitude: 31.768,
    LearnerSettings.kLongitude: 35.214,
    LearnerSettings.kTimeZone: 'Asia/Jerusalem',
    LearnerSettings.kInIsrael: true,
  });
  expect(find.text('UNDER THE LOCK'), findsOneWidget);
  expect(find.byKey(const Key('sacredTimeLockChangeLocation')), findsNothing);
}

Future<void> _runAdultUnguardedCase(WidgetTester tester) async {
  bool? granted;
  const adultId = '01ARZ3NDEKTSV4RRFFQ69G5FA1';
  final adult = LearnerProfileEntity(
    profileId: adultId,
    displayName: 'Adult Device Holder',
    mode: ProfileMode.adult,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        pinServiceProvider.overrideWithValue(_DeterministicPinService()),
        selectedProfileIdProvider.overrideWith(() => _SelectedProfile(adultId)),
        profileListStreamProvider.overrideWith((ref) => Stream.value([adult])),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Consumer(
          builder: (context, ref, _) => TextButton(
            onPressed: () async => granted =
                await guardLearnerLocationPromptAccess(context, ref, adultId),
            child: const Text('SET LOCATION'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('SET LOCATION'));
  await _pumpUntilGranted(tester, () => granted);
  expect(find.text('Enter Parent PIN'), findsNothing);
  expect(granted, isTrue);
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

  testWidgets(
    'E2E-1103 adult device holder keeps location access unguarded',
    _runAdultUnguardedCase,
  );
}
