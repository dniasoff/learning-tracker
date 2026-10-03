// Mirror test for
// `lib/features/sacred_time/presentation/providers/learner_settings_editor_provider.dart`
// (DNI-481 AC-3, AC-4): the active learner's settings are read only from
// `learnerLockSettingsProvider` and every edit is one governed
// learnerSettings change.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/governed_change.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings_history.dart';
import 'package:learning_tracker/domain/learner_state/lock_windows.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_commands.dart';
import 'package:learning_tracker/features/sacred_time/data/repositories/learner_lock_settings_sources.dart';
import 'package:learning_tracker/features/sacred_time/data/services/location_service.dart';
import 'package:learning_tracker/features/sacred_time/domain/learner_settings_change.dart';
import 'package:learning_tracker/features/sacred_time/domain/models/city.dart';
import 'package:learning_tracker/features/sacred_time/domain/models/location_fetch_result.dart';
import 'package:learning_tracker/features/sacred_time/domain/models/sacred_location.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/learner_lock_settings_provider.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/learner_settings_editor_provider.dart';

import '../../../../helpers/learner_state_fixtures.dart';

final _scope = LearnerScope(ownerUid: 'owner-uid', profileId: profileUlid);

class _Commands extends Fake implements LearningCommands {
  _Commands([this.result = const CaptureResult.success(changeIds: [])]);

  final CaptureResult result;
  final List<GovernedAction> applied = [];

  @override
  Future<CaptureResult> applyGovernedChange(GovernedAction action) async {
    applied.add(action);
    return result;
  }
}

class _Location extends LocationService {
  const _Location(this.result);

  final LocationFetchResult result;

  @override
  Future<LocationFetchResult> detectCurrent() async => result;
}

LearnerSettingsEditor _editor({
  LearningCommands? commands,
  LearnerScope? scope,
  LocationFetchResult detect = const LocationFetchServiceDisabled(),
  String? deviceZone,
}) => LearnerSettingsEditor(
  commands: () async => commands,
  scope: () async => scope,
  locationService: _Location(detect),
  deviceTimeZone: () async => deviceZone,
);

LocationFetchSuccess _fix({String? country}) => LocationFetchSuccess(
  SacredLocation(
    latitude: 40.08214,
    longitude: -74.20975,
    source: SacredLocationSource.detected,
    fixedAt: DateTime.utc(2026, 9),
    countryCode: country,
  ),
);

City _city({String? timezone, String country = 'IL'}) => City(
  id: 1,
  name: 'Somewhere',
  countryCode: country,
  latitude: 31.7683,
  longitude: 35.2137,
  population: 1,
  timezone: timezone,
);

