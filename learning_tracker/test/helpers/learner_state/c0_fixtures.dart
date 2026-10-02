/// Hermetic fixtures for tests written against the C0 (DNI-524) contract.
library;

import 'package:learning_tracker/domain/learner_state/learner_settings.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings_history.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';

import '../learner_state_fixtures.dart';

/// UTC settings for [profileUlid].
const c0Settings = LearnerSettings(profileId: profileUlid, timeZone: 'UTC');

/// A one-span history holding [c0Settings].
LearnerSettingsHistory c0SettingsHistory() =>
    LearnerSettingsHistory.constant(c0Settings);

/// The owner scope of [profileUlid].
LearnerScope c0Scope({String ownerUid = 'owner-uid'}) =>
    LearnerScope(ownerUid: ownerUid, profileId: profileUlid);

/// A live, valid ongoing sub-track over `Zeraim`.
SubTrack c0SubTrack({
  String id = ulidB,
  String lastChangeId = ulidC,
  double ratePerWeek = 7,
}) => SubTrack(
  id: id,
  curriculumId: 'mishnayos',
  name: 'Shiur',
  type: SubTrackType.ongoing,
  windowStart: '2026-09-01',
  ratePerWeek: ratePerWeek,
  weeksPerYear: 40,
  learnsOnShabbos: true,
  ground: const [NodeEntry(level: 'seder', ref: 'Zeraim')],
  lastChangeId: lastChangeId,
);
