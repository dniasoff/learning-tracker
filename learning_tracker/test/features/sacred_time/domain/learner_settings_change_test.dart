// Mirror test for `lib/features/sacred_time/domain/learner_settings_change.dart`
// (DNI-481 AC-3): the governed learnerSettings action a settings edit
// writes.
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/change_log_entry.dart';
import 'package:learning_tracker/domain/learner_state/governed_change.dart';
import 'package:learning_tracker/features/sacred_time/domain/learner_settings_change.dart';

import '../../../helpers/learner_state_fixtures.dart';

void main() {
  group('learnerSettingsAction', () {
    test('one learnerSettings entity patching only the given fields of the '
        'learner profile doc (mode update)', () {
      final action = learnerSettingsAction(
        profileUlid,
        const LearnerSettingsEdit(
          latitude: 31.7781234,
          longitude: 35.2354321,
          timeZone: 'Asia/Jerusalem',
          inIsrael: true,
        ),
      );
      final change = action.changes.single;
      expect(change.entity, GovernedEntity.learnerSettings);
      expect(change.entityId, profileUlid);
      final doc = change.docs.single;
      expect(doc.collection, 'learner_profiles');
      expect(doc.docId, profileUlid);
      expect(doc.mode, DocMode.update);
      expect(doc.fields, {
        'latitude': 31.778,
        'longitude': 35.235,
        'time_zone': 'Asia/Jerusalem',
        'in_israel': true,
      });
    });

    test('an Israel-only edit writes only in_israel', () {
      final action = learnerSettingsAction(
        profileUlid,
        const LearnerSettingsEdit(inIsrael: false),
      );
      expect(action.changes.single.docs.single.fields, {'in_israel': false});
    });

    test('coordinates are rounded to 3 decimal places (PV-7)', () {
      expect(roundLearnerCoordinate(40.08214), 40.082);
      expect(roundLearnerCoordinate(-74.20975), -74.21);
    });

    test('refuses an empty edit, a lone coordinate, out-of-range values and '
        'a non-IANA zone', () {
      for (final edit in const [
        LearnerSettingsEdit(),
        LearnerSettingsEdit(latitude: 31),
        LearnerSettingsEdit(latitude: 91, longitude: 0),
        LearnerSettingsEdit(latitude: 0, longitude: 181),
        LearnerSettingsEdit(timeZone: 'not a zone'),
      ]) {
        expect(
          () => learnerSettingsAction(profileUlid, edit),
          throwsArgumentError,
          reason: '$edit',
        );
      }
    });

    test('LearnerSettingsEdit value semantics', () {
      expect(
        const LearnerSettingsEdit(inIsrael: true),
        const LearnerSettingsEdit(inIsrael: true),
      );
      expect(const LearnerSettingsEdit().isEmpty, isTrue);
      expect(const LearnerSettingsEdit(timeZone: 'UTC').isEmpty, isFalse);
    });
  });
}
