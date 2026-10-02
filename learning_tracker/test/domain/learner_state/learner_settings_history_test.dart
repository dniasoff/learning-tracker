// Mirror test for `lib/domain/learner_state/learner_settings_history.dart`
// (C0, DNI-524 AC-6).
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings_history.dart';

import '../../helpers/learner_state/c0_stub_matcher.dart';
import '../../helpers/learner_state_fixtures.dart';

void main() {
  const tlv = LearnerSettings(
    profileId: profileUlid,
    timeZone: 'Asia/Jerusalem',
  );
  const nyc = LearnerSettings(
    profileId: profileUlid,
    timeZone: 'America/New_York',
  );
  const lon = LearnerSettings(
    profileId: profileUlid,
    timeZone: 'Europe/London',
  );
  final moved = DateTime.utc(2026, 3, 1);
  final movedAgain = DateTime.utc(2026, 6, 1);

  LearnerSettingsHistory history() => LearnerSettingsHistory([
    const SettingsSpan(fromUtc: null, settings: tlv),
    SettingsSpan(fromUtc: moved, settings: nyc),
    SettingsSpan(fromUtc: movedAgain, settings: lon),
  ]);

  group('at', () {
    test('picks the span in force, boundaries inclusive at the start', () {
      final h = history();
      expect(h.at(DateTime.utc(2020)), tlv);
      expect(h.at(moved.subtract(const Duration(microseconds: 1))), tlv);
      expect(h.at(moved), nyc);
      expect(h.at(DateTime.utc(2026, 5, 31, 23, 59)), nyc);
      expect(h.at(movedAgain), lon);
      expect(h.at(DateTime.utc(2030)), lon);
    });

    test('a non-UTC instant is compared as UTC', () {
      expect(history().at(moved.toLocal()), nyc);
    });

    test('an instant before a dated first span gets the first span', () {
      final h = LearnerSettingsHistory([
        SettingsSpan(fromUtc: moved, settings: nyc),
        SettingsSpan(fromUtc: movedAgain, settings: lon),
      ]);
      expect(h.at(DateTime.utc(2020)), nyc);
    });
  });

  test('current is the last span; constant has one open span', () {
    expect(history().current, lon);
    final c = LearnerSettingsHistory.constant(tlv);
    expect(c.spans, [const SettingsSpan(fromUtc: null, settings: tlv)]);
    expect(c.at(DateTime.utc(1990)), tlv);
    expect(c.current, tlv);
  });

  group('constructor validation', () {
    test('rejects an empty list', () {
      expect(() => LearnerSettingsHistory(const []), throwsArgumentError);
    });

    test('rejects a null fromUtc after the first span', () {
      expect(
        () => LearnerSettingsHistory(const [
          SettingsSpan(fromUtc: null, settings: tlv),
          SettingsSpan(fromUtc: null, settings: nyc),
        ]),
        throwsArgumentError,
      );
    });

    test('rejects spans that are not strictly ascending', () {
      expect(
        () => LearnerSettingsHistory([
          SettingsSpan(fromUtc: movedAgain, settings: nyc),
          SettingsSpan(fromUtc: moved, settings: lon),
        ]),
        throwsArgumentError,
      );
      expect(
        () => LearnerSettingsHistory([
          SettingsSpan(fromUtc: moved, settings: nyc),
          SettingsSpan(fromUtc: moved, settings: lon),
        ]),
        throwsArgumentError,
      );
    });
  });

  test('value equality', () {
    expect(history(), history());
    expect(history().hashCode, history().hashCode);
    expect(history(), isNot(LearnerSettingsHistory.constant(tlv)));
  });

  test('reconstruct is a C0 stub owned by DNI-470', () {
    expect(
      () => LearnerSettingsHistory.reconstruct(current: tlv, entries: const []),
      throwsC0Stub('DNI-470', 'LearnerSettingsHistory.reconstruct'),
    );
  });
}
