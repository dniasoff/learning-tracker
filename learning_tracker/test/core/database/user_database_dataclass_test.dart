/// Tests that exercise DataClass serialization methods (toJson, fromJson,
/// copyWith, copyWithCompanion, toString, ==, hashCode, toColumns,
/// toCompanion) for the key tables in user_database.g.dart.
///
/// Each round-trip test covers ~15-20 lines of generated code per DataClass.
library;

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/daos/profile_dao.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';

import '../../helpers/drift_memory.dart';

void main() {
  late UserDatabase db;

  setUp(() {
    db = inMemoryDb();
  });

  tearDown(() async {
    await db.close();
  });

  // ─── Helpers ─────────────────────────────────────────────────────────────

  final now = DateTime.utc(2026, 1, 15, 10);

  Future<int> insertAccount(UserDatabase db, {String email = 'a@test.local'}) =>
      db
          .into(db.accounts)
          .insert(
            AccountsCompanion.insert(
              email: email,
              tier: 'localBorn',
              displayName: 'Test User',
              userMode: 'adult',
              createdAt: now,
              updatedAt: now,
            ),
          );

  Future<int> insertProfile(
    UserDatabase db,
    int accountId, {
    String displayName = 'Profile',
    String mode = 'adult',
  }) => db
      .into(db.learnerProfiles)
      .insert(
        ProfilesCompanion.insert(
          accountId: accountId,
          displayName: displayName,
          mode: mode,
          createdAt: now,
          updatedAt: now,
        ),
      );

  Future<int> insertTrack(
    UserDatabase db,
    int profileId, {
    String curriculumId = 'bavli',
  }) => db
      .into(db.curriculumTracks)
      .insert(
        CurriculumTracksCompanion.insert(
          profileId: profileId,
          curriculumId: curriculumId,
          trackType: 'personal',
          activatedAt: now,
        ),
      );

  // ─── Account DataClass ───────────────────────────────────────────────────

  group('Account DataClass', () {
    Future<Account> getAccount(int id) async {
      final rows = await (db.select(
        db.accounts,
      )..where((t) => t.id.equals(id))).get();
      return rows.first;
    }

    test('toJson / fromJson round-trip', () async {
      final id = await insertAccount(db, email: 'json@test.local');
      final account = await getAccount(id);

      final json = account.toJson();
      expect(json['email'], 'json@test.local');
      expect(json['tier'], 'localBorn');

      final restored = Account.fromJson(json);
      expect(restored.email, account.email);
      expect(restored.tier, account.tier);
    });

    test('copyWith preserves unchanged fields', () async {
      final id = await insertAccount(db, email: 'copy@test.local');
      final account = await getAccount(id);

      final copy = account.copyWith(displayName: 'Updated Name');
      expect(copy.email, account.email);
      expect(copy.displayName, 'Updated Name');
      expect(copy.tier, account.tier);
    });

    test('toCompanion and copyWithCompanion', () async {
      final id = await insertAccount(db, email: 'comp@test.local');
      final account = await getAccount(id);

      final companion = account.toCompanion(true);
      expect(companion.email.value, 'comp@test.local');

      final copy = account.copyWithCompanion(
        const AccountsCompanion(displayName: Value('Companion Copy')),
      );
      expect(copy.displayName, 'Companion Copy');
      expect(copy.email, account.email);
    });

    test('equality, hashCode, toString', () async {
      final id = await insertAccount(db, email: 'eq@test.local');
      final a1 = await getAccount(id);
      final a2 = await getAccount(id);
      expect(a1, equals(a2));
      expect(a1.hashCode, equals(a2.hashCode));
      expect(a1.toString(), contains('eq@test.local'));
    });

    test('toColumns covers nullable fields', () async {
      await db
          .into(db.accounts)
          .insert(
            AccountsCompanion.insert(
              email: 'nullable@test.local',
              tier: 'cloudBorn',
              displayName: 'Cloud User',
              userMode: 'adult',
              createdAt: now,
              updatedAt: now,
              firebaseUid: const Value('fb-uid-test'),
            ),
          );
      final account = await (db.select(
        db.accounts,
      )..where((t) => t.email.equals('nullable@test.local'))).getSingle();
      final cols = account.toColumns(false);
      expect(cols.containsKey('firebase_uid'), isTrue);

      final noFb = account.copyWith(firebaseUid: const Value(null));
      final colsAbsent = noFb.toColumns(true);
      expect(colsAbsent.containsKey('firebase_uid'), isFalse);
    });

    test('AccountsCompanion.copyWith', () {
      const original = AccountsCompanion(
        email: Value('orig@test.local'),
        tier: Value('localBorn'),
      );
      final copy = original.copyWith(displayName: const Value('New Name'));
      expect(copy.email.value, 'orig@test.local');
      expect(copy.displayName.value, 'New Name');
    });
  });

  // ─── LearnerProfile DataClass ────────────────────────────────────────────

  group('LearnerProfile DataClass', () {
    Future<LearnerProfile> getProfile(int id) async {
      final rows = await (db.select(
        db.learnerProfiles,
      )..where((t) => t.id.equals(id))).get();
      return rows.first;
    }

    test('toJson / fromJson round-trip', () async {
      final accId = await insertAccount(db, email: 'lp@test.local');
      final profileId = await insertProfile(
        db,
        accId,
        displayName: 'JSON Profile',
      );
      final profile = await getProfile(profileId);

      final json = profile.toJson();
      expect(json['displayName'], 'JSON Profile');
      expect(json['mode'], 'adult');

      final restored = LearnerProfile.fromJson(json);
      expect(restored.displayName, profile.displayName);
    });

    test('copyWith', () async {
      final accId = await insertAccount(db, email: 'lp2@test.local');
      final profileId = await insertProfile(
        db,
        accId,
        displayName: 'Copy Profile',
      );
      final profile = await getProfile(profileId);

      final copy = profile.copyWith(displayName: 'Modified');
      expect(copy.accountId, profile.accountId);
      expect(copy.displayName, 'Modified');
    });

    test('toCompanion and copyWithCompanion', () async {
      final accId = await insertAccount(db, email: 'lp3@test.local');
      final profileId = await insertProfile(db, accId);
      final profile = await getProfile(profileId);

      final companion = profile.toCompanion(true);
      expect(companion.accountId.value, accId);

      final copy = profile.copyWithCompanion(
        const ProfilesCompanion(displayName: Value('From Companion')),
      );
      expect(copy.displayName, 'From Companion');
    });

    test('equality, hashCode, toString', () async {
      final accId = await insertAccount(db, email: 'lp4@test.local');
      final profileId = await insertProfile(
        db,
        accId,
        displayName: 'EQ Profile',
      );
      final p1 = await getProfile(profileId);
      final p2 = await getProfile(profileId);
      expect(p1, equals(p2));
      expect(p1.hashCode, equals(p2.hashCode));
      expect(p1.toString(), contains('EQ Profile'));
    });

    test('ProfilesCompanion.copyWith', () {
      final original = ProfilesCompanion(
        displayName: const Value('Original'),
        mode: const Value('adult'),
        createdAt: Value(now),
        updatedAt: Value(now),
      );
      final copy = original.copyWith(mode: const Value('child'));
      expect(copy.displayName.value, 'Original');
      expect(copy.mode.value, 'child');
    });
  });

  // ─── CurriculumTrack DataClass ───────────────────────────────────────────

  group('CurriculumTrack DataClass', () {
    Future<CurriculumTrack> getTrack(int id) async {
      final rows = await (db.select(
        db.curriculumTracks,
      )..where((t) => t.id.equals(id))).get();
      return rows.first;
    }

    test('toJson / fromJson round-trip', () async {
      final accId = await insertAccount(db, email: 'ct@test.local');
      final profileId = await insertProfile(db, accId);
      final trackId = await insertTrack(db, profileId, curriculumId: 'mishnah');
      final track = await getTrack(trackId);

      final json = track.toJson();
      expect(json['curriculumId'], 'mishnah');
      expect(json['trackType'], 'personal');

      final restored = CurriculumTrack.fromJson(json);
      expect(restored.curriculumId, track.curriculumId);
    });

    test('copyWith', () async {
      final accId = await insertAccount(db, email: 'ct2@test.local');
      final profileId = await insertProfile(db, accId);
      final trackId = await insertTrack(db, profileId);
      final track = await getTrack(trackId);

      final copy = track.copyWith(isActive: false);
      expect(copy.curriculumId, track.curriculumId);
      expect(copy.isActive, isFalse);
    });

    test('toCompanion and copyWithCompanion', () async {
      final accId = await insertAccount(db, email: 'ct3@test.local');
      final profileId = await insertProfile(db, accId);
      final trackId = await insertTrack(db, profileId);
      final track = await getTrack(trackId);

      final companion = track.toCompanion(true);
      expect(companion.profileId.value, profileId);

      final copy = track.copyWithCompanion(
        const CurriculumTracksCompanion(isActive: Value(false)),
      );
      expect(copy.isActive, isFalse);
    });

    test('equality, hashCode, toString (with nullable fields)', () async {
      final accId = await insertAccount(db, email: 'ct4@test.local');
      final profileId = await insertProfile(db, accId);
      final trackId = await insertTrack(db, profileId);
      final t1 = await getTrack(trackId);
      final t2 = await getTrack(trackId);
      expect(t1, equals(t2));
      expect(t1.hashCode, equals(t2.hashCode));
      expect(t1.toString(), contains('bavli'));
    });

    test('toColumns with nullable deactivatedAt', () async {
      final accId = await insertAccount(db, email: 'ct5@test.local');
      final profileId = await insertProfile(db, accId);
      final trackId = await insertTrack(db, profileId);
      final track = await getTrack(trackId);

      // deactivatedAt is null — test nullToAbsent path
      final cols = track.toColumns(true);
      expect(cols.containsKey('deactivated_at'), isFalse);

      final colsAll = track.toColumns(false);
      expect(colsAll.containsKey('deactivated_at'), isTrue);
    });

    test('CurriculumTracksCompanion.copyWith', () {
      const original = CurriculumTracksCompanion(
        curriculumId: Value('bavli'),
        trackType: Value('personal'),
      );
      final copy = original.copyWith(isActive: const Value(false));
      expect(copy.curriculumId.value, 'bavli');
      expect(copy.isActive.value, isFalse);
    });
  });

  // ─── DailyPlan DataClass ─────────────────────────────────────────────────

  group('DailyPlan DataClass', () {
    Future<int> insertStageDef(UserDatabase db, int profileId, int trackId) =>
        db
            .into(db.stageDefinitions)
            .insert(
              StageDefinitionsCompanion.insert(
                profileId: profileId,
                trackId: trackId,
                curriculumId: 'bavli',
                stageName: 'limud',
                stageOrder: 1,
                delayDays: 0,
              ),
            );

    Future<int> insertDailyPlan(
      UserDatabase db, {
      required int profileId,
      required int trackId,
      required int stageDefId,
      String ref = 'Berakhot 2a',
      String curriculumId = 'bavli',
    }) => db
        .into(db.dailyPlans)
        .insert(
          DailyPlansCompanion.insert(
            profileId: profileId,
            curriculumId: curriculumId,
            planDate: DateTime.utc(2026, 1, 15),
            sefariaRef: ref,
            stageOrder: 1,
            stageDefinitionId: stageDefId,
            trackId: trackId,
            priority: 'newLearning',
            createdAt: now,
          ),
        );

    Future<DailyPlan> getPlan(int id) async {
      final rows = await (db.select(
        db.dailyPlans,
      )..where((t) => t.id.equals(id))).get();
      return rows.first;
    }

    test('toJson / fromJson round-trip', () async {
      final accId = await insertAccount(db, email: 'dp@test.local');
      final profileId = await insertProfile(db, accId);
      final trackId = await insertTrack(db, profileId);
      final stageDefId = await insertStageDef(db, profileId, trackId);
      final planId = await insertDailyPlan(
        db,
        profileId: profileId,
        trackId: trackId,
        stageDefId: stageDefId,
        ref: 'Berakhot 5a',
      );
      final plan = await getPlan(planId);

      final json = plan.toJson();
      expect(json['sefariaRef'], 'Berakhot 5a');
      expect(json['priority'], 'newLearning');

      final restored = DailyPlan.fromJson(json);
      expect(restored.sefariaRef, plan.sefariaRef);
    });

    test('copyWith and toString', () async {
      final accId = await insertAccount(db, email: 'dp2@test.local');
      final profileId = await insertProfile(db, accId);
      final trackId = await insertTrack(db, profileId);
      final stageDefId = await insertStageDef(db, profileId, trackId);
      final planId = await insertDailyPlan(
        db,
        profileId: profileId,
        trackId: trackId,
        stageDefId: stageDefId,
      );
      final plan = await getPlan(planId);

      final copy = plan.copyWith(priority: 'overdueChazara');
      expect(copy.sefariaRef, plan.sefariaRef);
      expect(copy.priority, 'overdueChazara');
      expect(plan.toString(), contains('Berakhot 2a'));
    });

    test('DailyPlansCompanion.copyWith', () {
      const original = DailyPlansCompanion(
        sefariaRef: Value('Berakhot 2a'),
        priority: Value('newLearning'),
      );
      final copy = original.copyWith(priority: const Value('chazara'));
      expect(copy.sefariaRef.value, 'Berakhot 2a');
      expect(copy.priority.value, 'chazara');
    });
  });

  // ─── Goal DataClass ──────────────────────────────────────────────────────

  group('Goal DataClass', () {
    Future<Goal> getGoal(int id) async {
      final rows = await (db.select(
        db.goals,
      )..where((t) => t.id.equals(id))).get();
      return rows.first;
    }

    test('toJson / fromJson round-trip with nullable fields', () async {
      final accId = await insertAccount(db, email: 'goal@test.local');
      final profileId = await insertProfile(db, accId);
      final trackId = await insertTrack(db, profileId);

      final goalId = await db
          .into(db.goals)
          .insert(
            GoalsCompanion.insert(
              profileId: profileId,
              curriculumId: 'bavli',
              trackId: trackId,
              targetPercent: const Value(80.0),
              targetDate: Value(DateTime.utc(2026, 12, 31)),
              description: const Value('Complete Shas'),
              dateType: const Value('gregorian'),
              goalType: const Value('deadline'),
              createdAt: now,
              updatedAt: now,
            ),
          );
      final goal = await getGoal(goalId);

      final json = goal.toJson();
      expect(json['curriculumId'], 'bavli');
      expect(json['goalType'], 'deadline');
      expect(json['description'], 'Complete Shas');

      final restored = Goal.fromJson(json);
      expect(restored.curriculumId, goal.curriculumId);
      expect(restored.goalType, goal.goalType);
    });

    test('copyWith preserves nullable fields', () async {
      final accId = await insertAccount(db, email: 'goal2@test.local');
      final profileId = await insertProfile(db, accId);
      final trackId = await insertTrack(db, profileId);

      final goalId = await db
          .into(db.goals)
          .insert(
            GoalsCompanion.insert(
              profileId: profileId,
              curriculumId: 'bavli',
              trackId: trackId,
              paceValue: const Value(5),
              pacePeriod: const Value('week'),
              paceGranularity: const Value('daf'),
              createdAt: now,
              updatedAt: now,
            ),
          );
      final goal = await getGoal(goalId);

      final copy = goal.copyWith(description: 'Modified');
      expect(copy.description, 'Modified');
      expect(copy.paceValue, goal.paceValue);
      expect(copy.pacePeriod, goal.pacePeriod);
    });

    test(
      'toCompanion, copyWithCompanion, equality, hashCode, toString',
      () async {
        final accId = await insertAccount(db, email: 'goal3@test.local');
        final profileId = await insertProfile(db, accId);
        final trackId = await insertTrack(db, profileId);

        final goalId = await db
            .into(db.goals)
            .insert(
              GoalsCompanion.insert(
                profileId: profileId,
                curriculumId: 'mishnah',
                trackId: trackId,
                createdAt: now,
                updatedAt: now,
              ),
            );
        final g1 = await getGoal(goalId);
        final g2 = await getGoal(goalId);

        expect(g1, equals(g2));
        expect(g1.hashCode, equals(g2.hashCode));
        expect(g1.toString(), contains('mishnah'));

        final companion = g1.toCompanion(true);
        expect(companion.profileId.value, profileId);

        final copy = g1.copyWithCompanion(
          const GoalsCompanion(description: Value('From Companion')),
        );
        expect(copy.description, 'From Companion');
      },
    );

    test('Goal.toColumns covers nullable fields', () async {
      final accId = await insertAccount(db, email: 'goal4@test.local');
      final profileId = await insertProfile(db, accId);
      final trackId = await insertTrack(db, profileId);

      final goalId = await db
          .into(db.goals)
          .insert(
            GoalsCompanion.insert(
              profileId: profileId,
              curriculumId: 'bavli',
              trackId: trackId,
              targetDate: Value(DateTime.utc(2026, 6, 1)),
              createdAt: now,
              updatedAt: now,
            ),
          );
      final goal = await getGoal(goalId);

      // With target date set
      final cols = goal.toColumns(true);
      expect(cols.containsKey('target_date'), isTrue);

      // No target date
      final noDate = goal.copyWith(targetDate: const Value(null));
      final colsAbsent = noDate.toColumns(true);
      expect(colsAbsent.containsKey('target_date'), isFalse);
    });

    test('GoalsCompanion.copyWith', () {
      const original = GoalsCompanion(
        curriculumId: Value('bavli'),
        goalType: Value('deadline'),
      );
      final copy = original.copyWith(goalType: const Value('pace'));
      expect(copy.curriculumId.value, 'bavli');
      expect(copy.goalType.value, 'pace');
    });
  });

  // ─── LearningLedger DataClass ────────────────────────────────────────────

  group('LearningLedgerData DataClass', () {
    Future<LearningLedgerData> getLedger(int id) async {
      final rows = await (db.select(
        db.learningLedger,
      )..where((t) => t.id.equals(id))).get();
      return rows.first;
    }

    test('toJson / fromJson round-trip', () async {
      final accId = await insertAccount(db, email: 'll@test.local');
      final profileId = await insertProfile(db, accId);
      final trackId = await insertTrack(db, profileId);

      final ledgerId = await db
          .into(db.learningLedger)
          .insert(
            LearningLedgerCompanion.insert(
              profileId: profileId,
              curriculumId: 'bavli',
              entryScope: 'masechta',
              unitIdentifier: 'Berakhot',
              unitDisplayNameHe: 'ברכות',
              unitDisplayNameEn: 'Berakhot',
              trackType: 'personal',
              trackId: Value(trackId),
              completedAt: now,
              completionNumber: 1,
              markedBy: profileId,
            ),
          );
      final ledger = await getLedger(ledgerId);

      final json = ledger.toJson();
      expect(json['curriculumId'], 'bavli');
      expect(json['unitIdentifier'], 'Berakhot');

      final restored = LearningLedgerData.fromJson(json);
      expect(restored.curriculumId, ledger.curriculumId);
    });

    test('copyWith, toString, equality', () async {
      final accId = await insertAccount(db, email: 'll2@test.local');
      final profileId = await insertProfile(db, accId);

      final ledgerId = await db
          .into(db.learningLedger)
          .insert(
            LearningLedgerCompanion.insert(
              profileId: profileId,
              curriculumId: 'mishnah',
              entryScope: 'seder',
              unitIdentifier: 'Zeraim',
              unitDisplayNameHe: 'זרעים',
              unitDisplayNameEn: 'Zeraim',
              trackType: 'personal',
              completedAt: now,
              completionNumber: 1,
              markedBy: profileId,
            ),
          );
      final l1 = await getLedger(ledgerId);
      final l2 = await getLedger(ledgerId);

      expect(l1, equals(l2));
      expect(l1.hashCode, equals(l2.hashCode));
      expect(l1.toString(), contains('Zeraim'));

      final copy = l1.copyWith(completionNumber: 2);
      expect(copy.unitIdentifier, l1.unitIdentifier);
      expect(copy.completionNumber, 2);
    });

    test('LearningLedgerCompanion.copyWith', () {
      const original = LearningLedgerCompanion(
        curriculumId: Value('bavli'),
        completionNumber: Value(1),
      );
      final copy = original.copyWith(completionNumber: const Value(2));
      expect(copy.curriculumId.value, 'bavli');
      expect(copy.completionNumber.value, 2);
    });
  });

  // ─── CurriculumScope DataClass ───────────────────────────────────────────

  group('CurriculumScope DataClass', () {
    Future<CurriculumScope> getScope(int id) async {
      final rows = await (db.select(
        db.curriculumScopes,
      )..where((t) => t.id.equals(id))).get();
      return rows.first;
    }

    test('toJson / fromJson round-trip', () async {
      final accId = await insertAccount(db, email: 'cs@test.local');
      final profileId = await insertProfile(db, accId);
      final trackId = await insertTrack(db, profileId);

      final scopeId = await db
          .into(db.curriculumScopes)
          .insert(
            CurriculumScopesCompanion.insert(
              profileId: profileId,
              curriculumId: 'bavli',
              trackId: trackId,
              scopeLevel: 1,
              scopeValue: 'Moed',
              createdAt: now,
            ),
          );
      final scope = await getScope(scopeId);

      final json = scope.toJson();
      expect(json['scopeValue'], 'Moed');

      final restored = CurriculumScope.fromJson(json);
      expect(restored.scopeValue, scope.scopeValue);
    });

    test('copyWith, equality, toString', () async {
      final accId = await insertAccount(db, email: 'cs2@test.local');
      final profileId = await insertProfile(db, accId);
      final trackId = await insertTrack(db, profileId);

      final scopeId = await db
          .into(db.curriculumScopes)
          .insert(
            CurriculumScopesCompanion.insert(
              profileId: profileId,
              curriculumId: 'bavli',
              trackId: trackId,
              scopeLevel: 2,
              scopeValue: 'Berakhot',
              createdAt: now,
            ),
          );
      final s1 = await getScope(scopeId);
      final s2 = await getScope(scopeId);

      expect(s1, equals(s2));
      expect(s1.hashCode, equals(s2.hashCode));
      expect(s1.toString(), contains('Berakhot'));

      final copy = s1.copyWith(scopeValue: 'Shabbat');
      expect(copy.scopeLevel, s1.scopeLevel);
      expect(copy.scopeValue, 'Shabbat');
    });

    test('CurriculumScopesCompanion.copyWith', () {
      const original = CurriculumScopesCompanion(
        scopeValue: Value('Moed'),
        scopeLevel: Value(1),
      );
      final copy = original.copyWith(scopeLevel: const Value(2));
      expect(copy.scopeValue.value, 'Moed');
      expect(copy.scopeLevel.value, 2);
    });
  });

  // ─── ProfileProgram DataClass ────────────────────────────────────────────

  group('ProfileProgram DataClass', () {
    Future<ProfileProgram?> getProfileProgram(int profileId) => (db.select(
      db.profilePrograms,
    )..where((t) => t.profileId.equals(profileId))).getSingleOrNull();

    test('toJson / fromJson, copyWith, equality', () async {
      final accId = await insertAccount(db, email: 'pp@test.local');
      final profileId = await insertProfile(db, accId);

      await db
          .into(db.profilePrograms)
          .insert(
            ProfileProgramsCompanion.insert(
              profileId: profileId,
              curriculumType: 'bavli',
              programId: 1,
              trackingStartDate: Value(DateTime.utc(2026, 1, 1)),
              trackingStartRef: const Value('Berakhot 2a'),
            ),
          );
      final pp = await getProfileProgram(profileId);
      expect(pp, isNotNull);

      final json = pp!.toJson();
      expect(json['programId'], 1);
      final restored = ProfileProgram.fromJson(json);
      expect(restored.programId, pp.programId);

      final p2 = await getProfileProgram(profileId);
      expect(pp, equals(p2));
      expect(pp.hashCode, equals(p2.hashCode));
      expect(pp.toString(), contains('bavli'));

      final copy = pp.copyWith(programId: 2);
      expect(copy.profileId, pp.profileId);
      expect(copy.programId, 2);
    });

    test('ProfileProgramsCompanion.copyWith', () {
      const original = ProfileProgramsCompanion(
        programId: Value(1),
        curriculumType: Value('bavli'),
      );
      final copy = original.copyWith(programId: const Value(2));
      expect(copy.curriculumType.value, 'bavli');
      expect(copy.programId.value, 2);
    });
  });

  // ─── Managers API (covers $$*TableManager classes) ───────────────────────

  group('UserDatabase managers', () {
    test('managers.accounts.filter works', () async {
      await insertAccount(db, email: 'mgr1@test.local');
      await insertAccount(db, email: 'mgr2@test.local');

      final rows = await db.managers.accounts
          .filter((f) => f.email('mgr1@test.local'))
          .get();
      expect(rows, hasLength(1));
      expect(rows.first.email, 'mgr1@test.local');
    });

    test('managers.learnerProfiles.filter works', () async {
      final accId = await insertAccount(db, email: 'mgr3@test.local');
      await insertProfile(db, accId, displayName: 'Manager Profile');

      final rows = await db.managers.learnerProfiles
          .filter((f) => f.accountId(accId))
          .get();
      expect(rows, hasLength(1));
      expect(rows.first.displayName, 'Manager Profile');
    });

    test('managers.curriculumTracks.orderBy works', () async {
      final accId = await insertAccount(db, email: 'mgr4@test.local');
      final profileId = await insertProfile(db, accId);
      await insertTrack(db, profileId, curriculumId: 'bavli');
      await insertTrack(db, profileId, curriculumId: 'mishnah');

      final rows = await db.managers.curriculumTracks
          .filter((f) => f.profileId(profileId))
          .orderBy((o) => o.curriculumId.asc())
          .get();
      expect(rows, hasLength(2));
      expect(rows.first.curriculumId, 'bavli');
    });

    test('managers.goals.filter works', () async {
      final accId = await insertAccount(db, email: 'mgr5@test.local');
      final profileId = await insertProfile(db, accId);
      final trackId = await insertTrack(db, profileId);
      await db
          .into(db.goals)
          .insert(
            GoalsCompanion.insert(
              profileId: profileId,
              curriculumId: 'bavli',
              trackId: trackId,
              createdAt: now,
              updatedAt: now,
            ),
          );

      final rows = await db.managers.goals
          .filter((f) => f.profileId.id(profileId))
          .get();
      expect(rows, hasLength(1));
    });
  });
}
