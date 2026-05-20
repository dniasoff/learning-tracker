/// Story acceptance tests for Epic 25 — Story 25.13 (DNI-334):
/// SyncEngine decomposition Part 2 — MergeRouter + sealed EntityMerger strategies.
///
/// Validates:
///   AC1 — `MergeRouter` dispatches by entity kind to an `EntityMerger<T>`
///         implementation. Unknown kinds fail loudly.
///   AC2 — Eight sealed mergers exist (one file each):
///         CompletionEventMerger, StreakEventMerger, LearnerProfileMerger,
///         TrackConfigMerger, BookmarkMerger, SettingsMerger,
///         StageDefinitionMerger, ProfileProgramMerger.
///   AC3 — `StageDefinitionMerger` merges ALL fields — `scheduleType`,
///         `daysOfWeek`, `rollingWindowSize`, `delayDays` (closes T1.9).
///   AC4 — `MergeRules` is load-bearing: every LWW merger consults it
///         (verified by a structural import-check + a behavioural test).
///   AC5 — One-file extension: adding a new entity touches only the new
///         merger file + the `MergeRouter` switch (verified by counting
///         router branches and confirming no other file enumerates the
///         kind set).
@Tags(['epic_25'])
library;

import 'dart:io';

import 'package:drift/native.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/sync/merge/bookmark_merger.dart';
import 'package:learning_tracker/core/sync/merge/completion_event_merger.dart';
import 'package:learning_tracker/core/sync/merge/entity_merger.dart';
import 'package:learning_tracker/core/sync/merge/learner_profile_merger.dart';
import 'package:learning_tracker/core/sync/merge/merge_router.dart';
import 'package:learning_tracker/core/sync/merge/profile_program_merger.dart';
import 'package:learning_tracker/core/sync/merge/settings_merger.dart';
import 'package:learning_tracker/core/sync/merge/stage_definition_merger.dart';
import 'package:learning_tracker/core/sync/merge/streak_event_merger.dart';
import 'package:learning_tracker/core/sync/merge/track_config_merger.dart';
import 'package:learning_tracker/core/sync/pull_pipeline.dart';
import 'package:test/test.dart';

