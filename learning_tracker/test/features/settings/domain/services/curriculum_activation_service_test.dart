import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart';
import 'package:learning_tracker/data/repositories/firestore_curriculum_track_repository.dart';
import 'package:learning_tracker/data/repositories/firestore_study_day_config_repository.dart';
import 'package:learning_tracker/features/settings/presentation/providers/curriculum_activation_providers.dart';
import 'package:learning_tracker/features/settings/domain/exceptions/last_active_curriculum_exception.dart';
import 'package:learning_tracker/features/tracks/domain/services/curriculum_activation_service.dart';
import 'package:learning_tracker/features/tracks/setup/domain/entities/curriculum_track.dart';

import '../../../../helpers/firestore_fake.dart';
import '../../../../helpers/firestore_fixtures.dart';

const _uid = 'curriculum-activation-test-user';
const _profileId = '01J0000000000000000000000A';

CollectionReference<Map<String, dynamic>> _profileCollection(
  FakeFirebaseFirestore firestore,
  String collection,
) => firestore
    .collection('users')
    .doc(_uid)
    .collection('learner_profiles')
    .doc(_profileId)
    .collection(collection);

void main() {
  late FakeFirebaseFirestore firestore;
  late ProviderContainer container;
  late FirestoreCurriculumTrackRepository trackRepository;
  late FirestoreStudyDayConfigRepository studyDayConfigRepository;
  late CurriculumActivationService service;

  setUp(() async {
    firestore = createFakeFirestore(authenticatedUid: _uid);
    await seedAccount(firestore, uid: _uid);
    await seedProfile(firestore, uid: _uid, profileId: _profileId);

    trackRepository = FirestoreCurriculumTrackRepository(
      firestore: firestore,
      uid: _uid,
      profileId: _profileId,
    );
    studyDayConfigRepository = FirestoreStudyDayConfigRepository(
      firestore: firestore,
      uid: _uid,
      profileId: _profileId,
    );
    container = ProviderContainer(
      overrides: [
        firestoreCurriculumTrackRepositoryProvider.overrideWith(
          (ref) async => trackRepository,
        ),
        firestoreStudyDayConfigRepositoryProvider.overrideWith(
          (ref) async => studyDayConfigRepository,
        ),
      ],
    );
    service = container.read(curriculumActivationServiceProvider);
  });

  tearDown(() {
    container.dispose();
  });

  Future<List<Map<String, dynamic>>> getStudyDayConfigs() async {
    final snapshot = await _profileCollection(
      firestore,
      'study_day_configs',
    ).get();
    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  group('CurriculumActivationService', () {
    test('activate adds curriculum to Firestore', () async {
      await service.activate(CurriculumId.bavli);

      expect(await trackRepository.isActive(CurriculumId.bavli), isTrue);
    });

    test('deactivate retires one of two curricula', () async {
      await service.activate(CurriculumId.bavli);
      await service.activate(CurriculumId.yerushalmi);

      await service.deactivate(CurriculumId.bavli);

      expect(await trackRepository.isActive(CurriculumId.bavli), isFalse);
    });

    test('toggle activates an inactive curriculum', () async {
      await service.toggle(CurriculumId.bavli);

      expect(await trackRepository.isActive(CurriculumId.bavli), isTrue);
    });

    test('toggle deactivates an active curriculum', () async {
      await service.activate(CurriculumId.bavli);
      await service.activate(CurriculumId.yerushalmi);

      await service.toggle(CurriculumId.bavli);

      expect(await trackRepository.isActive(CurriculumId.bavli), isFalse);
    });

    test(
      'attempting to deactivate the last curriculum throws LastActiveCurriculumException',
      () async {
        await service.activate(CurriculumId.mishnayos);

        expect(
          () => service.deactivate(CurriculumId.mishnayos),
          throwsA(isA<LastActiveCurriculumException>()),
        );
      },
    );

    test(
      'initialize sets default active curriculum (Mishnayos) if none active',
      () async {
        await service.initialize();

        expect(
          await trackRepository.getActiveCurriculumIds(),
          contains(CurriculumId.mishnayos.storageKey),
        );
      },
    );

    test('initialize does not override existing active curricula', () async {
      await service.activate(CurriculumId.bavli);

      await service.initialize();

      final activeCurricula = await service.getActiveCurricula();
      expect(activeCurricula, contains(CurriculumId.bavli));
      expect(activeCurricula, isNot(contains(CurriculumId.mishnayos)));
    });

    test(
      'watchActiveCurricula emits stream of active curriculum IDs',
      () async {
        final stream = service.watchActiveCurricula();

        expect(
          stream,
          emitsInOrder([
            <String>[],
            [CurriculumId.bavli.storageKey],
          ]),
        );

        await Future<void>.delayed(Duration.zero);
        await service.activate(CurriculumId.bavli);
      },
    );

    test('getActiveCurricula returns list of CurriculumId enums', () async {
      await service.activate(CurriculumId.bavli);
      await service.activate(CurriculumId.yerushalmi);

      expect(
        await service.getActiveCurricula(),
        containsAll([CurriculumId.bavli, CurriculumId.yerushalmi]),
      );
    });

    test('all curricula can be activated simultaneously', () async {
      for (final curriculum in CurriculumId.values) {
        await service.activate(curriculum);
      }

      final activeCurricula = await service.getActiveCurricula();
      expect(activeCurricula, hasLength(CurriculumId.values.length));
      expect(activeCurricula, containsAll(CurriculumId.values));
    });

    test(
      'deactivation retires the track and preserves completions (DNI-317)',
      () async {
        await service.activate(CurriculumId.bavli);
        await service.activate(CurriculumId.mishnayos);
        final completionId = await seedCompletion(
          firestore,
          uid: _uid,
          profileId: _profileId,
          curriculumId: CurriculumId.bavli,
          sefariaRef: 'Berakhot.2a',
          stageId: 1,
          points: 10,
        );

        await service.deactivate(CurriculumId.bavli);

        final bavliTrack = (await trackRepository.getAllTracks()).singleWhere(
          (track) => track.curriculumId == CurriculumId.bavli,
        );
        expect(bavliTrack.state, CurriculumTrackState.retired.storageKey);

        final completion = await _profileCollection(
          firestore,
          'completions',
        ).doc(completionId).get();
        expect(completion.exists, isTrue);
        expect(completion.data()!['sefaria_ref'], 'Berakhot.2a');
      },
    );

    test(
      'deactivation preserves bookmarks (curriculum-scoped, not track-scoped)',
      () async {
        await service.activate(CurriculumId.bavli);
        await service.activate(CurriculumId.mishnayos);
        await seedBookmark(
          firestore,
          uid: _uid,
          profileId: _profileId,
          curriculumId: CurriculumId.bavli,
          sefariaRef: 'Berakhot.2a',
        );

        await service.deactivate(CurriculumId.bavli);

        final bookmarks = await _profileCollection(
          firestore,
          'bookmarks',
        ).get();
        expect(bookmarks.docs, hasLength(1));
        expect(bookmarks.docs.single.data()['sefaria_ref'], 'Berakhot.2a');
      },
    );

    test(
      'cannot deactivate all curricula via toggle (last-one-standing)',
      () async {
        await service.activate(CurriculumId.bavli);
        await service.activate(CurriculumId.mishnayos);

        await service.toggle(CurriculumId.bavli);

        expect(
          () => service.toggle(CurriculumId.mishnayos),
          throwsA(isA<LastActiveCurriculumException>()),
        );

        final active = await service.getActiveCurricula();
        expect(active, contains(CurriculumId.mishnayos));
        expect(active, hasLength(1));
      },
    );
  });

  // The old Drift test also asserted a local row plus a SyncWriteFacade
  // outbox. The current service has neither surface: activation writes the
  // Firestore study_day_configs collection directly, so these tests assert
  // that real Firestore state instead.
  group('study-day defaults on activation', () {
    test(
      'activate() seeds 7 Firestore study-day configs for the profile',
      () async {
        await service.activate(CurriculumId.bavli);

        final configs = await getStudyDayConfigs();
        expect(configs, hasLength(7));
        expect(
          configs.every(
            (config) =>
                config['curriculum_id'] == CurriculumId.bavli.storageKey &&
                config['day_type'] == 'study',
          ),
          isTrue,
        );
        expect(
          configs.map((config) => config['day_of_week']).toSet(),
          equals({1, 2, 3, 4, 5, 6, 7}),
        );
      },
    );

    test(
      'activateForProfile() seeds configs for the already-scoped ULID profile',
      () async {
        // The integer argument is retained for source compatibility but is
        // intentionally ignored by the Firestore-native service.
        await service.activateForProfile(CurriculumId.mishnayos, 1);

        final configs = await getStudyDayConfigs();
        expect(configs, hasLength(7));
        expect(
          configs.every(
            (config) =>
                config['curriculum_id'] == CurriculumId.mishnayos.storageKey,
          ),
          isTrue,
        );
      },
    );

    test('initialize() seeds 7 configs when no curricula are active', () async {
      await service.initialize();

      final configs = await getStudyDayConfigs();
      expect(configs, hasLength(7));
      expect(
        configs.every(
          (config) =>
              config['curriculum_id'] == CurriculumId.mishnayos.storageKey,
        ),
        isTrue,
      );
    });
  });
}
