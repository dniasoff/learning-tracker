/// DataClass coverage for core user_database.g.dart tables not yet covered.
///
/// Targets Account, LearnerProfile, CurriculumTrack, CurriculumScope,
/// ProfileProgram, DailyPlan, LearningLedgerData, and Goal DataClass methods:
///   • toColumns(nullToAbsent=true/false)
///   • toCompanion(nullToAbsent=true/false)
///   • copyWith / copyWithCompanion
///   • fromJson / toJson
///   • toString / hashCode / ==
///   • validateIntegrity missing-field paths (empty companion inserts)
///
/// No Firebase or Riverpod. Plain Drift in-memory DB.
library;

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';

import '../../helpers/drift_memory.dart';

void main() {
  late UserDatabase db;

  final now = DateTime.utc(2026, 3, 1, 12);

  setUp(() {
    db = inMemoryDb();
  });

  tearDown(() async {
    await db.close();
  });

  // ── helpers ─────────────────────────────────────────────────────────────────

  Future<int> insertAccount({String email = 'a@test.local'}) => db
      .into(db.accounts)
      .insert(
        AccountsCompanion.insert(
          email: email,
          tier: 'localBorn',
          displayName: 'User',
          userMode: 'adult',
          createdAt: now,
          updatedAt: now,
        ),
      );

  Future<int> insertProfile(int accountId) => db
      .into(db.learnerProfiles)
      .insert(
        LearnerProfilesCompanion.insert(
          accountId: accountId,
          displayName: 'Learner',
          mode: 'adult',
          createdAt: now,
          updatedAt: now,
        ),
      );

  Future<int> insertTrack(int profileId) => db
      .into(db.curriculumTracks)
      .insert(
        CurriculumTracksCompanion.insert(
          profileId: profileId,
          curriculumId: 'bavli',
          trackType: 'personal',
          activatedAt: now,
        ),
      );

  // ─── Account DataClass ────────────────────────────────────────────────────

  group('Account DataClass', () {
    Future<Account> getAccount(int id) async {
      return (await (db.select(
        db.accounts,
      )..where((t) => t.id.equals(id))).getSingleOrNull())!;
    }

    test('toColumns with null firebaseUid and nullToAbsent=true', () async {
      final id = await insertAccount(email: 'ac1@test.local');
      final account = await getAccount(id);
      final cols = account.toColumns(true);
      expect(cols.containsKey('id'), isTrue);
      expect(cols.containsKey('email'), isTrue);
      expect(cols.containsKey('tier'), isTrue);
      expect(cols.containsKey('display_name'), isTrue);
      // firebaseUid is null — with nullToAbsent=true, absent
      expect(cols.containsKey('firebase_uid'), isFalse);
      expect(cols.containsKey('password_hash'), isFalse);
    });

    test(
      'toColumns with nullToAbsent=false includes null nullable fields',
      () async {
        final id = await insertAccount(email: 'ac2@test.local');
        final account = await getAccount(id);
        final cols = account.toColumns(false);
        expect(cols.containsKey('firebase_uid'), isTrue);
        expect(cols.containsKey('password_hash'), isTrue);
      },
    );

    test(
      'toCompanion with nullToAbsent=true omits absent nullable fields',
      () async {
        final id = await insertAccount(email: 'ac3@test.local');
        final account = await getAccount(id);
        final comp = account.toCompanion(true);
        expect(comp.email.value, 'ac3@test.local');
        expect(comp.firebaseUid.present, isFalse);
        expect(comp.passwordHash.present, isFalse);
      },
    );

    test(
      'toCompanion with nullToAbsent=false includes nullable fields',
      () async {
        final id = await insertAccount(email: 'ac4@test.local');
        final account = await getAccount(id);
        final comp = account.toCompanion(false);
        expect(comp.firebaseUid.present, isTrue);
        expect(comp.passwordHash.present, isTrue);
      },
    );

    test('copyWith changes fields', () async {
      final id = await insertAccount(email: 'ac5@test.local');
      final account = await getAccount(id);
      final copy = account.copyWith(
        displayName: 'Updated',
        firebaseUid: const Value('fb-ac5'),
      );
      expect(copy.email, 'ac5@test.local');
      expect(copy.displayName, 'Updated');
      expect(copy.firebaseUid, 'fb-ac5');
    });

    test('copyWithCompanion applies partial updates', () async {
      final id = await insertAccount(email: 'ac6@test.local');
      final account = await getAccount(id);
      final copy = account.copyWithCompanion(
        const AccountsCompanion(
          displayName: Value('Companion Updated'),
          passwordHash: Value('hash-xyz'),
        ),
      );
      expect(copy.email, 'ac6@test.local');
      expect(copy.displayName, 'Companion Updated');
      expect(copy.passwordHash, 'hash-xyz');
    });

    test('fromJson / toJson round-trip', () async {
      final id = await insertAccount(email: 'ac7@test.local');
      final account = await getAccount(id);
      final json = account.toJson();
      expect(json['email'], 'ac7@test.local');
      final restored = Account.fromJson(json);
      expect(restored.email, account.email);
      expect(restored, equals(account));
    });

    test('toString contains key fields', () async {
      final id = await insertAccount(email: 'ac8@test.local');
      final account = await getAccount(id);
      final s = account.toString();
      expect(s, contains('Account'));
      expect(s, contains('ac8@test.local'));
    });

    test('hashCode and ==', () async {
      final id = await insertAccount(email: 'ac9@test.local');
      final a1 = await getAccount(id);
      final a2 = await getAccount(id);
      expect(a1, equals(a2));
      expect(a1.hashCode, equals(a2.hashCode));
    });
  });

  // ─── LearnerProfile DataClass ─────────────────────────────────────────────

  group('LearnerProfile DataClass', () {
    Future<LearnerProfile> getProfile(int id) async {
      return (await (db.select(
        db.learnerProfiles,
      )..where((t) => t.id.equals(id))).getSingleOrNull())!;
    }

    test('toColumns covers all fields', () async {
      final accId = await insertAccount(email: 'lp1@test.local');
      final profId = await insertProfile(accId);
      final profile = await getProfile(profId);
      final cols = profile.toColumns(true);
      expect(cols.containsKey('id'), isTrue);
      expect(cols.containsKey('account_id'), isTrue);
      expect(cols.containsKey('display_name'), isTrue);
      expect(cols.containsKey('mode'), isTrue);
      expect(cols.containsKey('avatar_index'), isTrue);
      expect(cols.containsKey('created_at'), isTrue);
      expect(cols.containsKey('updated_at'), isTrue);
    });

    test('toCompanion round-trips', () async {
      final accId = await insertAccount(email: 'lp2@test.local');
      final profId = await insertProfile(accId);
      final profile = await getProfile(profId);
      final comp = profile.toCompanion(false);
      expect(comp.displayName.value, 'Learner');
      expect(comp.mode.value, 'adult');
    });

    test('copyWith changes specific fields', () async {
      final accId = await insertAccount(email: 'lp3@test.local');
      final profId = await insertProfile(accId);
      final profile = await getProfile(profId);
      final copy = profile.copyWith(displayName: 'Updated', mode: 'child');
      expect(copy.accountId, profile.accountId);
      expect(copy.displayName, 'Updated');
      expect(copy.mode, 'child');
    });

    test('copyWithCompanion applies companion fields', () async {
      final accId = await insertAccount(email: 'lp4@test.local');
      final profId = await insertProfile(accId);
      final profile = await getProfile(profId);
      final copy = profile.copyWithCompanion(
        const LearnerProfilesCompanion(
          displayName: Value('New Name'),
          avatarIndex: Value(3),
        ),
      );
      expect(copy.displayName, 'New Name');
      expect(copy.avatarIndex, 3);
    });

    test('fromJson / toJson round-trip', () async {
      final accId = await insertAccount(email: 'lp5@test.local');
      final profId = await insertProfile(accId);
      final profile = await getProfile(profId);
      final json = profile.toJson();
      expect(json['displayName'], 'Learner');
      final restored = LearnerProfile.fromJson(json);
      expect(restored, equals(profile));
    });

    test('toString and hashCode', () async {
      final accId = await insertAccount(email: 'lp6@test.local');
      final profId = await insertProfile(accId);
      final p1 = await getProfile(profId);
      final p2 = await getProfile(profId);
      expect(p1.toString(), contains('LearnerProfile'));
      expect(p1.hashCode, equals(p2.hashCode));
      expect(p1, equals(p2));
    });
  });

  // ─── CurriculumTrack DataClass ────────────────────────────────────────────

  group('CurriculumTrack DataClass', () {
    Future<CurriculumTrack> getTrack(int id) async {
      return (await (db.select(
        db.curriculumTracks,
      )..where((t) => t.id.equals(id))).getSingleOrNull())!;
    }

    test('toColumns with null nullable fields and nullToAbsent=true', () async {
      final accId = await insertAccount(email: 'ct1@test.local');
      final profId = await insertProfile(accId);
      final trackId = await insertTrack(profId);
      final track = await getTrack(trackId);
      final cols = track.toColumns(true);
      expect(cols.containsKey('id'), isTrue);
      expect(cols.containsKey('profile_id'), isTrue);
      expect(cols.containsKey('curriculum_id'), isTrue);
      expect(cols.containsKey('track_type'), isTrue);
      expect(cols.containsKey('is_active'), isTrue);
      expect(cols.containsKey('activated_at'), isTrue);
      // nullable fields are null → absent with nullToAbsent=true
      expect(cols.containsKey('deactivated_at'), isFalse);
      expect(cols.containsKey('pace_reset_date'), isFalse);
      expect(cols.containsKey('deleted_at'), isFalse);
    });

    test(
      'toColumns with nullToAbsent=false includes all nullable fields',
      () async {
        final accId = await insertAccount(email: 'ct2@test.local');
        final profId = await insertProfile(accId);
        final trackId = await insertTrack(profId);
        final track = await getTrack(trackId);
        final cols = track.toColumns(false);
        expect(cols.containsKey('deactivated_at'), isTrue);
        expect(cols.containsKey('pace_reset_date'), isTrue);
        expect(cols.containsKey('deleted_at'), isTrue);
      },
    );

    test(
      'toCompanion with nullToAbsent=true omits null nullable fields',
      () async {
        final accId = await insertAccount(email: 'ct3@test.local');
        final profId = await insertProfile(accId);
        final trackId = await insertTrack(profId);
        final track = await getTrack(trackId);
        final comp = track.toCompanion(true);
        expect(comp.curriculumId.value, 'bavli');
        expect(comp.deactivatedAt.present, isFalse);
        expect(comp.paceResetDate.present, isFalse);
      },
    );

    test('copyWith changes isActive and deactivatedAt', () async {
      final accId = await insertAccount(email: 'ct4@test.local');
      final profId = await insertProfile(accId);
      final trackId = await insertTrack(profId);
      final track = await getTrack(trackId);
      final copy = track.copyWith(isActive: false, deactivatedAt: Value(now));
      expect(copy.isActive, isFalse);
      expect(copy.deactivatedAt, now);
      expect(copy.curriculumId, 'bavli');
    });

    test('copyWithCompanion applies changes', () async {
      final accId = await insertAccount(email: 'ct5@test.local');
      final profId = await insertProfile(accId);
      final trackId = await insertTrack(profId);
      final track = await getTrack(trackId);
      final copy = track.copyWithCompanion(
        CurriculumTracksCompanion(
          deactivatedAt: Value(now),
          paceResetDate: Value(now),
        ),
      );
      expect(copy.deactivatedAt, now);
      expect(copy.paceResetDate, now);
    });

    test('fromJson / toJson round-trip', () async {
      final accId = await insertAccount(email: 'ct6@test.local');
      final profId = await insertProfile(accId);
      final trackId = await insertTrack(profId);
      final track = await getTrack(trackId);
      final json = track.toJson();
      expect(json['curriculumId'], 'bavli');
      final restored = CurriculumTrack.fromJson(json);
      expect(restored, equals(track));
    });

    test('toString and hashCode', () async {
      final accId = await insertAccount(email: 'ct7@test.local');
      final profId = await insertProfile(accId);
      final trackId = await insertTrack(profId);
      final t1 = await getTrack(trackId);
      final t2 = await getTrack(trackId);
      expect(t1.toString(), contains('CurriculumTrack'));
      expect(t1, equals(t2));
      expect(t1.hashCode, equals(t2.hashCode));
    });
  });

  // ─── CurriculumScope DataClass ────────────────────────────────────────────

  group('CurriculumScope DataClass', () {
    Future<CurriculumScope> insertAndGetScope(
      int profileId,
      int trackId,
    ) async {
      final id = await db
          .into(db.curriculumScopes)
          .insert(
            CurriculumScopesCompanion.insert(
              profileId: profileId,
              curriculumId: 'bavli',
              trackId: trackId,
              scopeLevel: 1,
              scopeValue: 'Seder Zeraim',
              createdAt: now,
            ),
          );
      return (await (db.select(
        db.curriculumScopes,
      )..where((t) => t.id.equals(id))).getSingleOrNull())!;
    }

    test('toColumns covers all fields', () async {
      final accId = await insertAccount(email: 'cs1@test.local');
      final profId = await insertProfile(accId);
      final trackId = await insertTrack(profId);
      final scope = await insertAndGetScope(profId, trackId);
      final cols = scope.toColumns(true);
      expect(cols.containsKey('id'), isTrue);
      expect(cols.containsKey('profile_id'), isTrue);
      expect(cols.containsKey('curriculum_id'), isTrue);
      expect(cols.containsKey('track_id'), isTrue);
      expect(cols.containsKey('scope_level'), isTrue);
      expect(cols.containsKey('scope_value'), isTrue);
      expect(cols.containsKey('created_at'), isTrue);
    });

    test('toCompanion round-trips', () async {
      final accId = await insertAccount(email: 'cs2@test.local');
      final profId = await insertProfile(accId);
      final trackId = await insertTrack(profId);
      final scope = await insertAndGetScope(profId, trackId);
      final comp = scope.toCompanion(false);
      expect(comp.scopeValue.value, 'Seder Zeraim');
      expect(comp.scopeLevel.value, 1);
    });

    test('copyWith changes scopeValue', () async {
      final accId = await insertAccount(email: 'cs3@test.local');
      final profId = await insertProfile(accId);
      final trackId = await insertTrack(profId);
      final scope = await insertAndGetScope(profId, trackId);
      final copy = scope.copyWith(scopeValue: 'Seder Moed');
      expect(copy.profileId, profId);
      expect(copy.scopeValue, 'Seder Moed');
    });

    test('copyWithCompanion applies changes', () async {
      final accId = await insertAccount(email: 'cs4@test.local');
      final profId = await insertProfile(accId);
      final trackId = await insertTrack(profId);
      final scope = await insertAndGetScope(profId, trackId);
      final copy = scope.copyWithCompanion(
        const CurriculumScopesCompanion(
          scopeLevel: Value(2),
          scopeValue: Value('Berachos'),
        ),
      );
      expect(copy.scopeLevel, 2);
      expect(copy.scopeValue, 'Berachos');
    });

    test('fromJson / toJson round-trip', () async {
      final accId = await insertAccount(email: 'cs5@test.local');
      final profId = await insertProfile(accId);
      final trackId = await insertTrack(profId);
      final scope = await insertAndGetScope(profId, trackId);
      final json = scope.toJson();
      expect(json['scopeValue'], 'Seder Zeraim');
      final restored = CurriculumScope.fromJson(json);
      expect(restored, equals(scope));
    });

    test('toString and hashCode', () async {
      final accId = await insertAccount(email: 'cs6@test.local');
      final profId = await insertProfile(accId);
      final trackId = await insertTrack(profId);
      final s1 = await insertAndGetScope(profId, trackId);
      final s2 = await (db.select(
        db.curriculumScopes,
      )..where((t) => t.id.equals(s1.id))).getSingleOrNull();
      expect(s1.toString(), contains('CurriculumScope'));
      expect(s1, equals(s2));
      expect(s1.hashCode, equals(s2!.hashCode));
    });
  });

  // ─── ProfileProgram DataClass ─────────────────────────────────────────────

  group('ProfileProgram DataClass', () {
    Future<ProfileProgram> insertAndGetProgram(int profileId) async {
      await db
          .into(db.profilePrograms)
          .insert(
            ProfileProgramsCompanion.insert(
              profileId: profileId,
              curriculumType: 'bavli',
              programId: 1,
              trackingStartDate: Value(now),
              trackingStartRef: const Value('Berakhot 2a'),
            ),
          );
      return (await (db.select(
        db.profilePrograms,
      )..where((t) => t.profileId.equals(profileId))).getSingleOrNull())!;
    }

    test(
      'toColumns with non-null nullable fields and nullToAbsent=true',
      () async {
        final accId = await insertAccount(email: 'pp1@test.local');
        final profId = await insertProfile(accId);
        final prog = await insertAndGetProgram(profId);
        final cols = prog.toColumns(true);
        expect(cols.containsKey('id'), isTrue);
        expect(cols.containsKey('curriculum_type'), isTrue);
        expect(cols.containsKey('program_id'), isTrue);
        // Non-null nullable → present
        expect(cols.containsKey('tracking_start_date'), isTrue);
        expect(cols.containsKey('tracking_start_ref'), isTrue);
      },
    );

    test('toColumns with null nullable fields and nullToAbsent=true', () async {
      final accId = await insertAccount(email: 'pp2@test.local');
      final profId = await insertProfile(accId);
      await db
          .into(db.profilePrograms)
          .insert(
            ProfileProgramsCompanion.insert(
              profileId: profId,
              curriculumType: 'mishnayos',
              programId: 2,
            ),
          );
      final prog =
          (await (db.select(db.profilePrograms)
                ..where((t) => t.curriculumType.equals('mishnayos')))
              .getSingleOrNull())!;
      final cols = prog.toColumns(true);
      expect(cols.containsKey('tracking_start_date'), isFalse);
      expect(cols.containsKey('tracking_start_ref'), isFalse);
    });

    test(
      'toColumns with nullToAbsent=false includes null nullable fields',
      () async {
        final accId = await insertAccount(email: 'pp3@test.local');
        final profId = await insertProfile(accId);
        await db
            .into(db.profilePrograms)
            .insert(
              ProfileProgramsCompanion.insert(
                profileId: profId,
                curriculumType: 'yerushalmi',
                programId: 3,
              ),
            );
        final prog =
            (await (db.select(db.profilePrograms)
                  ..where((t) => t.curriculumType.equals('yerushalmi')))
                .getSingleOrNull())!;
        final cols = prog.toColumns(false);
        expect(cols.containsKey('tracking_start_date'), isTrue);
        expect(cols.containsKey('tracking_start_ref'), isTrue);
      },
    );

    test(
      'toCompanion with nullToAbsent=true omits null nullable fields',
      () async {
        final accId = await insertAccount(email: 'pp4@test.local');
        final profId = await insertProfile(accId);
        final prog = await insertAndGetProgram(profId);
        final comp = prog.toCompanion(true);
        expect(comp.curriculumType.value, 'bavli');
        expect(comp.trackingStartDate.present, isTrue);
      },
    );

    test('copyWith changes programId', () async {
      final accId = await insertAccount(email: 'pp5@test.local');
      final profId = await insertProfile(accId);
      final prog = await insertAndGetProgram(profId);
      final copy = prog.copyWith(programId: 99);
      expect(copy.profileId, profId);
      expect(copy.programId, 99);
    });

    test('copyWithCompanion applies changes', () async {
      final accId = await insertAccount(email: 'pp6@test.local');
      final profId = await insertProfile(accId);
      final prog = await insertAndGetProgram(profId);
      final copy = prog.copyWithCompanion(
        ProfileProgramsCompanion(
          trackingStartDate: Value(now.add(const Duration(days: 1))),
          trackingStartRef: const Value('Berakhot 3a'),
        ),
      );
      expect(copy.trackingStartRef, 'Berakhot 3a');
    });

    test('fromJson / toJson round-trip', () async {
      final accId = await insertAccount(email: 'pp7@test.local');
      final profId = await insertProfile(accId);
      final prog = await insertAndGetProgram(profId);
      final json = prog.toJson();
      expect(json['curriculumType'], 'bavli');
      final restored = ProfileProgram.fromJson(json);
      expect(restored, equals(prog));
    });

    test('toString and hashCode', () async {
      final accId = await insertAccount(email: 'pp8@test.local');
      final profId = await insertProfile(accId);
      final p1 = await insertAndGetProgram(profId);
      final p2 = await (db.select(
        db.profilePrograms,
      )..where((t) => t.id.equals(p1.id))).getSingleOrNull();
      expect(p1.toString(), contains('ProfileProgram'));
      expect(p1, equals(p2));
      expect(p1.hashCode, equals(p2!.hashCode));
    });
  });

  // ─── DailyPlan DataClass ──────────────────────────────────────────────────

  group('DailyPlan DataClass', () {
    Future<int> insertStageDef(int profileId, int trackId) => db
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

    Future<DailyPlan> insertAndGetPlan(
      int profileId,
      int trackId,
      int stageDefId,
    ) async {
      await db
          .into(db.dailyPlans)
          .insert(
            DailyPlansCompanion.insert(
              profileId: profileId,
              curriculumId: 'bavli',
              planDate: now,
              sefariaRef: 'Berakhot 2a',
              stageOrder: 1,
              stageDefinitionId: stageDefId,
              trackId: trackId,
              priority: 'regular',
              createdAt: now,
            ),
          );
      return (await (db.select(
        db.dailyPlans,
      )..where((t) => t.sefariaRef.equals('Berakhot 2a'))).getSingleOrNull())!;
    }

    test('toColumns covers all fields', () async {
      final accId = await insertAccount(email: 'dp1@test.local');
      final profId = await insertProfile(accId);
      final trackId = await insertTrack(profId);
      final stageDefId = await insertStageDef(profId, trackId);
      final plan = await insertAndGetPlan(profId, trackId, stageDefId);
      final cols = plan.toColumns(true);
      expect(cols.containsKey('id'), isTrue);
      expect(cols.containsKey('profile_id'), isTrue);
      expect(cols.containsKey('curriculum_id'), isTrue);
      expect(cols.containsKey('plan_date'), isTrue);
      expect(cols.containsKey('sefaria_ref'), isTrue);
      expect(cols.containsKey('stage_order'), isTrue);
      expect(cols.containsKey('stage_definition_id'), isTrue);
      expect(cols.containsKey('track_id'), isTrue);
      expect(cols.containsKey('track_label'), isTrue);
      expect(cols.containsKey('priority'), isTrue);
      expect(cols.containsKey('is_overdue'), isTrue);
      expect(cols.containsKey('reason'), isTrue);
      expect(cols.containsKey('stage_name'), isTrue);
      expect(cols.containsKey('estimated_effort_minutes'), isTrue);
      expect(cols.containsKey('sort_order'), isTrue);
      expect(cols.containsKey('created_at'), isTrue);
    });

    test('toCompanion round-trips correctly', () async {
      final accId = await insertAccount(email: 'dp2@test.local');
      final profId = await insertProfile(accId);
      final trackId = await insertTrack(profId);
      final stageDefId = await insertStageDef(profId, trackId);
      final plan = await insertAndGetPlan(profId, trackId, stageDefId);
      final comp = plan.toCompanion(false);
      expect(comp.sefariaRef.value, 'Berakhot 2a');
      expect(comp.priority.value, 'regular');
    });

    test('copyWith changes priority', () async {
      final accId = await insertAccount(email: 'dp3@test.local');
      final profId = await insertProfile(accId);
      final trackId = await insertTrack(profId);
      final stageDefId = await insertStageDef(profId, trackId);
      final plan = await insertAndGetPlan(profId, trackId, stageDefId);
      final copy = plan.copyWith(priority: 'overdueChazara', isOverdue: true);
      expect(copy.sefariaRef, 'Berakhot 2a');
      expect(copy.priority, 'overdueChazara');
      expect(copy.isOverdue, isTrue);
    });

    test('copyWithCompanion applies changes', () async {
      final accId = await insertAccount(email: 'dp4@test.local');
      final profId = await insertProfile(accId);
      final trackId = await insertTrack(profId);
      final stageDefId = await insertStageDef(profId, trackId);
      final plan = await insertAndGetPlan(profId, trackId, stageDefId);
      final copy = plan.copyWithCompanion(
        const DailyPlansCompanion(
          stageName: Value('limud-updated'),
          estimatedEffortMinutes: Value(10),
          sortOrder: Value(5),
          trackLabel: Value('Track A'),
          reason: Value('new reason'),
        ),
      );
      expect(copy.stageName, 'limud-updated');
      expect(copy.estimatedEffortMinutes, 10);
      expect(copy.sortOrder, 5);
      expect(copy.trackLabel, 'Track A');
    });

    test('fromJson / toJson round-trip', () async {
      final accId = await insertAccount(email: 'dp5@test.local');
      final profId = await insertProfile(accId);
      final trackId = await insertTrack(profId);
      final stageDefId = await insertStageDef(profId, trackId);
      final plan = await insertAndGetPlan(profId, trackId, stageDefId);
      final json = plan.toJson();
      expect(json['sefariaRef'], 'Berakhot 2a');
      final restored = DailyPlan.fromJson(json);
      expect(restored, equals(plan));
    });

    test('toString and hashCode', () async {
      final accId = await insertAccount(email: 'dp6@test.local');
      final profId = await insertProfile(accId);
      final trackId = await insertTrack(profId);
      final stageDefId = await insertStageDef(profId, trackId);
      final p1 = await insertAndGetPlan(profId, trackId, stageDefId);
      final p2 = await (db.select(
        db.dailyPlans,
      )..where((t) => t.id.equals(p1.id))).getSingleOrNull();
      expect(p1.toString(), contains('DailyPlan'));
      expect(p1, equals(p2));
      expect(p1.hashCode, equals(p2!.hashCode));
    });
  });

  // ─── LearningLedgerData DataClass ─────────────────────────────────────────

  group('LearningLedgerData DataClass', () {
    Future<LearningLedgerData> insertAndGetEntry(int profileId) async {
      await db
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
              completedAt: now,
              completionNumber: 1,
              markedBy: profileId,
            ),
          );
      return (await (db.select(
        db.learningLedger,
      )..where((t) => t.profileId.equals(profileId))).getSingleOrNull())!;
    }

    test('toColumns with null trackId and nullToAbsent=true', () async {
      final accId = await insertAccount(email: 'll1@test.local');
      final profId = await insertProfile(accId);
      final entry = await insertAndGetEntry(profId);
      final cols = entry.toColumns(true);
      expect(cols.containsKey('id'), isTrue);
      expect(cols.containsKey('profile_id'), isTrue);
      expect(cols.containsKey('curriculum_id'), isTrue);
      expect(cols.containsKey('unit_type'), isTrue);
      expect(cols.containsKey('unit_identifier'), isTrue);
      expect(cols.containsKey('track_type'), isTrue);
      expect(cols.containsKey('completed_at'), isTrue);
      expect(cols.containsKey('completion_number'), isTrue);
      expect(cols.containsKey('marked_by'), isTrue);
      // trackId is null → absent with nullToAbsent=true
      expect(cols.containsKey('track_id'), isFalse);
    });

    test('toColumns with nullToAbsent=false includes null trackId', () async {
      final accId = await insertAccount(email: 'll2@test.local');
      final profId = await insertProfile(accId);
      final entry = await insertAndGetEntry(profId);
      final cols = entry.toColumns(false);
      expect(cols.containsKey('track_id'), isTrue);
    });

    test('toCompanion with nullToAbsent=true', () async {
      final accId = await insertAccount(email: 'll3@test.local');
      final profId = await insertProfile(accId);
      final entry = await insertAndGetEntry(profId);
      final comp = entry.toCompanion(true);
      expect(comp.unitIdentifier.value, 'Berakhot');
      expect(comp.trackId.present, isFalse);
    });

    test('toCompanion with nullToAbsent=false includes trackId', () async {
      final accId = await insertAccount(email: 'll4@test.local');
      final profId = await insertProfile(accId);
      final entry = await insertAndGetEntry(profId);
      final comp = entry.toCompanion(false);
      expect(comp.trackId.present, isTrue);
    });

    test('copyWith changes completionNumber', () async {
      final accId = await insertAccount(email: 'll5@test.local');
      final profId = await insertProfile(accId);
      final entry = await insertAndGetEntry(profId);
      final copy = entry.copyWith(completionNumber: 2);
      expect(copy.unitIdentifier, 'Berakhot');
      expect(copy.completionNumber, 2);
    });

    test('copyWithCompanion applies changes', () async {
      final accId = await insertAccount(email: 'll6@test.local');
      final profId = await insertProfile(accId);
      final entry = await insertAndGetEntry(profId);
      final copy = entry.copyWithCompanion(
        const LearningLedgerCompanion(
          unitDisplayNameHe: Value('ברכות עדכון'),
          completionNumber: Value(3),
        ),
      );
      expect(copy.unitDisplayNameHe, 'ברכות עדכון');
      expect(copy.completionNumber, 3);
    });

    test('fromJson / toJson round-trip', () async {
      final accId = await insertAccount(email: 'll7@test.local');
      final profId = await insertProfile(accId);
      final entry = await insertAndGetEntry(profId);
      final json = entry.toJson();
      expect(json['unitIdentifier'], 'Berakhot');
      final restored = LearningLedgerData.fromJson(json);
      expect(restored, equals(entry));
    });

    test('toString and hashCode', () async {
      final accId = await insertAccount(email: 'll8@test.local');
      final profId = await insertProfile(accId);
      final e1 = await insertAndGetEntry(profId);
      final e2 = await (db.select(
        db.learningLedger,
      )..where((t) => t.id.equals(e1.id))).getSingleOrNull();
      expect(e1.toString(), contains('LearningLedgerData'));
      expect(e1, equals(e2));
      expect(e1.hashCode, equals(e2!.hashCode));
    });
  });

  // ─── Goal DataClass ───────────────────────────────────────────────────────

  group('Goal DataClass', () {
    Future<Goal> insertAndGetGoal(int profileId, int trackId) async {
      final id = await db
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
      return (await (db.select(
        db.goals,
      )..where((t) => t.id.equals(id))).getSingleOrNull())!;
    }

    Future<Goal> insertAndGetGoalWithNullables(
      int profileId,
      int trackId,
    ) async {
      final id = await db
          .into(db.goals)
          .insert(
            GoalsCompanion.insert(
              profileId: profileId,
              curriculumId: 'bavli',
              trackId: trackId,
              targetDate: Value(now),
              paceValue: const Value(5),
              pacePeriod: const Value('week'),
              paceGranularity: const Value('daf'),
              createdAt: now,
              updatedAt: now,
            ),
          );
      return (await (db.select(
        db.goals,
      )..where((t) => t.id.equals(id))).getSingleOrNull())!;
    }

    test('toColumns with null nullable fields and nullToAbsent=true', () async {
      final accId = await insertAccount(email: 'gl1@test.local');
      final profId = await insertProfile(accId);
      final trackId = await insertTrack(profId);
      final goal = await insertAndGetGoal(profId, trackId);
      final cols = goal.toColumns(true);
      expect(cols.containsKey('id'), isTrue);
      expect(cols.containsKey('target_percent'), isTrue);
      expect(cols.containsKey('description'), isTrue);
      // null nullable fields absent
      expect(cols.containsKey('target_date'), isFalse);
      expect(cols.containsKey('pace_value'), isFalse);
      expect(cols.containsKey('pace_unit'), isFalse);
      expect(cols.containsKey('learning_unit'), isFalse);
    });

    test('toColumns with non-null nullable fields', () async {
      final accId = await insertAccount(email: 'gl2@test.local');
      final profId = await insertProfile(accId);
      final trackId = await insertTrack(profId);
      final goal = await insertAndGetGoalWithNullables(profId, trackId);
      final cols = goal.toColumns(true);
      expect(cols.containsKey('target_date'), isTrue);
      expect(cols.containsKey('pace_value'), isTrue);
      expect(cols.containsKey('pace_unit'), isTrue);
      expect(cols.containsKey('learning_unit'), isTrue);
    });

    test('toColumns with nullToAbsent=false includes all fields', () async {
      final accId = await insertAccount(email: 'gl3@test.local');
      final profId = await insertProfile(accId);
      final trackId = await insertTrack(profId);
      final goal = await insertAndGetGoal(profId, trackId);
      final cols = goal.toColumns(false);
      expect(cols.containsKey('target_date'), isTrue);
      expect(cols.containsKey('pace_value'), isTrue);
      expect(cols.containsKey('pace_unit'), isTrue);
      expect(cols.containsKey('learning_unit'), isTrue);
    });

    test('toCompanion with nullToAbsent=true omits null fields', () async {
      final accId = await insertAccount(email: 'gl4@test.local');
      final profId = await insertProfile(accId);
      final trackId = await insertTrack(profId);
      final goal = await insertAndGetGoal(profId, trackId);
      final comp = goal.toCompanion(true);
      expect(comp.curriculumId.value, 'bavli');
      expect(comp.targetDate.present, isFalse);
      expect(comp.paceValue.present, isFalse);
      expect(comp.pacePeriod.present, isFalse);
    });

    test('toCompanion with non-null nullable includes them', () async {
      final accId = await insertAccount(email: 'gl5@test.local');
      final profId = await insertProfile(accId);
      final trackId = await insertTrack(profId);
      final goal = await insertAndGetGoalWithNullables(profId, trackId);
      final comp = goal.toCompanion(true);
      expect(comp.targetDate.present, isTrue);
      expect(comp.paceValue.present, isTrue);
      expect(comp.pacePeriod.present, isTrue);
    });

    test('toCompanion with nullToAbsent=false includes null fields', () async {
      final accId = await insertAccount(email: 'gl6@test.local');
      final profId = await insertProfile(accId);
      final trackId = await insertTrack(profId);
      final goal = await insertAndGetGoal(profId, trackId);
      final comp = goal.toCompanion(false);
      expect(comp.targetDate.present, isTrue);
      expect(comp.paceValue.present, isTrue);
    });

    test('copyWith changes targetPercent and paceValue', () async {
      final accId = await insertAccount(email: 'gl7@test.local');
      final profId = await insertProfile(accId);
      final trackId = await insertTrack(profId);
      final goal = await insertAndGetGoal(profId, trackId);
      final copy = goal.copyWith(
        targetPercent: 50.0,
        paceValue: const Value(3),
        pacePeriod: const Value('day'),
        paceGranularity: const Value('amud'),
        targetDate: Value(now),
        description: 'My goal',
        dateType: 'hebrew',
        goalType: 'pace',
      );
      expect(copy.targetPercent, 50.0);
      expect(copy.paceValue, 3);
      expect(copy.pacePeriod, 'day');
      expect(copy.paceGranularity, 'amud');
      expect(copy.description, 'My goal');
    });

    test('copyWithCompanion applies changes', () async {
      final accId = await insertAccount(email: 'gl8@test.local');
      final profId = await insertProfile(accId);
      final trackId = await insertTrack(profId);
      final goal = await insertAndGetGoal(profId, trackId);
      final copy = goal.copyWithCompanion(
        GoalsCompanion(
          targetDate: Value(now),
          paceValue: const Value(7),
          pacePeriod: const Value('week'),
          paceGranularity: const Value('daf'),
          description: const Value('Weekly daf goal'),
          goalType: const Value('pace'),
        ),
      );
      expect(copy.paceValue, 7);
      expect(copy.pacePeriod, 'week');
      expect(copy.description, 'Weekly daf goal');
    });

    test('fromJson / toJson round-trip', () async {
      final accId = await insertAccount(email: 'gl9@test.local');
      final profId = await insertProfile(accId);
      final trackId = await insertTrack(profId);
      final goal = await insertAndGetGoalWithNullables(profId, trackId);
      final json = goal.toJson();
      expect(json['curriculumId'], 'bavli');
      expect(json['paceValue'], 5);
      final restored = Goal.fromJson(json);
      expect(restored, equals(goal));
    });

    test('toString and hashCode', () async {
      final accId = await insertAccount(email: 'gl10@test.local');
      final profId = await insertProfile(accId);
      final trackId = await insertTrack(profId);
      final g1 = await insertAndGetGoal(profId, trackId);
      final g2 = await (db.select(
        db.goals,
      )..where((t) => t.id.equals(g1.id))).getSingleOrNull();
      expect(g1.toString(), contains('Goal'));
      expect(g1, equals(g2));
      expect(g1.hashCode, equals(g2!.hashCode));
    });
  });

  // ─── validateIntegrity — missing required fields ──────────────────────────

  group('validateIntegrity — main tables', () {
    test('Accounts insert without email throws', () {
      expect(
        () => db.into(db.accounts).insert(const AccountsCompanion()),
        throwsA(anything),
      );
    });

    test('LearnerProfiles insert without accountId throws', () {
      expect(
        () => db
            .into(db.learnerProfiles)
            .insert(const LearnerProfilesCompanion()),
        throwsA(anything),
      );
    });

    test('CurriculumTracks insert without profileId throws', () {
      expect(
        () => db
            .into(db.curriculumTracks)
            .insert(const CurriculumTracksCompanion()),
        throwsA(anything),
      );
    });

    test('CurriculumScopes insert without profileId throws', () {
      expect(
        () => db
            .into(db.curriculumScopes)
            .insert(const CurriculumScopesCompanion()),
        throwsA(anything),
      );
    });

    test('ProfilePrograms insert without profileId throws', () {
      expect(
        () => db
            .into(db.profilePrograms)
            .insert(const ProfileProgramsCompanion()),
        throwsA(anything),
      );
    });

    test('DailyPlans insert without profileId throws', () {
      expect(
        () => db.into(db.dailyPlans).insert(const DailyPlansCompanion()),
        throwsA(anything),
      );
    });

    test('LearningLedger insert without profileId throws', () {
      expect(
        () =>
            db.into(db.learningLedger).insert(const LearningLedgerCompanion()),
        throwsA(anything),
      );
    });

    test('Goals insert without profileId throws', () {
      expect(
        () => db.into(db.goals).insert(const GoalsCompanion()),
        throwsA(anything),
      );
    });

    test('StageDefinitions insert without profileId throws', () {
      expect(
        () => db
            .into(db.stageDefinitions)
            .insert(const StageDefinitionsCompanion()),
        throwsA(anything),
      );
    });

    test('PointConfigs insert without profileId throws', () {
      expect(
        () => db.into(db.pointConfigs).insert(const PointConfigsCompanion()),
        throwsA(anything),
      );
    });

    test('StudyDayConfigs insert without profileId throws', () {
      expect(
        () => db
            .into(db.studyDayConfigs)
            .insert(const StudyDayConfigsCompanion()),
        throwsA(anything),
      );
    });

    test('Completions insert without profileId throws', () {
      expect(
        () => db.into(db.completions).insert(const CompletionsCompanion()),
        throwsA(anything),
      );
    });

    test('CompletionEvents insert without profileId throws', () {
      expect(
        () => db
            .into(db.completionEvents)
            .insert(const CompletionEventsCompanion()),
        throwsA(anything),
      );
    });

    test('Bookmarks insert without profileId throws', () {
      expect(
        () => db.into(db.bookmarks).insert(const BookmarksCompanion()),
        throwsA(anything),
      );
    });

    test('LearningOrder insert without profileId throws', () {
      expect(
        () => db.into(db.learningOrder).insert(const LearningOrderCompanion()),
        throwsA(anything),
      );
    });

    test('Streaks insert without profileId throws', () {
      expect(
        () => db.into(db.streaks).insert(const StreaksCompanion()),
        throwsA(anything),
      );
    });

    test('StreakEvents insert without profileId throws', () {
      expect(
        () => db.into(db.streakEvents).insert(const StreakEventsCompanion()),
        throwsA(anything),
      );
    });
  });
}