void main() {
  group(
    'Story 25.13 — MergeRouter + sealed EntityMerger',
    tags: ['story_25_13'],
    () {
      // ── AC1 — Router dispatches by kind ──────────────────────────────────

      group('MergeRouter dispatch', () {
        test('dispatches each known kind to the matching merger', () async {
          final calls = <String>[];
          // All kinds in EntityKind.all must be wired so the router
          // returns continueNext rather than halt. Add new entries here
          // whenever EntityKind.all grows.
          final mergers = {
            for (final kind in EntityKind.all)
              kind: _RecordingMerger(kind, calls),
          };
          final router = MergeRouter(mergers: mergers);

          for (final kind in EntityKind.all) {
            final outcome = await router.dispatch(
              profileId: 1,
              kind: kind,
              rows: [
                {'id': 'r-$kind'},
              ],
            );
            expect(outcome, MergeOutcome.continueNext);
          }

          expect(calls, equals(EntityKind.all));
        });

        test(
          'unknown kind returns halt and records nothing — fails loudly',
          () async {
            final router = MergeRouter(mergers: const {});

            final outcome = await router.dispatch(
              profileId: 1,
              kind: 'mystery_kind',
              rows: [
                {'id': 'r'},
              ],
            );

            expect(outcome, MergeOutcome.halt);
          },
        );

        test('empty rows short-circuits without invoking the merger', () async {
          final calls = <String>[];
          final router = MergeRouter(
            mergers: {
              EntityKind.completion: _RecordingMerger(
                EntityKind.completion,
                calls,
              ),
            },
          );

          await router.dispatch(
            profileId: 1,
            kind: EntityKind.completion,
            rows: const [],
          );

          expect(calls, isEmpty);
        });
      });

      // ── AC2 — Eight sealed mergers, each in its own file ─────────────────

      group('sealed EntityMerger strategies', () {
        test('eight concrete subclasses exist, one per file', () {
          final libDir = Directory('lib/core/sync/merge');
          expect(libDir.existsSync(), isTrue);

          const expected = <String>{
            'completion_event_merger.dart',
            'streak_event_merger.dart',
            'learner_profile_merger.dart',
            'track_config_merger.dart',
            'bookmark_merger.dart',
            'settings_merger.dart',
            'stage_definition_merger.dart',
            'profile_program_merger.dart',
          };

          final actual = libDir
              .listSync()
              .whereType<File>()
              .map((f) => f.uri.pathSegments.last)
              .where(expected.contains)
              .toSet();

          expect(actual, equals(expected));
        });

        test('each concrete merger is an EntityMerger', () async {
          // StreakEventMerger (DNI-337) uses an in-memory DB instead of
          // MergeStore — its constructor changed, but it still implements
          // EntityMerger so the router can dispatch to it unchanged.
          final db = UserDatabase(NativeDatabase.memory());
          addTearDown(db.close);

          final completion = CompletionEventMerger(store: _NullMergeStore());
          final streak = StreakEventMerger(db);
          final learnerProfile = LearnerProfileMerger(store: _NullMergeStore());
          final trackConfig = TrackConfigMerger(store: _NullMergeStore());
          final bookmark = BookmarkMerger(store: _NullMergeStore());
          final settings = SettingsMerger(store: _NullMergeStore());
          final stageDef = StageDefinitionMerger(store: _NullMergeStore());
          final profileProgram = ProfileProgramMerger(store: _NullMergeStore());

          expect(completion, isA<EntityMerger>());
          expect(streak, isA<EntityMerger>());
          expect(learnerProfile, isA<EntityMerger>());
          expect(trackConfig, isA<EntityMerger>());
          expect(bookmark, isA<EntityMerger>());
          expect(settings, isA<EntityMerger>());
          expect(stageDef, isA<EntityMerger>());
          expect(profileProgram, isA<EntityMerger>());

          expect(completion.kind, EntityKind.completion);
          expect(streak.kind, EntityKind.streak);
          expect(learnerProfile.kind, EntityKind.learnerProfile);
          expect(trackConfig.kind, EntityKind.trackConfig);
          expect(bookmark.kind, EntityKind.bookmark);
          expect(settings.kind, EntityKind.settings);
          expect(stageDef.kind, EntityKind.stageDefinition);
          expect(profileProgram.kind, EntityKind.profileProgram);
        });
      });

      // ── AC3 — StageDefinitionMerger covers all T1.9 fields ───────────────

      group('StageDefinitionMerger (T1.9)', () {
        test('merges scheduleType, daysOfWeek, rollingWindowSize, delayDays — '
            'not just delayDays', () async {
          final store = _RecordingMergeStore();
          final merger = StageDefinitionMerger(store: store);

          await merger.merge(
            profileId: 1,
            rows: [
              {
                'id': 7,
                'profile_id': 1,
                'curriculum_id': 'mishnayos',
                'track_id': 3,
                'stage_order': 1,
                'stage_name': 'learning',
                'delay_days': 0,
                'schedule_type': 'rolling_window',
                'days_of_week': '1,3,5',
                'rolling_window_size': 7,
                'updated_at': DateTime.utc(2026, 5, 13).toIso8601String(),
              },
            ],
          );

          expect(store.upserts, hasLength(1));
          final fields = store.upserts.single.fields;
          expect(fields['delay_days'], 0);
          expect(fields['schedule_type'], 'rolling_window');
          expect(fields['days_of_week'], '1,3,5');
          expect(fields['rolling_window_size'], 7);
          expect(fields['stage_name'], 'learning');
        });
      });

      // ── AC4 — MergeRules is load-bearing ─────────────────────────────────

      group('MergeRules is load-bearing', () {
        test('every LWW merger source file imports merge_rules.dart', () {
          const lwwMergers = <String>[
            'lib/core/sync/merge/learner_profile_merger.dart',
            'lib/core/sync/merge/track_config_merger.dart',
            'lib/core/sync/merge/bookmark_merger.dart',
            'lib/core/sync/merge/settings_merger.dart',
            'lib/core/sync/merge/stage_definition_merger.dart',
          ];

          for (final path in lwwMergers) {
            final src = File(path).readAsStringSync();
            expect(
              src.contains('merge_rules.dart'),
              isTrue,
              reason:
                  '$path must import merge_rules.dart so the LWW rule is '
                  'consulted — DNI-334 AC: MergeRules is load-bearing, not '
                  'vestigial',
            );
          }
        });

        test('BookmarkMerger drops a remote row older than the local row '
            '(LWW behaviour from MergeRules)', () async {
          final store = _RecordingMergeStore()
            ..localUpdatedAt = DateTime.utc(2026, 5, 13);
          final merger = BookmarkMerger(store: store);

          await merger.merge(
            profileId: 1,
            rows: [
              {
                'id': 1,
                'profile_id': 1,
                'curriculum_id': 'mishnayos',
                'track_type': 'learning',
                'sefaria_ref': 'Mishnah Berakhot 1',
                'updated_at': DateTime.utc(2026, 5, 1).toIso8601String(),
              },
            ],
          );

          expect(
            store.upserts,
            isEmpty,
            reason: 'remote is older than local — must be dropped',
          );
          expect(
            store.lwwChecks,
            isNotEmpty,
            reason: 'merger must consult MergeRules.remoteIsNewer',
          );
        });

        test(
          'BookmarkMerger applies a remote row that is newer than local',
          () async {
            final store = _RecordingMergeStore()
              ..localUpdatedAt = DateTime.utc(2026, 5, 1);
            final merger = BookmarkMerger(store: store);

            await merger.merge(
              profileId: 1,
              rows: [
                {
                  'id': 1,
                  'profile_id': 1,
                  'curriculum_id': 'mishnayos',
                  'track_type': 'learning',
                  'sefaria_ref': 'Mishnah Berakhot 1',
                  'updated_at': DateTime.utc(2026, 5, 13).toIso8601String(),
                },
              ],
            );

            expect(store.upserts, hasLength(1));
          },
        );
      });

      // ── AC5 — One-file extension story ────────────────────────────────────

      group('one-file extension contract', () {
        test('MergeRouter dispatch branches cover every kind in EntityKind.all '
            '— adding a kind means: new merger file + 1 entry in EntityKind '
            '+ 1 case in the router switch', () {
          // Structural check: MergeRouter source references each
          // EntityKind constant by name in its switch. We look for the
          // camelCase symbol (`EntityKind.completion`) rather than the
          // string literal, since the router uses the constant.
          final routerSrc = File(
            'lib/core/sync/merge/merge_router.dart',
          ).readAsStringSync();
          for (final kind in EntityKind.all) {
            // Translate snake_case kind back to the EntityKind member
            // name. e.g. 'learner_profile' -> 'learnerProfile'.
            final member = kind.replaceAllMapped(
              RegExp('_([a-z])'),
              (m) => m.group(1)!.toUpperCase(),
            );
            expect(
              routerSrc.contains('EntityKind.$member'),
              isTrue,
              reason:
                  'merge_router.dart must reference EntityKind.$member '
                  'in its switch — missing for kind=$kind',
            );
          }
        });

        test('mergeRouterProvider wires every kind in EntityKind.all '
            '— a missing entry means the pull pipeline silently halts '
            'on that kind in production', () {
          // Structural check: the production provider's map must list
          // every EntityKind. Wave 6 re-review caught a case where a new
          // kind (profileProgram) was added to EntityKind.all and the
          // router switch but NOT to the provider map — the pull halted
          // silently while a hand-wired test router passed.
          final providerSrc = File(
            'lib/core/sync/providers/merge_router_provider.dart',
          ).readAsStringSync();
          for (final kind in EntityKind.all) {
            final member = kind.replaceAllMapped(
              RegExp('_([a-z])'),
              (m) => m.group(1)!.toUpperCase(),
            );
            expect(
              providerSrc.contains('EntityKind.$member:'),
              isTrue,
              reason:
                  'merge_router_provider.dart must wire EntityKind.$member '
                  'to a concrete merger — missing for kind=$kind',
            );
          }
        });
      });
    },
  );
}

