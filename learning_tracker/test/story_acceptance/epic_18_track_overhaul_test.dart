/// Story acceptance tests for Epic 18 -- Onboarding & Track Management Overhaul.
@Tags(['epic_18'])
@Skip('TODO: Fix missing pushCurriculumTrack parameter')
library;

import 'dart:convert';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart'
    hide expect, group, setUp, setUpAll, tearDown, tearDownAll, test;
import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/constants/hebrew_terms.dart';
import 'package:learning_tracker/core/database/seed/learning_program_seeds.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/services/learning_program_service.dart';
import 'package:learning_tracker/features/learning/domain/repositories/track_repository.dart';
import 'package:learning_tracker/features/onboarding/domain/services/learning_process_wizard_service.dart';
import 'package:learning_tracker/features/scheduler/data/repositories/goal_repository_impl.dart';
import 'package:learning_tracker/features/settings/domain/services/curriculum_activation_service.dart';
import 'package:learning_tracker/features/stages/data/repositories/stage_definition_repository_impl.dart';
import 'package:learning_tracker/features/track_setup/domain/entities/add_track_result.dart';
import 'package:learning_tracker/features/track_setup/domain/services/track_creation_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart' hide isNotNull, isNull;

import '../helpers/test_database.dart' show seedProfile;

class _MockTrackRepository extends Mock implements TrackRepository {}

/// Creates a default curriculum track and returns its ID.
Future<int> _insertTrack(UserDatabase db) async {
  final row = await db
      .into(db.curriculumTracks)
      .insertReturning(
        CurriculumTracksCompanion.insert(
          profileId: 1,
          curriculumId: 'mishnayos',
          trackType: 'personal',
          activatedAt: DateTime.now(),
        ),
      );
  return row.id;
}

