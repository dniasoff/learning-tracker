import 'package:learning_tracker/core/database/seed/learning_program_seeds.dart';

/// In-memory learning program data, replacing the old ContentDatabase DAO.
///
/// All data comes from [learningProgramSeeds] — a compile-time constant.
/// Programs are assigned synthetic IDs (1-based index in the seed list).
class LearningProgramData {
  const LearningProgramData({
    required this.id,
    required this.name,
    required this.displayName,
    required this.description,
    required this.curriculumType,
    required this.isActive,
    required this.hasTests,
    required this.stagesConfig,
    required this.testConfig,
    required this.apiSource,
    required this.apiProgramKey,
    required this.isCalendarProgram,
  });

  final int id;
  final String name;
  final String displayName;
  final String description;
  final String curriculumType;
  final bool isActive;
  final bool hasTests;
  final String stagesConfig;
  final String testConfig;
  final String? apiSource;
  final String? apiProgramKey;
  final bool isCalendarProgram;
}

/// Provides learning program data from compile-time constants.
///
/// Drop-in replacement for `ContentLearningProgramDao` — same query patterns,
/// no database required.
class LearningProgramRepository {
  LearningProgramRepository._();
  static final instance = LearningProgramRepository._();

  late final List<LearningProgramData> _programs = _buildPrograms();

  static List<LearningProgramData> _buildPrograms() {
    return List.generate(learningProgramSeeds.length, (i) {
      final p = learningProgramSeeds[i];
      return LearningProgramData(
        id: i + 1,
        name: p['name']! as String,
        displayName: p['display_name']! as String,
        description: (p['description'] as String?) ?? '',
        curriculumType: p['curriculum_type']! as String,
        isActive: (p['is_active'] as bool?) ?? true,
        hasTests: (p['has_tests'] as bool?) ?? false,
        stagesConfig: p['stages_config']! as String,
        testConfig: (p['test_config'] as String?) ?? '{}',
        apiSource: p['api_source'] as String?,
        apiProgramKey: p['api_program_key'] as String?,
        isCalendarProgram: (p['is_calendar_program'] as bool?) ?? false,
      );
    });
  }

  List<LearningProgramData> getAllPrograms() => _programs;

  List<LearningProgramData> getActivePrograms() =>
      _programs.where((p) => p.isActive).toList();

  LearningProgramData? getProgramById(int id) {
    if (id < 1 || id > _programs.length) return null;
    return _programs[id - 1];
  }

  LearningProgramData? getProgramByName(String name) {
    for (final p in _programs) {
      if (p.name == name) return p;
    }
    return null;
  }

  List<LearningProgramData> getProgramsByCurriculumType(
    String curriculumType,
  ) => _programs.where((p) => p.curriculumType == curriculumType).toList();
}
