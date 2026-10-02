/// The Sacred Time settings of the active learner, read and edited
/// (DNI-481 AC-3, AC-4).
///
/// Reads come only from `learnerLockSettingsProvider` (AD-37: one provider
/// serves every reader). Edits are governed `learnerSettings` changes
/// through `LearningCommands.applyGovernedChange` (DNI-470), so each is a
/// logged change-log entry and every past lock window keeps the settings
/// in force at its instant. Nothing is read from, or written to, device
/// preferences.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings.dart';
import 'package:learning_tracker/domain/learner_state/learner_zone.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_commands.dart';
import 'package:learning_tracker/features/learning/presentation/providers/learning_command_providers.dart';
import 'package:learning_tracker/features/sacred_time/data/repositories/learner_lock_settings_sources.dart';
import 'package:learning_tracker/features/sacred_time/data/services/device_time_zone.dart';
import 'package:learning_tracker/features/sacred_time/data/services/location_service.dart';
import 'package:learning_tracker/features/sacred_time/domain/learner_settings_change.dart';
import 'package:learning_tracker/features/sacred_time/domain/models/city.dart';
import 'package:learning_tracker/features/sacred_time/domain/models/location_fetch_result.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/learner_lock_settings_provider.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/sacred_location_provider.dart'
    show locationServiceProvider;

/// The current settings of the active learner: `AsyncData(null)` while no
/// learner is active, loading while the scope or the settings load, and an
/// error when either cannot be read.
final activeLearnerSettingsProvider =
    Provider.autoDispose<AsyncValue<LearnerSettings?>>((ref) {
      final scope = ref.watch(activeLearnerScopeProvider);
      if (scope case AsyncError(:final error, :final stackTrace)) {
        return AsyncError(error, stackTrace);
      }
      if (!scope.hasValue) return const AsyncLoading();
      final active = scope.requireValue;
      if (active == null) return const AsyncData(null);
      return ref
          .watch(learnerLockSettingsProvider(active))
          .whenData((history) => history.spans.last.settings);
    });

/// What a settings edit did.
enum LearnerSettingsEditOutcome {
  /// The governed change was written (or queued offline).
  saved,

  /// The learner is inside a lock: nothing was written (AD-36).
  locked,

  /// The change was not saved (rejected, or online-only while offline).
  notSaved,

  /// No learner can be edited here: none is active, the account is not
  /// ready, or this is a tutored session (tutor writes go through
  /// callables, AD-53).
  unavailable,
}

/// The result of a location detect: the fix itself and, on success, what
/// writing it did.
typedef LearnerLocationDetectResult = ({
  LocationFetchResult fetch,
  LearnerSettingsEditOutcome? outcome,
});

/// Edits the active learner's lock settings through governed commands.
final class LearnerSettingsEditor {
  /// Creates the editor over its seams.
  LearnerSettingsEditor({
    required Future<LearningCommands?> Function() commands,
    required Future<LearnerScope?> Function() scope,
    required LocationService locationService,
    required DeviceTimeZoneReader deviceTimeZone,
  }) : _commands = commands,
       _scope = scope,
       _locationService = locationService,
       _deviceTimeZone = deviceTimeZone;

  final Future<LearningCommands?> Function() _commands;
  final Future<LearnerScope?> Function() _scope;
  final LocationService _locationService;
  final DeviceTimeZoneReader _deviceTimeZone;

  /// Writes [edit] onto the active learner as one governed change.
  Future<LearnerSettingsEditOutcome> apply(LearnerSettingsEdit edit) async {
    final LearningCommands? commands;
    final LearnerScope? scope;
    try {
      commands = await _commands();
      scope = await _scope();
    } on Object {
      return LearnerSettingsEditOutcome.unavailable;
    }
    if (commands == null || scope == null) {
      return LearnerSettingsEditOutcome.unavailable;
    }
    final result = await commands.applyGovernedChange(
      learnerSettingsAction(scope.profileId, edit),
    );
    return switch (result) {
      CaptureSuccess() => LearnerSettingsEditOutcome.saved,
      CaptureLocked() => LearnerSettingsEditOutcome.locked,
      CaptureChildLimit() ||
      CaptureOnlineRequired() ||
      CaptureRejected() => LearnerSettingsEditOutcome.notSaved,
    };
  }

  /// Sets the learner's location, zone and Israel flag from [city]: its
  /// coordinates, its IANA zone when the tz database knows it (else the
  /// zone is left as it is), and Israel iff the city is in Israel.
  Future<LearnerSettingsEditOutcome> chooseCity(City city) => apply(
    LearnerSettingsEdit(
      latitude: city.latitude,
      longitude: city.longitude,
      timeZone: _knownZone(city.timezone),
      inIsrael: city.countryCode == 'IL',
    ),
  );

  /// Detects the device's location and, on a fix, sets the learner's
  /// location, the device's zone (when the tz database knows it) and the
  /// Israel flag from the fix's country (unchanged when unknown).
  Future<LearnerLocationDetectResult> detect() async {
    final fetch = await _locationService.detectCurrent();
    if (fetch is! LocationFetchSuccess) return (fetch: fetch, outcome: null);
    final country = fetch.location.countryCode;
    final outcome = await apply(
      LearnerSettingsEdit(
        latitude: fetch.location.latitude,
        longitude: fetch.location.longitude,
        timeZone: _knownZone(await _deviceTimeZone()),
        inIsrael: country == null ? null : country == 'IL',
      ),
    );
    return (fetch: fetch, outcome: outcome);
  }

  /// Sets the learner's Israel (one-day yom tov) flag.
  Future<LearnerSettingsEditOutcome> setInIsrael(bool value) =>
      apply(LearnerSettingsEdit(inIsrael: value));

  static String? _knownZone(String? id) {
    if (id == null || id.isEmpty) return null;
    return LearnerZone.of(id).isKnown ? id : null;
  }
}

/// The [LearnerSettingsEditor] of the active learner.
final learnerSettingsEditorProvider = Provider<LearnerSettingsEditor>(
  (ref) => LearnerSettingsEditor(
    commands: () => ref.read(learningCommandsProvider.future),
    scope: () => ref.read(activeLearnerScopeProvider.future),
    locationService: ref.watch(locationServiceProvider),
    deviceTimeZone: ref.watch(deviceTimeZoneReaderProvider),
  ),
);
