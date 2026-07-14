/// Story acceptance tests for Story 26.22 (DNI-365) —
/// Shared TrackManagementBody + curriculum-minimum-1 guard.
///
/// AC1: One TrackManagementBody widget is shared between both screens
///      (only role-specific actions differ).
/// AC2: CurriculumActivationService.deactivate(curriculumId) throws
///      LastActiveCurriculumException when exactly one active curriculum.
/// AC3: UI catches and surfaces the constraint message clearly
///      (no silent failure) — verified via service + widget import.
///
/// AUD-t-story-acceptance-04: at the time this file was first written,
/// TrackManagementBody had zero callers in lib/ — a hand-rolled duplicate,
/// track_management_hub_screen.dart, shipped instead, and drifted (it grew
/// its own TS-16 last-active-curriculum delete guard that the widget never
/// received). The AC1 group above only proved the widget was *importable*
/// in isolation, which let that drift go unnoticed. The group below proves
/// the widget is actually wired into the real, routed screen, and that the
/// TS-16 guard lives in exactly one place:
///   AC1 (finding) — TrackManagementBody( appears in a real @RoutePage()
///        screen's build method.
///   AC2 (finding) — track_management_hub_screen.dart's source references
///        TrackManagementBody( (the same source-grep shape as 26.20 AC4's
///        settings_screen.dart check).
///   AC3 (finding) — the TS-16 guard (trackDeletionAllowed) is declared in
///        track_management_body.dart only, not duplicated in
///        track_management_hub_screen.dart.
@Tags(['epic_26'])
library;

import 'dart:io';

import 'package:drift/native.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/learning/data/repositories/track_repository_impl.dart';
import 'package:learning_tracker/features/settings/domain/exceptions/last_active_curriculum_exception.dart';
import 'package:learning_tracker/features/tracks/domain/services/curriculum_activation_service.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/widgets/track_management_body.dart';
import 'package:test/test.dart';

/// Reads a source file, trying both repo-root-relative and
/// learning_tracker/-relative candidate paths (tests may run from either
/// working directory).
String _readSource(String relativePath) {
  final candidates = [
    File(relativePath),
    File('learning_tracker/$relativePath'),
  ];
  final file = candidates.firstWhere(
    (f) => f.existsSync(),
    orElse: () => candidates.first,
  );
  return file.existsSync() ? file.readAsStringSync() : '';
}

Future<void> _noPush(Map<String, dynamic> _) async {}

