/// Story acceptance tests for Story 26.22 (DNI-365) —
/// Shared TrackManagementBody + curriculum-minimum-1 guard.
///
/// AC1: One TrackManagementBody widget is shared between both screens
///      (only role-specific actions differ).
/// AC2: CurriculumActivationService.deactivate(curriculumId) throws
///      LastActiveCurriculumException when exactly one active curriculum.
/// AC3: UI catches and surfaces the constraint message clearly
///      (no silent failure) — verified via service + widget import.
@Tags(['epic_26'])
library;

import 'package:drift/native.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/learning/data/repositories/track_repository_impl.dart';
import 'package:learning_tracker/features/settings/domain/exceptions/last_active_curriculum_exception.dart';
import 'package:learning_tracker/features/tracks/domain/services/curriculum_activation_service.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/widgets/track_management_body.dart';
import 'package:test/test.dart';

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
}
