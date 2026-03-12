import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/stages/domain/models/stage_definition.dart';
import 'package:learning_tracker/features/stages/domain/repositories/stage_definition_repository.dart';
import 'package:learning_tracker/features/stages/presentation/providers/stage_providers.dart';
import 'package:learning_tracker/features/stages/presentation/screens/stage_editor_screen.dart';
import 'package:mocktail/mocktail.dart';

class MockStageDefinitionRepository extends Mock
    implements StageDefinitionRepository {}

class FakeStageEditorNotifier extends AsyncNotifier<List<StageDefinition>>
    implements StageEditorNotifier {
  // ignore: avoid_unused_constructor_parameters
  FakeStageEditorNotifier(CurriculumId curriculum, this._stages);

  final List<StageDefinition> _stages;

  @override
  Future<List<StageDefinition>> build() async => _stages;

  @override
  Future<void> addStage(String name, int delayDays) async {}

  @override
  Future<void> updateStage(int id, {String? name, int? delayDays}) async {}

  @override
  Future<void> deleteStage(int id) async {}

  @override
  Future<void> reorderStages(List<int> orderedIds) async {}

  @override
  Future<void> resetToDefaults() async {}
}

void main() {
  const curriculum = CurriculumId.mishnayos;

  List<StageDefinition> defaultStages() => [
    const StageDefinition(
      id: 1,
      curriculumId: curriculum,
      stageOrder: 1,
      stageName: 'Learn',
      delayDays: 0,
      isDefault: true,
    ),
    const StageDefinition(
      id: 2,
      curriculumId: curriculum,
      stageOrder: 2,
      stageName: 'Chazara 1',
      delayDays: 1,
      isDefault: true,
    ),
    const StageDefinition(
      id: 3,
      curriculumId: curriculum,
      stageOrder: 3,
      stageName: 'Chazara 2',
      delayDays: 7,
      isDefault: true,
    ),
  ];

  Widget buildScreen({
    List<StageDefinition>? stages,
    MockStageDefinitionRepository? repository,
  }) {
    final stageList = stages ?? defaultStages();
    final mockRepo = repository ?? MockStageDefinitionRepository();

    return ProviderScope(
      overrides: [
        stageEditorProvider(
          curriculum,
        ).overrideWith(() => FakeStageEditorNotifier(curriculum, stageList)),
        stageDefinitionRepositoryProvider(
          curriculum,
        ).overrideWithValue(mockRepo),
      ],
      child: const MaterialApp(
        home: StageEditorScreen(curriculumId: 'mishnayos'),
      ),
    );
  }

  group('StageEditorScreen', () {
    testWidgets('renders 3 default stages in order', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      expect(find.text('Learn'), findsOneWidget);
      expect(find.text('Chazara 1'), findsOneWidget);
      expect(find.text('Chazara 2'), findsOneWidget);
    });

    testWidgets('Learn stage has no delete button', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      // Find all delete icon buttons
      final deleteButtons = find.byIcon(Icons.delete);
      // There should be 2 delete buttons (Chazara 1 and Chazara 2), not 3
      expect(deleteButtons, findsNWidgets(2));
    });

    testWidgets('deleting a stage with completions shows warning dialog', (
      tester,
    ) async {
      final mockRepo = MockStageDefinitionRepository();
      when(
        () => mockRepo.hasCompletionsForStage(3),
      ).thenAnswer((_) async => true);

      await tester.pumpWidget(buildScreen(repository: mockRepo));
      await tester.pump();

      // Tap delete on Chazara 2 (id=3, stageOrder=3)
      // Find the delete icon buttons and tap the last one (Chazara 2)
      final deleteButtons = find.byIcon(Icons.delete);
      await tester.tap(deleteButtons.last);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Delete Stage'), findsOneWidget);
      expect(find.textContaining('existing completions'), findsOneWidget);
    });

    testWidgets('Reset to Defaults button shows confirmation dialog', (
      tester,
    ) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      await tester.tap(find.byIcon(Icons.restore));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Reset to Defaults'), findsOneWidget);
    });

    testWidgets('Add Stage FAB opens input dialog', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Add Stage'), findsOneWidget);
      expect(find.text('Stage name'), findsOneWidget);
    });
  });
}