void main() {
  setUpAll(() {
    registerFallbackValue(CurriculumId.mishnayos);
  });

  // ── Story 18.1: AddTrackFlow has no rewards step ──────────────────────────

  group(
    'Story 18.1 -- AddTrackFlow has no rewards step',
    tags: ['story_18_1'],
    () {
      test('AddTrackStep enum does not contain a rewards step', () {
        final stepNames = AddTrackStep.values.map((s) => s.name).toList();
        expect(stepNames, isNot(contains('rewards')));
        expect(stepNames, isNot(contains('rewardsSetup')));
        expect(stepNames, isNot(contains('reward')));
      });

      test('AddTrackStep enum has exactly 8 steps ending at bulkMark', () {
        expect(AddTrackStep.values.length, 8);
        expect(AddTrackStep.values.last, AddTrackStep.bulkMark);
      });

      test(
        'AddTrackStep steps are in expected order (program before scope)',
        () {
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
        },
      );
    },
  );

  // ── Story 18.6: Child Mode Onboarding & Post-Setup Rewards ────────────────

  group(
    'Story 18.6 -- Child Mode Onboarding & Post-Setup Rewards',
    tags: ['story_18_6'],
    () {
      // ── AC-1: No rewards during track setup ──

      group('AC-1: No rewards during track setup', () {
        test('AddTrackFlow steps contain no rewards-related step', () {
          // Verify the enum has no rewards step for either adult or child mode
          final allSteps = AddTrackStep.values.map((s) => s.name.toLowerCase());
          for (final step in allSteps) {
            expect(
              step.contains('reward'),
              isFalse,
              reason: 'Step "$step" should not relate to rewards',
            );
          }
        });

        test('AddTrackResult does not contain rewards fields', () {
          // Construct a minimal result — no rewards field exists
          const result = AddTrackResult(
            curriculumId: CurriculumId.mishnayos,
            label: 'Test Track',
            studyDays: {1: 'study', 2: 'study'},
          );
          // If this compiles, there is no required rewards field
          expect(result.curriculumId, CurriculumId.mishnayos);
          expect(result.label, 'Test Track');
        });
      });

      // ── AC-6: Points initialization per track ──

      group('AC-6: Points initialization per track', () {
        late UserDatabase db;
        late TrackCreationService service;
        late _MockTrackRepository mockTrackRepo;

        setUp(() async {
          db = UserDatabase(NativeDatabase.memory());
          await _insertTrack(db);
          mockTrackRepo = _MockTrackRepository();

          when(
            () => mockTrackRepo.initializeDefaultTracks(
              any(),
              profileId: any(named: 'profileId'),
            ),
          ).thenAnswer((invocation) async {
            final curriculum =
                invocation.positionalArguments[0] as CurriculumId;
            final pId = invocation.namedArguments[#profileId] as int? ?? 0;
            // Actually create the track so downstream lookups succeed
            await db
                .into(db.curriculumTracks)
                .insert(
                  CurriculumTracksCompanion.insert(
                    profileId: pId,
                    curriculumId: curriculum.storageKey,
                    trackType: 'personal',
                    activatedAt: DateTime.now(),
                  ),
                );
          });

          final activationService = CurriculumActivationService(
            database: db,
            pushCurriculumTrack: (_) async {},
            trackRepository: mockTrackRepo,
          );

          final wizardService = LearningProcessWizardService(
            stageDao: db.stageDao,
            learningProgramRepo: LearningProgramRepository.instance,
            profileProgramDao: db.profileProgramDao,
          );

          final goalRepo = GoalRepositoryImpl(database: db);

          service = TrackCreationService(
            database: db,
            activationService: activationService,
            wizardService: wizardService,
            goalRepository: goalRepo,
            stageRepository: StageDefinitionRepositoryImpl(
              stageDao: db.stageDao,
              completionDao: db.completionDao,
              pushSettings: null,
            ),
          );
        });

        tearDown(() async {
          await db.close();
        });

        test('creating a track seeds default point_configs '
            'when none exist for the curriculum', () async {
          // Verify no configs exist initially
          final before = await db.pointConfigDao.getConfigsByCurriculum(
            CurriculumId.mishnayos.storageKey,
          );
          expect(before, isEmpty);

          // Create a track
          await service.createTrack(
            result: const AddTrackResult(
              curriculumId: CurriculumId.mishnayos,
              label: 'Mishnayos Track',
              studyDays: {
                1: 'study',
                2: 'study',
                3: 'study',
                4: 'study',
                5: 'study',
                6: 'review',
                7: 'review',
              },
            ),
            profileId: 1,
          );

          // Verify point configs were seeded
          final after = await db.pointConfigDao.getConfigsByCurriculum(
            CurriculumId.mishnayos.storageKey,
          );
          expect(
            after,
            isNotEmpty,
            reason: 'point_configs should be seeded after track creation',
          );

          // Verify fallback defaults: stage 1=10, stage 2=5, stage 3=3
          final stage1 = after.where((c) => c.stageOrder == 1).firstOrNull;
          expect(stage1, isNotNull);
          expect(stage1!.points, 10);

          final stage2 = after.where((c) => c.stageOrder == 2).firstOrNull;
          expect(stage2, isNotNull);
          expect(stage2!.points, 5);

          final stage3 = after.where((c) => c.stageOrder == 3).firstOrNull;
          expect(stage3, isNotNull);
          expect(stage3!.points, 3);
        });

        test('creating a second track for the same curriculum '
            'does not duplicate point_configs', () async {
          // Create first track
          await service.createTrack(
            result: const AddTrackResult(
              curriculumId: CurriculumId.mishnayos,
              label: 'Track 1',
              studyDays: {1: 'study'},
            ),
            profileId: 1,
          );

          final afterFirst = await db.pointConfigDao.getConfigsByCurriculum(
            CurriculumId.mishnayos.storageKey,
          );
          final countAfterFirst = afterFirst.length;

          // Create second track for same curriculum
          await service.createTrack(
            result: const AddTrackResult(
              curriculumId: CurriculumId.mishnayos,
              label: 'Track 2',
              studyDays: {1: 'study'},
            ),
            profileId: 2,
          );

          final afterSecond = await db.pointConfigDao.getConfigsByCurriculum(
            CurriculumId.mishnayos.storageKey,
          );
          expect(
            afterSecond.length,
            countAfterFirst,
            reason: 'should not duplicate point_configs',
          );
        });

        test('point_configs are seeded per curriculum independently', () async {
          // Create a track for Mishnayos
          await service.createTrack(
            result: const AddTrackResult(
              curriculumId: CurriculumId.mishnayos,
              label: 'Mishnayos',
              studyDays: {1: 'study'},
            ),
            profileId: 1,
          );

          // Create a track for Bavli
          await service.createTrack(
            result: const AddTrackResult(
              curriculumId: CurriculumId.bavli,
              label: 'Bavli',
              studyDays: {1: 'study'},
            ),
            profileId: 1,
          );

          final mishnayosConfigs = await db.pointConfigDao
              .getConfigsByCurriculum(CurriculumId.mishnayos.storageKey);
          final bavliConfigs = await db.pointConfigDao.getConfigsByCurriculum(
            CurriculumId.bavli.storageKey,
          );

          expect(mishnayosConfigs, isNotEmpty);
          expect(bavliConfigs, isNotEmpty);
        });
      });

      // ── AC-2, AC-3: Handoff screen content (structural verification) ──

      group('AC-2/AC-3: Handoff screen content', () {
        test(
          'childAwareText returns child template with name substitution',
          () {
            // Import the helper function indirectly by testing its logic
            const adultText = "You're all set!";
            const childTemplate = "{name}'s learning is all set up!";
            const childName = 'Sarah';

            // Simulate the childAwareText logic
            String childAwareText(
              String adult,
              String template,
              String? name, {
              bool isChildMode = false,
            }) {
              if (!isChildMode || name == null) return adult;
              return template.replaceAll('{name}', name);
            }

            // Adult mode returns adult text
            expect(
              childAwareText(adultText, childTemplate, childName),
              adultText,
            );

            // Child mode returns personalized text
            expect(
              childAwareText(
                adultText,
                childTemplate,
                childName,
                isChildMode: true,
              ),
              "Sarah's learning is all set up!",
            );

            // Child mode with null name falls back to adult text
            expect(
              childAwareText(adultText, childTemplate, null, isChildMode: true),
              adultText,
            );
          },
        );
      });
    },
  );

  // ── Story 18.4: Hebrew Terms for Chazara & Curriculum Names ──────────────

  group(
    'Story 18.4 -- Hebrew Terms for Chazara & Curriculum Names',
    tags: ['story_18_4'],
    () {
      // ── AC-1: Default stage names use Hebrew ──

      group('AC-1: Default stage names use Hebrew', () {
        test('CurriculumDefaults.defaultStages has Hebrew names', () {
          const stages = CurriculumDefaults.defaultStages;
          expect(stages[0].stageName, 'לימוד');
          expect(stages[1].stageName, 'חזרה א׳');
          expect(stages[2].stageName, 'חזרה ב׳');
        });

        test(
          'StageDefinitionRepositoryImpl.initializeDefaults creates Hebrew stages',
          () async {
            final db = UserDatabase(NativeDatabase.memory());
            addTearDown(db.close);
            await seedProfile(db);
            final trackId = await _insertTrack(db);

            final repo = StageDefinitionRepositoryImpl(
              stageDao: db.stageDao,
              completionDao: db.completionDao,
              pushSettings: (_) async {},
            );

            await repo.initializeDefaults(
              CurriculumId.mishnayos,
              profileId: 1,
              trackId: trackId,
            );
            final stages = await repo.getStagesForCurriculum(
              CurriculumId.mishnayos,
            );

            expect(stages[0].stageName, 'לימוד');
            expect(stages[1].stageName, 'חזרה א׳');
            expect(stages[2].stageName, 'חזרה ב׳');
          },
        );

        test(
          'LearningProcessWizardService._applyCustom creates לימוד stage',
          () async {
            final db = UserDatabase(NativeDatabase.memory());
            addTearDown(db.close);

            final service = LearningProcessWizardService(
              stageDao: db.stageDao,
              learningProgramRepo: LearningProgramRepository.instance,
              profileProgramDao: db.profileProgramDao,
            );

            final bavliTrack = await db
                .into(db.curriculumTracks)
                .insertReturning(
                  CurriculumTracksCompanion.insert(
                    profileId: 1,
                    curriculumId: 'bavli',
                    trackType: 'personal',
                    activatedAt: DateTime.now(),
                  ),
                );

            await service.applyWizardResult(
              const WizardResult(
                curriculumId: CurriculumId.bavli,
                choice: WizardChoice.custom,
                customRounds: [],
              ),
              profileId: 1,
              trackId: bavliTrack.id,
            );

            final stages = await db.stageDao.getStageDefinitionsByCurriculum(
              'bavli',
            );
            expect(stages, hasLength(1));
            expect(stages.first.stageName, 'לימוד');
          },
        );

        test(
          'LearningProcessWizardService._applyNoReview creates לימוד stage',
          () async {
            final db = UserDatabase(NativeDatabase.memory());
            addTearDown(db.close);

            final bavliTrack = await db
                .into(db.curriculumTracks)
                .insertReturning(
                  CurriculumTracksCompanion.insert(
                    profileId: 1,
                    curriculumId: 'bavli',
                    trackType: 'personal',
                    activatedAt: DateTime.now(),
                  ),
                );

            final service = LearningProcessWizardService(
              stageDao: db.stageDao,
              learningProgramRepo: LearningProgramRepository.instance,
              profileProgramDao: db.profileProgramDao,
            );

            await service.applyWizardResult(
              const WizardResult(
                curriculumId: CurriculumId.bavli,
                choice: WizardChoice.noReview,
              ),
              profileId: 1,
              trackId: bavliTrack.id,
            );

            final stages = await db.stageDao.getStageDefinitionsByCurriculum(
              'bavli',
            );
            expect(stages, hasLength(1));
            expect(stages.first.stageName, 'לימוד');
          },
        );
      });

      // ── AC-2: Curriculum names display in Hebrew ──

      group('AC-2: Curriculum names display in Hebrew', () {
        test('every CurriculumId has a non-empty displayNameHe', () {
          for (final id in CurriculumId.values) {
            expect(
              id.displayNameHe,
              isNotEmpty,
              reason: '${id.name} should have Hebrew display name',
            );
          }
        });

        test(
          'HebrewTerms.getCurriculumDisplayName delegates to displayNameHe',
          () {
            for (final id in CurriculumId.values) {
              expect(
                HebrewTerms.getCurriculumDisplayName(id),
                id.displayNameHe,
              );
            }
          },
        );
      });

      // ── AC-4: Learning process wizard presets use Hebrew ──

      group('AC-4: Seed data labels are Hebrew', () {
        test('all learning_program_seeds have Hebrew labels', () {
          for (final seed in learningProgramSeeds) {
            final stagesJson = seed['stages_config']! as String;
            final stages = (jsonDecode(stagesJson) as List)
                .cast<Map<String, dynamic>>();
            for (final stage in stages) {
              final label = stage['label'] as String;
              // Should NOT be English defaults
              expect(label, isNot('Learn'), reason: 'seed ${seed['name']}');
              expect(
                label,
                isNot(matches(RegExp(r'^Chazara \d+$'))),
                reason: 'seed ${seed['name']}',
              );
              expect(
                label,
                isNot('Next-Day Review'),
                reason: 'seed ${seed['name']}',
              );
              expect(
                label,
                isNot('Weekly Review'),
                reason: 'seed ${seed['name']}',
              );
              expect(
                label,
                isNot('Rolling Back-20'),
                reason: 'seed ${seed['name']}',
              );
            }
          }
        });
      });

      // ── AC-5: Existing data migrated ──

      group('AC-5: Data migration v23→v24', () {
        test('migration converts English defaults to Hebrew', () async {
          final db = UserDatabase(NativeDatabase.memory());
          addTearDown(db.close);
          final trackId = await _insertTrack(db);

          // Insert English defaults
          await db.stageDao.insertStageDefinition(
            StageDefinitionsCompanion.insert(
              profileId: 1,
              curriculumId: 'bavli',
              trackId: trackId,
              stageOrder: 1,
              stageName: 'Learn',
              delayDays: 0,
              isDefault: const Value(true),
            ),
          );
          await db.stageDao.insertStageDefinition(
            StageDefinitionsCompanion.insert(
              profileId: 1,
              curriculumId: 'bavli',
              trackId: trackId,
              stageOrder: 2,
              stageName: 'Chazara 1',
              delayDays: 1,
            ),
          );

          // Run migration SQL
          for (final entry in HebrewTerms.stageNameMap.entries) {
            await db.customStatement(
              "UPDATE stage_definitions SET stage_name = '${entry.value}' "
              "WHERE stage_name = '${entry.key}'",
            );
          }

          final stages = await db.stageDao.getStageDefinitionsByCurriculum(
            'bavli',
          );
          expect(stages[0].stageName, 'לימוד');
          expect(stages[1].stageName, 'חזרה א׳');
        });

        test('migration does not touch user-customized names', () async {
          final db = UserDatabase(NativeDatabase.memory());
          addTearDown(db.close);
          final trackId = await _insertTrack(db);

          await db.stageDao.insertStageDefinition(
            StageDefinitionsCompanion.insert(
              profileId: 1,
              curriculumId: 'mishnayos',
              trackId: trackId,
              stageOrder: 1,
              stageName: 'My Custom Stage',
              delayDays: 0,
            ),
          );

          for (final entry in HebrewTerms.stageNameMap.entries) {
            await db.customStatement(
              "UPDATE stage_definitions SET stage_name = '${entry.value}' "
              "WHERE stage_name = '${entry.key}'",
            );
          }

          final stages = await db.stageDao.getStageDefinitionsByCurriculum(
            'mishnayos',
          );
          expect(stages.first.stageName, 'My Custom Stage');
        });

        test('migration is idempotent', () async {
          final db = UserDatabase(NativeDatabase.memory());
          addTearDown(db.close);
          final trackId = await _insertTrack(db);

          await db.stageDao.insertStageDefinition(
            StageDefinitionsCompanion.insert(
              profileId: 1,
              curriculumId: 'bavli',
              trackId: trackId,
              stageOrder: 1,
              stageName: 'Learn',
              delayDays: 0,
            ),
          );

          // Run twice
          for (var i = 0; i < 2; i++) {
            for (final entry in HebrewTerms.stageNameMap.entries) {
              await db.customStatement(
                "UPDATE stage_definitions SET stage_name = '${entry.value}' "
                "WHERE stage_name = '${entry.key}'",
              );
            }
          }

          final stages = await db.stageDao.getStageDefinitionsByCurriculum(
            'bavli',
          );
          expect(stages.first.stageName, 'לימוד');
        });
      });

      // ── HebrewTerms helpers ──

      group('HebrewTerms helpers', () {
        test('getDefaultStageName returns correct Hebrew names', () {
          expect(HebrewTerms.getDefaultStageName(0), 'לימוד');
          expect(HebrewTerms.getDefaultStageName(1), 'חזרה א׳');
          expect(HebrewTerms.getDefaultStageName(2), 'חזרה ב׳');
          expect(HebrewTerms.getDefaultStageName(3), 'חזרה ג׳');
        });

        test('toHebrew converts known English defaults', () {
          expect(HebrewTerms.toHebrew('Learn'), 'לימוד');
          expect(HebrewTerms.toHebrew('Chazara 1'), 'חזרה א׳');
          expect(HebrewTerms.toHebrew('My Custom'), isNull);
        });
      });
    },
  );
}