// ─── Test doubles ────────────────────────────────────────────────────────────

class _RecordingMerger implements EntityMerger {
  _RecordingMerger(this.kind, this._log);
  @override
  final String kind;
  final List<String> _log;

  @override
  Future<void> merge({
    required int profileId,
    required List<Map<String, dynamic>> rows,
  }) async {
    _log.add(kind);
  }
}

class _Upsert {
  _Upsert({required this.kind, required this.fields});
  final String kind;
  final Map<String, dynamic> fields;
}

class _RecordingMergeStore implements MergeStore {
  final List<_Upsert> upserts = [];
  final List<String> lwwChecks = [];
  DateTime? localUpdatedAt;

  @override
  Future<DateTime?> currentUpdatedAt({
    required String kind,
    required int profileId,
    required String naturalKey,
  }) async {
    lwwChecks.add('$kind:$naturalKey');
    return localUpdatedAt;
  }

  @override
  Future<void> upsert({
    required String kind,
    required int profileId,
    required Map<String, dynamic> fields,
  }) async {
    upserts.add(_Upsert(kind: kind, fields: fields));
  }

  @override
  Future<void> insertIfAbsent({
    required String kind,
    required int profileId,
    required String naturalKey,
    required Map<String, dynamic> fields,
  }) async {
    upserts.add(_Upsert(kind: kind, fields: fields));
  }
}

class _NullMergeStore implements MergeStore {
  @override
  Future<DateTime?> currentUpdatedAt({
    required String kind,
    required int profileId,
    required String naturalKey,
  }) async => null;

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
}
