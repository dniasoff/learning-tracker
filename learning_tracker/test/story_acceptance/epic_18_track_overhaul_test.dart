import 'dart:convert';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/constants/hebrew_terms.dart';
import 'package:learning_tracker/core/database/seed/learning_program_seeds.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/data/repositories/firestore_curriculum_track_repository.dart';
import 'package:learning_tracker/data/repositories/firestore_point_config_repository.dart';
import 'package:learning_tracker/data/repositories/firestore_stage_definition_repository.dart';
import 'package:learning_tracker/features/onboarding/presentation/screens/onboarding_screen.dart'
    show childAwareText;
import 'package:learning_tracker/features/tracks/setup/domain/entities/add_track_result.dart';

import '../helpers/firestore_fixtures.dart';

const _uid = 'epic-18-user';
const _profileId = '01ARZ3NDEKTSV4RRFFQ69G5FAV';

void main() {
  late FakeFirebaseFirestore firestore;

  setUp(() => firestore = FakeFirebaseFirestore());

  group('Story 18.1 -- AddTrackFlow has no rewards step', () {
    test('AddTrackStep enum does not contain a rewards step', () {
      final names = AddTrackStep.values.map((step) => step.name.toLowerCase());
      expect(names, isNot(contains('reward')));
      expect(names, isNot(contains('rewards')));
    });

    test('AddTrackStep has exactly 8 steps ending at bulkMark', () {
      expect(AddTrackStep.values.length, 8);
      expect(AddTrackStep.values.last, AddTrackStep.bulkMark);
    });

    test('AddTrackStep keeps program before scope', () {
      expect(AddTrackStep.values, [
        AddTrackStep.curriculum,
        AddTrackStep.program,
        AddTrackStep.scope,
        AddTrackStep.studyDays,
        AddTrackStep.chazaraSetup,
        AddTrackStep.goal,
        AddTrackStep.trackName,
        AddTrackStep.bulkMark,
      ]);
    });
  });

  group('Story 18.6 -- Child Mode Onboarding & Post-Setup Rewards', () {
    test('AddTrackResult has no rewards fields', () {
      const result = AddTrackResult(
        curriculumId: CurriculumId.mishnayos,
        label: 'Test Track',
        studyDays: {1: 'study'},
      );
      expect(result.curriculumId, CurriculumId.mishnayos);
      expect(result.label, 'Test Track');
    });

    test('track setup stores one Firestore track by CurriculumId', () async {
      await seedTrack(
        firestore,
        uid: _uid,
        profileId: _profileId,
        curriculumId: CurriculumId.mishnayos,
      );
      final repo = FirestoreCurriculumTrackRepository(
        firestore: firestore,
        uid: _uid,
        profileId: _profileId,
      );
      final track = await repo.getTrack(CurriculumId.mishnayos);
      expect(track?.curriculumId, CurriculumId.mishnayos);
      expect(await repo.getTrack(CurriculumId.bavli), isNull);
    });

    test(
      'default reward ladder is applied without point-config seeding',
      () async {
        final repo = FirestorePointConfigRepository(
          firestore: firestore,
          uid: _uid,
          profileId: _profileId,
        );
        expect(
          await repo.getConfigsForCurriculum(CurriculumId.mishnayos),
          isEmpty,
        );
        expect(defaultPointsForStage(1), 10);
        expect(defaultPointsForStage(2), 5);
        expect(defaultPointsForStage(3), 3);
      },
    );

    test('childAwareText keeps adult and child handoff copy distinct', () {
      const adultText = "You're all set!";
      const childTemplate = "{name}'s learning is all set up!";
      expect(childAwareText(adultText, childTemplate, 'Sarah'), adultText);
      expect(
        childAwareText(adultText, childTemplate, 'Sarah', isChildMode: true),
        "Sarah's learning is all set up!",
      );
      expect(
        childAwareText(adultText, childTemplate, null, isChildMode: true),
        adultText,
      );
    });
  });

  group('Story 18.4 -- Hebrew Terms for Chazara & Curriculum Names', () {
    test('Firestore stage defaults use Hebrew names', () async {
      await seedStageDefinitions(
        firestore,
        uid: _uid,
        profileId: _profileId,
        curriculumId: CurriculumId.mishnayos,
      );
      final repo = FirestoreStageDefinitionRepository(
        firestore: firestore,
        uid: _uid,
        profileId: _profileId,
      );
      final stages = await repo.getStagesForCurriculum(CurriculumId.mishnayos);
      expect(stages.map((stage) => stage.stageName), [
        'לימוד',
        'חזרה א׳',
        'חזרה ב׳',
      ]);
    });

    test('every CurriculumId has a Hebrew display name', () {
      for (final id in CurriculumId.values) {
        expect(id.displayNameHe, isNotEmpty);
      }
    });

    test('learning program seed labels are Hebrew', () {
      for (final seed in learningProgramSeeds) {
        final stages = (jsonDecode(seed['stages_config']! as String) as List)
            .cast<Map<String, dynamic>>();
        for (final stage in stages) {
          final label = stage['label'] as String;
          expect(label, isNot('Learn'));
          expect(label, isNot(matches(RegExp(r'^Chazara \d+$'))));
          expect(label, isNot('Next-Day Review'));
          expect(label, isNot('Weekly Review'));
          expect(label, isNot('Rolling Back-20'));
        }
      }
    });

    test('HebrewTerms helpers preserve the stage-name mapping', () {
      expect(HebrewTerms.getDefaultStageName(0), 'לימוד');
      expect(HebrewTerms.getDefaultStageName(1), 'חזרה א׳');
      expect(HebrewTerms.getDefaultStageName(2), 'חזרה ב׳');
      expect(HebrewTerms.toHebrew('Learn'), 'לימוד');
      expect(HebrewTerms.toHebrew('Chazara 1'), 'חזרה א׳');
      expect(HebrewTerms.toHebrew('My Custom'), isNull);
    });
  });
}
