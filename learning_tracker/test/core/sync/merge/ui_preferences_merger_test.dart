/// Unit tests for [UiPreferencesMerger]: LWW gate, per-field writes,
/// cross-profile isolation, no sacred_time clobber, locale/font-size/nikud
/// bounds enforcement.
///
/// AG-5: split out of the former test/core/sync/codecs_and_mergers_test.dart
/// (AUD-app-05) so this file mirrors lib/core/sync/merge/ui_preferences_merger.dart
/// 1:1. StageDefinitionCodec's tests moved to
/// test/core/sync/codec/stage_definition_codec_test.dart.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/preferences/profile_scoped_preference_keys.dart';
import 'package:learning_tracker/core/sync/merge/entity_merger.dart';
import 'package:learning_tracker/core/sync/merge/ui_preferences_merger.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeMergeStore implements MergeStore {
  final _timestamps = <String, Map<int, Map<String, DateTime?>>>{};
  final _syncedAt = <String, Map<int, Map<String, DateTime?>>>{};
  final List<Map<String, dynamic>> persisted = [];

  void seed({
    required String kind,
    required int profileId,
    required String naturalKey,
    required DateTime? updatedAt,
    DateTime? syncedAt,
  }) {
    _timestamps
            .putIfAbsent(kind, () => {})
            .putIfAbsent(profileId, () => {})[naturalKey] =
        updatedAt;
    _syncedAt
            .putIfAbsent(kind, () => {})
            .putIfAbsent(profileId, () => {})[naturalKey] =
        syncedAt;
  }

  @override
  Future<DateTime?> currentUpdatedAt({
    required String kind,
    required int profileId,
    required String naturalKey,
  }) async => _timestamps[kind]?[profileId]?[naturalKey];

  @override
  Future<DateTime?> currentSyncedAt({
    required String kind,
    required int profileId,
    required String naturalKey,
  }) async => _syncedAt[kind]?[profileId]?[naturalKey];

  @override
  Future<void> persistUpdatedAt({
    required String kind,
    required int profileId,
    required String naturalKey,
    required DateTime updatedAt,
    DateTime? syncedAt,
  }) async {
    _timestamps
            .putIfAbsent(kind, () => {})
            .putIfAbsent(profileId, () => {})[naturalKey] =
        updatedAt;
    _syncedAt
            .putIfAbsent(kind, () => {})
            .putIfAbsent(profileId, () => {})[naturalKey] =
        syncedAt;
    persisted.add({
      'kind': kind,
      'profileId': profileId,
      'naturalKey': naturalKey,
      'updatedAt': updatedAt,
      'syncedAt': syncedAt,
    });
  }

  @override
  bool remoteIsNewer({
    required DateTime? localUpdatedAt,
    required DateTime? remoteUpdatedAt,
    DateTime? localSyncedAt,
    DateTime? remoteSyncedAt,
  }) {
    if (remoteUpdatedAt == null) return false;
    if (localUpdatedAt == null) return true;
    final diff = remoteUpdatedAt.difference(localUpdatedAt).abs();
    if (diff > const Duration(seconds: 5)) {
      return remoteUpdatedAt.isAfter(localUpdatedAt);
    }
    if (remoteSyncedAt != null && localSyncedAt != null) {
      if (remoteSyncedAt.isAfter(localSyncedAt)) return true;
      if (localSyncedAt.isAfter(remoteSyncedAt)) return false;
    }
    return true;
  }

  @override
  Future<void> upsert({
    required String kind,
    required int profileId,
    required Map<String, dynamic> fields,
  }) async {}

  @override
  Future<void> insertIfAbsent({
    required String kind,
    required int profileId,
    required String naturalKey,
    required Map<String, dynamic> fields,
  }) async {}

  @override
  Future<T> runInTransaction<T>(Future<T> Function() body) => body();
}

DateTime _dt(int year, [int month = 1, int day = 1]) =>
    DateTime.utc(year, month, day);

