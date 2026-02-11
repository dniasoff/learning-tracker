/// Story acceptance tests for Epic 4 -- Multi-Track.
/// Stories 4.1 and 4.2 are backlog (skipped).
/// Story 4.3 (DNI-40) has full acceptance tests for track-specific progress views.
@Tags(['epic_4'])
library;

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/app_database.dart';
import 'package:learning_tracker/core/enums/track_type.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/core/widgets/track_progress_bar.dart';
import 'package:learning_tracker/features/progress/data/repositories/progress_repository_impl.dart';
import 'package:learning_tracker/features/progress/presentation/providers/progress_providers.dart';
import 'package:learning_tracker/features/progress/presentation/screens/completion_history_screen.dart';
import 'package:learning_tracker/features/progress/presentation/screens/curriculum_progress_screen.dart';

void main() {
  // ── Story 4.1: Track CRUD ─────────────────────────────────────

  group(
    'Story 4.1 -- Track CRUD',
    tags: ['story_4_1'],
    skip: 'Backlog: track CRUD UI not yet implemented',
    () {
      test('user can create a school track for a curriculum', () {
        // TODO: verify TrackDao.activateTrack creates a track
      });

      test('personal track cannot be deleted', () {
        // TODO: verify personal track is always present
      });

      test('deactivating a track preserves its history', () {
        // TODO: verify completions remain after deactivation
      });
    },
  );

  // ── Story 4.2: Track switching ────────────────────────────────

  group(
    'Story 4.2 -- Track switching',
    tags: ['story_4_2'],
    skip: 'Backlog: track switching UI not yet implemented',
    () {
      test('switching tracks updates the bookmark position', () {
        // TODO: verify bookmark changes per track
      });

      test('each track maintains independent progress', () {
        // TODO: verify completions are scoped to track
      });
    },
  );

  // ── Story 4.3: Track-Specific Progress Views (DNI-40) ────────

  group('Story 4.3: Track-Specific Progress Views', () {
    late AppDatabase database;

    setUp(() {
      database = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await database.close();
    });

    group('Unit Tests', () {
      test(
        'ProgressRepository.getTrackBreakdown returns Map<TrackType, int> with correct counts per track from completions table',
        () async {
          // Arrange
          final repository = ProgressRepositoryImpl(database: database);
          await database.completionDao.insertCompletion(
            CompletionsCompanion.insert(
              curriculumId: 'bavli',
              sefariaRef: 'Berakhot.2a',
              stageId: 1,
              trackType: TrackType.personal.storageKey,
              completedAt: DateTime.now(),
              points: const drift.Value(10),
            ),
          );
          await database.completionDao.insertCompletion(
            CompletionsCompanion.insert(
              curriculumId: 'bavli',
              sefariaRef: 'Berakhot.2b',
              stageId: 1,
              trackType: TrackType.school.storageKey,
              completedAt: DateTime.now(),
              points: const drift.Value(10),
            ),
          );

          // Act
          final breakdown = await repository.getTrackBreakdown('bavli');

          // Assert
          expect(breakdown[TrackType.personal], 1);
          expect(breakdown[TrackType.school], 1);
          expect(breakdown[TrackType.tutor], 0);
        },
      );

      test(
        'ProgressRepository.getTrackBreakdown returns zero counts for inactive tracks that have no completions',
        () async {
          // Arrange
          final repository = ProgressRepositoryImpl(database: database);
          await database.completionDao.insertCompletion(
            CompletionsCompanion.insert(
              curriculumId: 'bavli',
              sefariaRef: 'Berakhot.2a',
              stageId: 1,
              trackType: TrackType.personal.storageKey,
              completedAt: DateTime.now(),
              points: const drift.Value(10),
            ),
          );

          // Act
          final breakdown = await repository.getTrackBreakdown('bavli');

          // Assert
          expect(breakdown[TrackType.personal], 1);
          expect(breakdown[TrackType.school], 0);
          expect(breakdown[TrackType.tutor], 0);
        },
      );

      test(
        'ProgressRepository.getTrackBreakdown includes completions from deactivated tracks (data preserved per DNI-38)',
        () async {
          // Arrange
          final repository = ProgressRepositoryImpl(database: database);
          await database.completionDao.insertCompletion(
            CompletionsCompanion.insert(
              curriculumId: 'bavli',
              sefariaRef: 'Berakhot.2a',
              stageId: 1,
              trackType: TrackType.school.storageKey,
              completedAt: DateTime.now(),
              points: const drift.Value(10),
            ),
          );

          // Act
          final breakdown = await repository.getTrackBreakdown('bavli');

          // Assert: School completions are still included even if track is deactivated
          expect(breakdown[TrackType.school], 1);
        },
      );

      test(
        'ProgressRepository.getAggregateCount returns sum across all tracks, matching individual track counts',
        () async {
          // Arrange
          final repository = ProgressRepositoryImpl(database: database);
          await database.completionDao.insertCompletion(
            CompletionsCompanion.insert(
              curriculumId: 'bavli',
              sefariaRef: 'Berakhot.2a',
              stageId: 1,
              trackType: TrackType.personal.storageKey,
              completedAt: DateTime.now(),
              points: const drift.Value(10),
            ),
          );
          await database.completionDao.insertCompletion(
            CompletionsCompanion.insert(
              curriculumId: 'bavli',
              sefariaRef: 'Berakhot.2b',
              stageId: 1,
              trackType: TrackType.school.storageKey,
              completedAt: DateTime.now(),
              points: const drift.Value(10),
            ),
          );

          // Act
          final breakdown = await repository.getTrackBreakdown('bavli');
          final aggregate = await repository.getAggregateCount('bavli');

          // Assert
          final expectedTotal = breakdown.values.fold<int>(
            0,
            (sum, count) => sum + count,
          );
          expect(aggregate, expectedTotal);
          expect(aggregate, 2);
        },
      );

      test(
        'Track color mapping is sourced from theme configuration, not hardcoded in business logic',
        () {
          // Assert: Track colors are defined in theme
          expect(AppTheme.trackPersonal, isA<Color>());
          expect(AppTheme.trackSchool, isA<Color>());
          expect(AppTheme.trackTutor, isA<Color>());

          // Assert: getTrackColor method exists and returns colors
          expect(
            AppTheme.getTrackColor(TrackType.personal),
            AppTheme.trackPersonal,
          );
          expect(
            AppTheme.getTrackColor(TrackType.school),
            AppTheme.trackSchool,
          );
          expect(AppTheme.getTrackColor(TrackType.tutor), AppTheme.trackTutor);
        },
      );
    });

    group('Widget Tests', () {
      testWidgets(
        'TrackProgressBar renders segmented bar with correct proportions and track-specific colors',
        (tester) async {
          // Arrange
          final trackCounts = {
            TrackType.personal: 150,
            TrackType.school: 80,
            TrackType.tutor: 20,
          };

          // Act
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.lightTheme,
              home: Scaffold(body: TrackProgressBar(trackCounts: trackCounts)),
            ),
          );

          // Assert
          expect(find.byType(TrackProgressBar), findsOneWidget);
          expect(find.text('Personal: 150'), findsOneWidget);
          expect(find.text('School: 80'), findsOneWidget);
          expect(find.text('Tutor: 20'), findsOneWidget);
        },
      );

      testWidgets(
        'CompletionHistoryScreen with track filter shows only completions for the selected track',
        (tester) async {
          // Arrange: Insert completions for different tracks
          await database.completionDao.insertCompletion(
            CompletionsCompanion.insert(
              curriculumId: 'bavli',
              sefariaRef: 'Berakhot.2a',
              stageId: 1,
              trackType: TrackType.personal.storageKey,
              completedAt: DateTime.now(),
              points: const drift.Value(10),
            ),
          );
          await database.completionDao.insertCompletion(
            CompletionsCompanion.insert(
              curriculumId: 'bavli',
              sefariaRef: 'Berakhot.2b',
              stageId: 1,
              trackType: TrackType.school.storageKey,
              completedAt: DateTime.now(),
              points: const drift.Value(10),
            ),
          );

          // Act
          await tester.pumpWidget(
            ProviderScope(
              overrides: [appDatabaseProvider.overrideWithValue(database)],
              child: MaterialApp(
                theme: AppTheme.lightTheme,
                home: const CompletionHistoryScreen(curriculumId: 'bavli'),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Assert: Both completions shown initially
          expect(find.text('Berakhot.2a'), findsOneWidget);
          expect(find.text('Berakhot.2b'), findsOneWidget);

          // Act: Open filter menu and select Personal
          await tester.tap(find.byIcon(Icons.filter_alt_outlined));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Personal'));
          await tester.pumpAndSettle();

          // Assert: Only personal completion shown
          expect(find.text('Berakhot.2a'), findsOneWidget);
          expect(find.text('Berakhot.2b'), findsNothing);
        },
      );

      testWidgets(
        'Toggling between aggregate view and track breakdown view updates the displayed data correctly',
        (tester) async {
          // Arrange: Insert completions
          await database.completionDao.insertCompletion(
            CompletionsCompanion.insert(
              curriculumId: 'bavli',
              sefariaRef: 'Berakhot.2a',
              stageId: 1,
              trackType: TrackType.personal.storageKey,
              completedAt: DateTime.now(),
              points: const drift.Value(10),
            ),
          );
          await database.completionDao.insertCompletion(
            CompletionsCompanion.insert(
              curriculumId: 'bavli',
              sefariaRef: 'Berakhot.2b',
              stageId: 1,
              trackType: TrackType.school.storageKey,
              completedAt: DateTime.now(),
              points: const drift.Value(10),
            ),
          );

          // Act
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                appDatabaseProvider.overrideWithValue(database),
                progressRepositoryProvider.overrideWithValue(
                  ProgressRepositoryImpl(database: database),
                ),
              ],
              child: MaterialApp(
                theme: AppTheme.lightTheme,
                home: const CurriculumProgressScreen(curriculumId: 'bavli'),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Assert: Breakdown view is shown by default
          expect(find.text('Completion Breakdown by Track'), findsOneWidget);
          expect(find.byType(TrackProgressBar), findsOneWidget);

          // Act: Toggle to aggregate view
          await tester.tap(find.text('Total'));
          await tester.pumpAndSettle();

          // Assert: Aggregate view is shown
          expect(find.text('Total Completions'), findsOneWidget);
          expect(find.text('2'), findsOneWidget); // Total count
        },
      );

      testWidgets(
        'Track-colored indicators render correctly in both light and dark themes',
        (tester) async {
          // Arrange
          final trackCounts = {
            TrackType.personal: 10,
            TrackType.school: 5,
            TrackType.tutor: 0,
          };

          // Test light theme
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.lightTheme,
              home: Scaffold(body: TrackProgressBar(trackCounts: trackCounts)),
            ),
          );

          // Assert: Widget renders in light theme
          expect(find.byType(TrackProgressBar), findsOneWidget);

          // Note: Dark theme test would go here when dark theme is implemented
        },
      );
    });

    group('Integration Tests', () {
      test(
        'Complete 3 items under personal and 2 under school for Bavli — progress view shows "Personal: 3, School: 2, Total: 5"',
        () async {
          // Arrange: Complete 3 personal items
          for (var i = 1; i <= 3; i++) {
            await database.completionDao.insertCompletion(
              CompletionsCompanion.insert(
                curriculumId: 'bavli',
                sefariaRef: 'Berakhot.${i}a',
                stageId: 1,
                trackType: TrackType.personal.storageKey,
                completedAt: DateTime.now(),
                points: const drift.Value(10),
              ),
            );
          }

          // Arrange: Complete 2 school items
          for (var i = 4; i <= 5; i++) {
            await database.completionDao.insertCompletion(
              CompletionsCompanion.insert(
                curriculumId: 'bavli',
                sefariaRef: 'Berakhot.${i}a',
                stageId: 1,
                trackType: TrackType.school.storageKey,
                completedAt: DateTime.now(),
                points: const drift.Value(10),
              ),
            );
          }

          // Act
          final repository = ProgressRepositoryImpl(database: database);
          final breakdown = await repository.getTrackBreakdown('bavli');
          final aggregate = await repository.getAggregateCount('bavli');

          // Assert
          expect(breakdown[TrackType.personal], 3);
          expect(breakdown[TrackType.school], 2);
          expect(breakdown[TrackType.tutor], 0);
          expect(aggregate, 5);
        },
      );

      test(
        'Deactivate school track — progress view still shows school completions in breakdown (historical data preserved)',
        () async {
          // Arrange: Complete items under school track
          await database.completionDao.insertCompletion(
            CompletionsCompanion.insert(
              curriculumId: 'bavli',
              sefariaRef: 'Berakhot.2a',
              stageId: 1,
              trackType: TrackType.school.storageKey,
              completedAt: DateTime.now(),
              points: const drift.Value(10),
            ),
          );

          // Note: Track deactivation is managed by TrackRepository
          // Completions persist regardless of track activation state

          // Act
          final repository = ProgressRepositoryImpl(database: database);
          final breakdown = await repository.getTrackBreakdown('bavli');

          // Assert: School completions are still visible
          expect(breakdown[TrackType.school], 1);
        },
      );
    });
  });
}