void main() {
  // ── AC1: TrackManagementBody widget exists and is importable ─────────────────
  group(
    'Story 26.22 AC1 — TrackManagementBody widget exists',
    tags: ['story_26_22'],
    () {
      test(
        'TrackManagementBody can be instantiated with showBackButton=false',
        () {
          const widget = TrackManagementBody(showBackButton: false);
          expect(widget.showBackButton, isFalse);
        },
      );

      test(
        'TrackManagementBody can be instantiated with showBackButton=true',
        () {
          const widget = TrackManagementBody(showBackButton: true);
          expect(widget.showBackButton, isTrue);
        },
      );

      test('TrackManagementBody default showBackButton is false', () {
        const widget = TrackManagementBody();
        expect(widget.showBackButton, isFalse);
      });
    },
  );

  // ── AC2 + AC3: service guard throws typed exception ──────────────────────────
  group(
    'Story 26.22 AC2+AC3 — LastActiveCurriculumException on deactivate',
    tags: ['story_26_22'],
    () {
      late UserDatabase database;
      late CurriculumActivationService service;

      setUp(() async {
        database = UserDatabase(NativeDatabase.memory());
        service = CurriculumActivationService(
          database: database,
          pushCurriculumTrack: _noPush,
          trackRepository: TrackRepositoryImpl(database: database),
          profileId: 0,
        );
      });

      tearDown(() => database.close());

      test(
        'deactivating the sole active curriculum throws LastActiveCurriculumException',
        () async {
          await service.activate(CurriculumId.mishnayos);

          await expectLater(
            () => service.deactivate(CurriculumId.mishnayos),
            throwsA(isA<LastActiveCurriculumException>()),
          );
        },
      );

      test(
        'LastActiveCurriculumException is a typed domain exception, not StateError',
        () async {
          await service.activate(CurriculumId.mishnayos);

          Object? caught;
          try {
            await service.deactivate(CurriculumId.mishnayos);
          } catch (e) {
            caught = e;
          }
          // Must be the typed domain exception.
          expect(caught, isA<LastActiveCurriculumException>());
          // Must NOT be a plain StateError (backward-compat check).
          expect(caught, isNot(isA<StateError>()));
        },
      );

      test('deactivating is allowed when 2+ curricula are active', () async {
        await service.activate(CurriculumId.mishnayos);
        await service.activate(CurriculumId.bavli);

        // Should complete without throwing.
        await service.deactivate(CurriculumId.bavli);

        final isStillActive = await database.activeCurriculumDao
            .isActiveForProfile(CurriculumId.bavli, 0);
        expect(isStillActive, isFalse);
      });

      test(
        'guard leaves DB intact on rejection (curriculum remains active)',
        () async {
          await service.activate(CurriculumId.mishnayos);

          try {
            await service.deactivate(CurriculumId.mishnayos);
          } on LastActiveCurriculumException {
            // Expected — swallow.
          }

          final stillActive = await database.activeCurriculumDao
              .isActiveForProfile(CurriculumId.mishnayos, 0);
          expect(
            stillActive,
            isTrue,
            reason: 'DB must remain intact after guard rejection',
          );
        },
      );

      test('exception has meaningful toString', () {
        const e = LastActiveCurriculumException();
        expect(e.toString(), contains('LastActiveCurriculumException'));
        expect(e.toString(), contains('last active curriculum'));
      });
    },
  );

  // ── AUD-t-story-acceptance-04 ─────────────────────────────────────────────
  group(
    'AUD-t-story-acceptance-04 — TrackManagementBody is wired into a real screen',
    tags: ['story_26_22'],
    () {
      late String hubSource;
      late String widgetSource;

      setUpAll(() {
        hubSource = _readSource(
          'lib/features/tracks/setup/presentation/screens/'
          'track_management_hub_screen.dart',
        );
        widgetSource = _readSource(
          'lib/features/tracks/setup/presentation/widgets/'
          'track_management_body.dart',
        );
      });

      // AC1 (finding): grep -rn 'TrackManagementBody(' lib/features/ matches
      // at least one real @RoutePage() screen's build method.
      test(
        'track_management_hub_screen.dart is a real @RoutePage() screen',
        () {
          expect(
            hubSource,
            isNotEmpty,
            reason: 'track_management_hub_screen.dart must exist',
          );
          expect(
            hubSource.contains('@RoutePage()'),
            isTrue,
            reason:
                'TrackManagementHubScreen must remain a routed screen — '
                'AC1 requires the real caller to be an @RoutePage()',
          );
        },
      );

      // AC2 (finding): a story-acceptance test asserts
      // track_management_hub_screen.dart's source contains
      // 'TrackManagementBody(', the same way 26.20 AC4 checks
      // settings_screen.dart.
      test(
        'track_management_hub_screen.dart references TrackManagementBody(',
        () {
          expect(
            hubSource.contains('TrackManagementBody('),
            isTrue,
            reason:
                'TrackManagementHubScreen.build() must instantiate '
                'TrackManagementBody( — the widget must not be dead code',
          );
        },
      );

      // AC3 (finding): the TS-16 deactivation guard logic exists in exactly
      // one place, not duplicated between the widget and the hub screen.
      test('trackDeletionAllowed (TS-16 guard) is declared only in '
          'track_management_body.dart', () {
        expect(
          widgetSource.contains('bool trackDeletionAllowed('),
          isTrue,
          reason:
              'track_management_body.dart must own the TS-16 guard '
              '(single source of truth)',
        );
        expect(
          hubSource.contains('trackDeletionAllowed('),
          isFalse,
          reason:
              'track_management_hub_screen.dart must not re-declare or '
              'duplicate the TS-16 guard — it must delegate to '
              'TrackManagementBody instead',
        );
      });
    },
  );
}