void main() {
  group('UiPreferencesMerger — kind', () {
    test('kind is "ui_preferences"', () {
      SharedPreferences.setMockInitialValues({});
      final merger = UiPreferencesMerger(store: _FakeMergeStore());
      expect(merger.kind, EntityKind.uiPreferences);
    });
  });

  group('UiPreferencesMerger — LWW gate', () {
    late _FakeMergeStore store;
    late UiPreferencesMerger merger;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      store = _FakeMergeStore();
      merger = UiPreferencesMerger(store: store);
    });

    test('does nothing when rows list is empty', () async {
      await merger.merge(profileId: 1, rows: []);
      final prefs = await SharedPreferences.getInstance();
      // No locale key should be written
      expect(prefs.getString(ProfileScopedPreferenceKeys.appLocale(1)), isNull);
    });

    test('does nothing when the single row is empty', () async {
      await merger.merge(profileId: 1, rows: [{}]);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(ProfileScopedPreferenceKeys.appLocale(1)), isNull);
    });

    test(
      'applies remote row when no local timestamp exists (first sync)',
      () async {
        await merger.merge(
          profileId: 1,
          rows: [
            {'updated_at': _dt(2026).toIso8601String(), 'app_locale': 'he'},
          ],
        );
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString(ProfileScopedPreferenceKeys.appLocale(1)), 'he');
      },
    );

    test(
      'applies remote row when remote is strictly newer than local',
      () async {
        store.seed(
          kind: EntityKind.uiPreferences,
          profileId: 1,
          naturalKey: 'data',
          updatedAt: _dt(2025),
        );
        await merger.merge(
          profileId: 1,
          rows: [
            {
              'updated_at': _dt(2026).toIso8601String(),
              'app_locale': 'en',
              'use_hebrew_calendar': true,
            },
          ],
        );
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString(ProfileScopedPreferenceKeys.appLocale(1)), 'en');
        expect(
          prefs.getBool(ProfileScopedPreferenceKeys.useHebrewCalendar(1)),
          isTrue,
        );
      },
    );

    test('skips when remote is older than local', () async {
      store.seed(
        kind: EntityKind.uiPreferences,
        profileId: 1,
        naturalKey: 'data',
        updatedAt: _dt(2027),
      );
      await merger.merge(
        profileId: 1,
        rows: [
          {'updated_at': _dt(2026).toIso8601String(), 'app_locale': 'he'},
        ],
      );
      final prefs = await SharedPreferences.getInstance();
      // Nothing written — remote was older
      expect(prefs.getString(ProfileScopedPreferenceKeys.appLocale(1)), isNull);
    });

    test(
      'skips when remote has no updated_at (remoteIsNewer returns false)',
      () async {
        await merger.merge(
          profileId: 1,
          rows: [
            {
              // No updated_at
              'app_locale': 'he',
            },
          ],
        );
        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getString(ProfileScopedPreferenceKeys.appLocale(1)),
          isNull,
        );
      },
    );

    test('persistUpdatedAt is called after a successful merge', () async {
      await merger.merge(
        profileId: 1,
        rows: [
          {'updated_at': _dt(2026).toIso8601String(), 'app_locale': 'en'},
        ],
      );
      expect(store.persisted, hasLength(1));
      expect(store.persisted.first['kind'], EntityKind.uiPreferences);
      expect(store.persisted.first['profileId'], 1);
      expect(store.persisted.first['naturalKey'], 'data');
    });

    test(
      'uiPreferencesUpdatedAtMs key is written to SharedPrefs on apply',
      () async {
        final ts = _dt(2026, 3, 15);
        await merger.merge(
          profileId: 1,
          rows: [
            {'updated_at': ts.toIso8601String(), 'app_locale': 'en'},
          ],
        );
        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getInt(ProfileScopedPreferenceKeys.uiPreferencesUpdatedAtMs(1)),
          ts.millisecondsSinceEpoch,
        );
      },
    );

    test('falls back to SharedPrefs updatedAt when store returns null', () async {
      // Pre-seed a "local" timestamp only in SharedPreferences (no store entry).
      final localTs = _dt(2027);
      SharedPreferences.setMockInitialValues({
        ProfileScopedPreferenceKeys.uiPreferencesUpdatedAtMs(1):
            localTs.millisecondsSinceEpoch,
      });

      // Remote is older than the SharedPrefs-stored local timestamp → skip.
      await merger.merge(
        profileId: 1,
        rows: [
          {'updated_at': _dt(2026).toIso8601String(), 'app_locale': 'he'},
        ],
      );
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString(ProfileScopedPreferenceKeys.appLocale(1)),
        isNull,
        reason: 'Remote (2026) must not overwrite local (2027)',
      );
    });

    test(
      'within ±5 s clock-skew window: remote server syncedAt wins tie-break',
      () async {
        final base = DateTime.utc(2026, 3, 15, 10, 0, 0);
        // local and remote updatedAt differ by only 3 s (within 5 s window)
        final localUpdatedAt = base;
        final remoteUpdatedAt = base.add(const Duration(seconds: 3));

        final localSyncedAt = base.subtract(const Duration(seconds: 10));
        final remoteSyncedAt = base.add(const Duration(seconds: 5));

        store.seed(
          kind: EntityKind.uiPreferences,
          profileId: 1,
          naturalKey: 'data',
          updatedAt: localUpdatedAt,
          syncedAt: localSyncedAt,
        );

        await merger.merge(
          profileId: 1,
          rows: [
            {
              'updated_at': remoteUpdatedAt.toIso8601String(),
              'synced_at': remoteSyncedAt.toIso8601String(),
              'app_locale': 'he',
            },
          ],
        );
        final prefs = await SharedPreferences.getInstance();
        // remoteSyncedAt > localSyncedAt → remote wins
        expect(prefs.getString(ProfileScopedPreferenceKeys.appLocale(1)), 'he');
      },
    );
  });

  group('UiPreferencesMerger — per-field write rules', () {
    late _FakeMergeStore store;
    late UiPreferencesMerger merger;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      store = _FakeMergeStore();
      merger = UiPreferencesMerger(store: store);
    });

    test('app_locale "en" is written to scoped key', () async {
      await merger.merge(
        profileId: 5,
        rows: [
          {'updated_at': _dt(2026).toIso8601String(), 'app_locale': 'en'},
        ],
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(ProfileScopedPreferenceKeys.appLocale(5)), 'en');
    });

    test('app_locale "he" is written to scoped key', () async {
      await merger.merge(
        profileId: 5,
        rows: [
          {'updated_at': _dt(2026).toIso8601String(), 'app_locale': 'he'},
        ],
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(ProfileScopedPreferenceKeys.appLocale(5)), 'he');
    });

    test('app_locale with invalid value is not written', () async {
      await merger.merge(
        profileId: 5,
        rows: [
          {
            'updated_at': _dt(2026).toIso8601String(),
            'app_locale': 'fr', // not 'en' or 'he'
          },
        ],
      );
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString(ProfileScopedPreferenceKeys.appLocale(5)),
        isNull,
        reason: '"fr" is not an accepted locale — must not be written',
      );
    });

    test('use_hebrew_calendar bool true is written', () async {
      await merger.merge(
        profileId: 5,
        rows: [
          {
            'updated_at': _dt(2026).toIso8601String(),
            'use_hebrew_calendar': true,
          },
        ],
      );
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getBool(ProfileScopedPreferenceKeys.useHebrewCalendar(5)),
        isTrue,
      );
    });

    test('use_hebrew_calendar bool false is written', () async {
      await merger.merge(
        profileId: 5,
        rows: [
          {
            'updated_at': _dt(2026).toIso8601String(),
            'use_hebrew_calendar': false,
          },
        ],
      );
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getBool(ProfileScopedPreferenceKeys.useHebrewCalendar(5)),
        isFalse,
      );
    });

    test('use_hebrew_calendar non-bool is not written', () async {
      await merger.merge(
        profileId: 5,
        rows: [
          {
            'updated_at': _dt(2026).toIso8601String(),
            'use_hebrew_calendar': 1, // int, not bool
          },
        ],
      );
      final prefs = await SharedPreferences.getInstance();
      // The merger guards `if (hebrew is bool)` — int is not written
      expect(
        prefs.getBool(ProfileScopedPreferenceKeys.useHebrewCalendar(5)),
        isNull,
      );
    });

    test(
      'text_display.font_size_index=0 is written (lower boundary)',
      () async {
        await merger.merge(
          profileId: 5,
          rows: [
            {
              'updated_at': _dt(2026).toIso8601String(),
              'text_display': {'font_size_index': 0},
            },
          ],
        );
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getInt(ProfileScopedPreferenceKeys.textFontSize(5)), 0);
      },
    );

    test(
      'text_display.font_size_index=2 is written (upper boundary)',
      () async {
        await merger.merge(
          profileId: 5,
          rows: [
            {
              'updated_at': _dt(2026).toIso8601String(),
              'text_display': {'font_size_index': 2},
            },
          ],
        );
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getInt(ProfileScopedPreferenceKeys.textFontSize(5)), 2);
      },
    );

    test('text_display.font_size_index=3 is rejected (out of range)', () async {
      await merger.merge(
        profileId: 5,
        rows: [
          {
            'updated_at': _dt(2026).toIso8601String(),
            'text_display': {'font_size_index': 3},
          },
        ],
      );
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getInt(ProfileScopedPreferenceKeys.textFontSize(5)),
        isNull,
        reason: 'font_size_index=3 is out-of-range; must not be written',
      );
    });

    test(
      'text_display.font_size_index=-1 is rejected (out of range)',
      () async {
        await merger.merge(
          profileId: 5,
          rows: [
            {
              'updated_at': _dt(2026).toIso8601String(),
              'text_display': {'font_size_index': -1},
            },
          ],
        );
        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getInt(ProfileScopedPreferenceKeys.textFontSize(5)),
          isNull,
          reason: 'font_size_index=-1 is out-of-range; must not be written',
        );
      },
    );

    test('text_display.show_nikud true is written', () async {
      await merger.merge(
        profileId: 5,
        rows: [
          {
            'updated_at': _dt(2026).toIso8601String(),
            'text_display': {'show_nikud': true},
          },
        ],
      );
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getBool(ProfileScopedPreferenceKeys.textShowNikud(5)),
        isTrue,
      );
    });

    test('text_display.show_nikud false is written', () async {
      await merger.merge(
        profileId: 5,
        rows: [
          {
            'updated_at': _dt(2026).toIso8601String(),
            'text_display': {'show_nikud': false},
          },
        ],
      );
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getBool(ProfileScopedPreferenceKeys.textShowNikud(5)),
        isFalse,
      );
    });

    test('text_display absent — no font/nikud keys are written', () async {
      await merger.merge(
        profileId: 5,
        rows: [
          {
            'updated_at': _dt(2026).toIso8601String(),
            // no text_display block
            'app_locale': 'en',
          },
        ],
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt(ProfileScopedPreferenceKeys.textFontSize(5)), isNull);
      expect(
        prefs.getBool(ProfileScopedPreferenceKeys.textShowNikud(5)),
        isNull,
      );
    });

    test('learning_order_parent_controls true is written', () async {
      await merger.merge(
        profileId: 5,
        rows: [
          {
            'updated_at': _dt(2026).toIso8601String(),
            'learning_order_parent_controls': true,
          },
        ],
      );
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getBool(
          ProfileScopedPreferenceKeys.learningOrderParentControls(5),
        ),
        isTrue,
      );
    });

    test('learning_order_parent_controls false is written', () async {
      await merger.merge(
        profileId: 5,
        rows: [
          {
            'updated_at': _dt(2026).toIso8601String(),
            'learning_order_parent_controls': false,
          },
        ],
      );
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getBool(
          ProfileScopedPreferenceKeys.learningOrderParentControls(5),
        ),
        isFalse,
      );
    });

    test('hebrew_terms_script true is written', () async {
      await merger.merge(
        profileId: 5,
        rows: [
          {
            'updated_at': _dt(2026).toIso8601String(),
            'hebrew_terms_script': true,
          },
        ],
      );
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getBool(ProfileScopedPreferenceKeys.hebrewTermsScript(5)),
        isTrue,
      );
    });

    test('hebrew_terms_script false is written', () async {
      await merger.merge(
        profileId: 5,
        rows: [
          {
            'updated_at': _dt(2026).toIso8601String(),
            'hebrew_terms_script': false,
          },
        ],
      );
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getBool(ProfileScopedPreferenceKeys.hebrewTermsScript(5)),
        isFalse,
      );
    });

    test('sacred_time block is silently ignored (DEC-26 / WS6)', () async {
      // The sacred_time block must never be written to SharedPreferences.
      // If the merger accidentally writes it, the test will fail.
      await merger.merge(
        profileId: 5,
        rows: [
          {
            'updated_at': _dt(2026).toIso8601String(),
            'app_locale': 'en',
            'sacred_time': {
              'latitude': 31.7683,
              'longitude': 35.2137,
              'tzid': 'Asia/Jerusalem',
            },
          },
        ],
      );
      final prefs = await SharedPreferences.getInstance();
      // No key starting with "sacred_time" should have been written
      final allKeys = prefs.getKeys();
      for (final key in allKeys) {
        expect(
          key.contains('sacred_time'),
          isFalse,
          reason: 'sacred_time must not be written to SharedPrefs (DEC-26)',
        );
      }
    });

    test('all fields written in a single row merge', () async {
      await merger.merge(
        profileId: 7,
        rows: [
          {
            'updated_at': _dt(2026).toIso8601String(),
            'app_locale': 'he',
            'use_hebrew_calendar': true,
            'text_display': {'font_size_index': 1, 'show_nikud': false},
            'learning_order_parent_controls': true,
            'hebrew_terms_script': false,
          },
        ],
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(ProfileScopedPreferenceKeys.appLocale(7)), 'he');
      expect(
        prefs.getBool(ProfileScopedPreferenceKeys.useHebrewCalendar(7)),
        isTrue,
      );
      expect(prefs.getInt(ProfileScopedPreferenceKeys.textFontSize(7)), 1);
      expect(
        prefs.getBool(ProfileScopedPreferenceKeys.textShowNikud(7)),
        isFalse,
      );
      expect(
        prefs.getBool(
          ProfileScopedPreferenceKeys.learningOrderParentControls(7),
        ),
        isTrue,
      );
      expect(
        prefs.getBool(ProfileScopedPreferenceKeys.hebrewTermsScript(7)),
        isFalse,
      );
    });
  });

  group('UiPreferencesMerger — cross-profile isolation', () {
    late _FakeMergeStore store;
    late UiPreferencesMerger merger;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      store = _FakeMergeStore();
      merger = UiPreferencesMerger(store: store);
    });

    test('merging profile B does NOT overwrite profile A locale', () async {
      // Profile A: en
      await merger.merge(
        profileId: 1,
        rows: [
          {
            'updated_at': DateTime.utc(2026, 5, 1).toIso8601String(),
            'app_locale': 'en',
          },
        ],
      );
      // Profile B: he
      await merger.merge(
        profileId: 2,
        rows: [
          {
            'updated_at': DateTime.utc(2026, 5, 2).toIso8601String(),
            'app_locale': 'he',
          },
        ],
      );
      final prefs = await SharedPreferences.getInstance();
      // Profile A must still be 'en'
      expect(
        prefs.getString(ProfileScopedPreferenceKeys.appLocale(1)),
        'en',
        reason: 'Profile A locale must not be overwritten by profile B merge',
      );
      // Profile B must be 'he'
      expect(prefs.getString(ProfileScopedPreferenceKeys.appLocale(2)), 'he');
    });

    test(
      'merging profile A does NOT overwrite profile B hebrew_calendar',
      () async {
        await merger.merge(
          profileId: 10,
          rows: [
            {
              'updated_at': DateTime.utc(2026, 5, 1).toIso8601String(),
              'use_hebrew_calendar': false,
            },
          ],
        );
        await merger.merge(
          profileId: 20,
          rows: [
            {
              'updated_at': DateTime.utc(2026, 5, 2).toIso8601String(),
              'use_hebrew_calendar': true,
            },
          ],
        );
        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getBool(ProfileScopedPreferenceKeys.useHebrewCalendar(10)),
          isFalse,
        );
        expect(
          prefs.getBool(ProfileScopedPreferenceKeys.useHebrewCalendar(20)),
          isTrue,
        );
      },
    );

    test(
      'later merge of same profile with newer timestamp overwrites earlier',
      () async {
        await merger.merge(
          profileId: 3,
          rows: [
            {
              'updated_at': _dt(2025).toIso8601String(),
              'app_locale': 'en',
              'use_hebrew_calendar': false,
            },
          ],
        );
        await merger.merge(
          profileId: 3,
          rows: [
            {
              'updated_at': _dt(2026).toIso8601String(),
              'app_locale': 'he',
              'use_hebrew_calendar': true,
            },
          ],
        );
        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getString(ProfileScopedPreferenceKeys.appLocale(3)),
          'he',
          reason: 'Newer merge for same profile must win',
        );
        expect(
          prefs.getBool(ProfileScopedPreferenceKeys.useHebrewCalendar(3)),
          isTrue,
        );
      },
    );

    test(
      'older merge of same profile does NOT overwrite newer already-applied',
      () async {
        // Apply a newer row first.
        await merger.merge(
          profileId: 4,
          rows: [
            {'updated_at': _dt(2026).toIso8601String(), 'app_locale': 'he'},
          ],
        );
        // Then try to apply an older row — must be skipped.
        await merger.merge(
          profileId: 4,
          rows: [
            {'updated_at': _dt(2025).toIso8601String(), 'app_locale': 'en'},
          ],
        );
        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getString(ProfileScopedPreferenceKeys.appLocale(4)),
          'he',
          reason: 'Older remote must not revert a newer already-applied merge',
        );
      },
    );
  });
}