void main() {
  group('LearnerSettingsEditor.apply', () {
    test('unavailable (nothing written) with no commands, no scope or a '
        'failing source', () async {
      const edit = LearnerSettingsEdit(inIsrael: true);
      expect(
        await _editor(scope: _scope).apply(edit),
        LearnerSettingsEditOutcome.unavailable,
      );
      final commands = _Commands();
      expect(
        await _editor(commands: commands).apply(edit),
        LearnerSettingsEditOutcome.unavailable,
      );
      expect(commands.applied, isEmpty);
      final failing = LearnerSettingsEditor(
        commands: () async => throw StateError('not ready'),
        scope: () async => _scope,
        locationService: const _Location(LocationFetchServiceDisabled()),
        deviceTimeZone: () async => null,
      );
      expect(await failing.apply(edit), LearnerSettingsEditOutcome.unavailable);
    });

    test('writes the learnerSettings action for the scope profile and maps '
        'the command result', () async {
      final cases = <CaptureResult, LearnerSettingsEditOutcome>{
        const CaptureResult.success(changeIds: []):
            LearnerSettingsEditOutcome.saved,
        CaptureResult.locked(
          LockWindow(DateTime.utc(2026), DateTime.utc(2026)),
        ): LearnerSettingsEditOutcome.locked,
        const CaptureResult.onlineRequired():
            LearnerSettingsEditOutcome.notSaved,
        const CaptureResult.rejected(CaptureRejection.notSaved):
            LearnerSettingsEditOutcome.notSaved,
      };
      for (final MapEntry(key: result, value: outcome) in cases.entries) {
        final commands = _Commands(result);
        expect(
          await _editor(commands: commands, scope: _scope).setInIsrael(false),
          outcome,
        );
        expect(commands.applied, [
          learnerSettingsAction(
            profileUlid,
            const LearnerSettingsEdit(inIsrael: false),
          ),
        ]);
      }
    });
  });

  group('chooseCity', () {
    test('writes the city location, its known zone and Israel flag', () async {
      final commands = _Commands();
      await _editor(
        commands: commands,
        scope: _scope,
      ).chooseCity(_city(timezone: 'Asia/Jerusalem'));
      expect(commands.applied.single.changes.single.docs.single.fields, {
        'latitude': 31.768,
        'longitude': 35.214,
        'time_zone': 'Asia/Jerusalem',
        'in_israel': true,
      });
    });

    test('an unknown or missing city zone leaves the zone as it is', () async {
      for (final zone in [null, 'Mars/Olympus_Mons']) {
        final commands = _Commands();
        await _editor(
          commands: commands,
          scope: _scope,
        ).chooseCity(_city(timezone: zone, country: 'US'));
        final fields =
            commands.applied.single.changes.single.docs.single.fields;
        expect(fields.containsKey('time_zone'), isFalse);
        expect(fields['in_israel'], isFalse);
      }
    });
  });

  group('detect', () {
    test('a failed fix writes nothing', () async {
      final commands = _Commands();
      final result = await _editor(commands: commands, scope: _scope).detect();
      expect(result.fetch, isA<LocationFetchServiceDisabled>());
      expect(result.outcome, isNull);
      expect(commands.applied, isEmpty);
    });

    test('a fix writes the rounded location, the device zone and the '
        'Israel flag from the country', () async {
      final commands = _Commands();
      final result = await _editor(
        commands: commands,
        scope: _scope,
        detect: _fix(country: 'US'),
        deviceZone: 'America/New_York',
      ).detect();
      expect(result.outcome, LearnerSettingsEditOutcome.saved);
      expect(commands.applied.single.changes.single.docs.single.fields, {
        'latitude': 40.082,
        'longitude': -74.21,
        'time_zone': 'America/New_York',
        'in_israel': false,
      });
    });

    test('an unknown country or device zone is left unchanged', () async {
      final commands = _Commands();
      await _editor(commands: commands, scope: _scope, detect: _fix()).detect();
      expect(
        commands.applied.single.changes.single.docs.single.fields.keys,
        unorderedEquals(['latitude', 'longitude']),
      );
    });
  });

  group('activeLearnerSettingsProvider', () {
    test('no active learner reads as AsyncData(null)', () async {
      final container = ProviderContainer.test(
        overrides: [
          activeLearnerScopeProvider.overrideWith((ref) async => null),
        ],
      );
      await container.read(activeLearnerScopeProvider.future);
      expect(
        container.read(activeLearnerSettingsProvider),
        const AsyncData<LearnerSettings?>(null),
      );
    });

    test('reads the current settings from learnerLockSettingsProvider of '
        'the active scope', () async {
      const older = LearnerSettings(profileId: profileUlid, timeZone: 'UTC');
      const current = LearnerSettings(
        profileId: profileUlid,
        timeZone: 'Asia/Jerusalem',
        inIsrael: true,
      );
      final container = ProviderContainer.test(
        overrides: [
          activeLearnerScopeProvider.overrideWith((ref) async => _scope),
          learnerLockSettingsProvider(_scope).overrideWithValue(
            AsyncData(
              LearnerSettingsHistory([
                const SettingsSpan(fromUtc: null, settings: older),
                SettingsSpan(fromUtc: t1, settings: current),
              ]),
            ),
          ),
        ],
      );
      await container.read(activeLearnerScopeProvider.future);
      expect(
        container.read(activeLearnerSettingsProvider),
        const AsyncData<LearnerSettings?>(current),
      );
    });
  });
}
