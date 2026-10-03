// Mirror test for `lib/domain/learner_state/learner_settings_history.dart`
// (C0, DNI-524 AC-6).
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/change_log_entry.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings_history.dart';
import 'package:learning_tracker/domain/learner_state/storage_codec.dart';

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

  group('reconstruct (DNI-470 AC-7)', () {
    String key(String field) => 'learner_profiles/$profileUlid.$field';

    ChangeLogEntry settingsEntry(
      String id,
      DateTime at, {
      required Map<String, Object?> before,
      required Map<String, Object?> after,
      DateTime? originalAt,
      String entityId = profileUlid,
    }) => ChangeLogEntry(
      id: id,
      entity: GovernedEntity.learnerSettings,
      entityId: entityId,
      actionId: id,
      before: {for (final e in before.entries) key(e.key): e.value},
      after: {for (final e in after.entries) key(e.key): e.value},
      at: at,
      originalAt: originalAt,
      actor: parentActor,
    );

    final seedAt = DateTime.utc(2026);
    ChangeLogEntry seed() => settingsEntry(
      ulidA,
      seedAt,
      before: {'time_zone': null, 'in_israel': null},
      after: {'time_zone': 'Asia/Jerusalem', 'in_israel': true},
    );
    ChangeLogEntry move() => settingsEntry(
      ulidB,
      moved,
      before: {'time_zone': 'Asia/Jerusalem', 'in_israel': true},
      after: {'time_zone': 'America/New_York', 'in_israel': false},
    );
    ChangeLogEntry locate() => settingsEntry(
      ulidC,
      movedAgain,
      before: {'latitude': null, 'longitude': null},
      after: {'latitude': 40.7, 'longitude': -74.0},
    );
    const current = LearnerSettings(
      profileId: profileUlid,
      timeZone: 'America/New_York',
      inIsrael: false,
      latitude: 40.7,
      longitude: -74,
      lastChangeId: ulidC,
    );

    test('no entries: the current values hold forever', () {
      expect(
        LearnerSettingsHistory.reconstruct(current: tlv, entries: const []),
        LearnerSettingsHistory.constant(tlv),
      );
    });

    test('spans per entry; instants before the first entry use its after; '
        'the last span is the current doc', () {
      final h = LearnerSettingsHistory.reconstruct(
        current: current,
        entries: [locate(), seed(), move()],
      );
      expect(h.spans.map((s) => s.fromUtc), [null, moved, movedAgain]);
      expect(
        h.at(DateTime.utc(2000)),
        const LearnerSettings(
          profileId: profileUlid,
          timeZone: 'Asia/Jerusalem',
          inIsrael: true,
          lastChangeId: ulidA,
        ),
      );
      expect(h.at(seedAt), h.at(DateTime.utc(2000)));
      expect(
        h.at(moved),
        const LearnerSettings(
          profileId: profileUlid,
          timeZone: 'America/New_York',
          inIsrael: false,
          lastChangeId: ulidB,
        ),
      );
      expect(h.at(movedAgain), current);
      expect(h.current, current);
    });

    test('original_at orders an imported entry before later live ones', () {
      final imported = settingsEntry(
        ulidE,
        DateTime.utc(2027), // imported late …
        originalAt: DateTime.utc(2025, 6), // … but happened first
        before: {'time_zone': null},
        after: {'time_zone': 'Europe/London'},
      );
      final h = LearnerSettingsHistory.reconstruct(
        current: const LearnerSettings(
          profileId: profileUlid,
          timeZone: 'Asia/Jerusalem',
          inIsrael: true,
        ),
        entries: [
          seed(),
          settingsEntry(
            ulidD,
            DateTime.utc(2026, 2),
            before: {'time_zone': 'Europe/London'},
            after: {'time_zone': 'Asia/Jerusalem'},
          ),
          imported,
        ],
      );
      expect(h.spans.first.fromUtc, isNull);
      expect(h.at(DateTime.utc(2020)).timeZone, 'Europe/London');
      expect(h.at(DateTime.utc(2026, 1, 15)).timeZone, 'Europe/London');
      expect(h.at(DateTime.utc(2026, 3)).timeZone, 'Asia/Jerusalem');
    });

    test('an import-time seed leads the history it was replayed under '
        '(DNI-482, AD-49)', () {
      // The destination profile was created (seeded) at importSeedAt; the
      // import then replayed the source history with older original_at.
      final importSeedAt = DateTime.utc(2027);
      final importSeed = settingsEntry(
        ulidA,
        importSeedAt,
        before: {'time_zone': null, 'in_israel': null},
        after: {'time_zone': 'UTC', 'in_israel': false},
      );
      final replayedSeed = settingsEntry(
        ulidB,
        DateTime.utc(2027, 2),
        originalAt: seedAt,
        before: {'time_zone': 'UTC', 'in_israel': false},
        after: {'time_zone': 'Asia/Jerusalem', 'in_israel': true},
      );
      final replayedMove = settingsEntry(
        ulidC,
        DateTime.utc(2027, 2),
        originalAt: moved,
        before: {'time_zone': 'Asia/Jerusalem', 'in_israel': true},
        after: {'time_zone': 'America/New_York', 'in_israel': false},
      );
      final h = LearnerSettingsHistory.reconstruct(
        current: const LearnerSettings(
          profileId: profileUlid,
          timeZone: 'America/New_York',
          inIsrael: false,
        ),
        entries: [replayedMove, importSeed, replayedSeed],
      );
      expect(h.spans.map((s) => s.fromUtc), [null, seedAt, moved]);
      expect(h.at(seedAt).timeZone, 'Asia/Jerusalem');
      expect(h.at(moved).timeZone, 'America/New_York');
      // After the import-time seed's instant the replayed state still holds.
      expect(h.at(importSeedAt).timeZone, 'America/New_York');
    });

    test('an update that fills an absent optional field is not a seed', () {
      final h = LearnerSettingsHistory.reconstruct(
        current: current,
        entries: [locate(), seed(), move()],
      );
      expect(h.spans.map((s) => s.fromUtc), [null, moved, movedAgain]);
    });

    test('entries of other entities or profiles are ignored', () {
      final other = ChangeLogEntry(
        id: ulidD,
        entity: GovernedEntity.mainTrackProgram,
        entityId: 'mishnayos',
        actionId: ulidD,
        before: const {'profile_programs/mishnayos.program_id': null},
        after: const {'profile_programs/mishnayos.program_id': 'daf'},
        at: moved,
        actor: parentActor,
      );
      final h = LearnerSettingsHistory.reconstruct(
        current: tlv,
        entries: [other],
      );
      expect(h, LearnerSettingsHistory.constant(tlv));
    });

    test('entries at the same instant collapse to the later one', () {
      final h = LearnerSettingsHistory.reconstruct(
        current: current,
        entries: [
          seed(),
          settingsEntry(
            ulidB,
            seedAt,
            before: {'time_zone': 'Asia/Jerusalem', 'in_israel': true},
            after: {'time_zone': 'America/New_York', 'in_israel': false},
          ),
          locate(),
        ],
      );
      expect(h.spans.map((s) => s.fromUtc), [null, movedAgain]);
      expect(h.at(DateTime.utc(2000)).timeZone, 'America/New_York');
    });

    test('a wrong-typed settings value fails closed', () {
      expect(
        () => LearnerSettingsHistory.reconstruct(
          current: current,
          entries: [
            seed(),
            settingsEntry(
              ulidB,
              moved,
              before: {'time_zone': 42},
              after: {'time_zone': 'America/New_York'},
            ),
          ],
        ),
        throwsA(isA<StorageFormatException>()),
      );
    });
  });
}
