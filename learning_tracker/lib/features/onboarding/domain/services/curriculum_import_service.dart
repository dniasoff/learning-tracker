import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/settings/domain/services/curriculum_activation_service.dart';

/// Result of importing a single curriculum.
class CurriculumImportResult {
  const CurriculumImportResult({
    required this.curriculumId,
    required this.success,
    this.itemCount = 0,
    this.error,
  });

  final CurriculumId curriculumId;
  final bool success;
  final int itemCount;
  final String? error;
}

/// Orchestrates importing bundled content for selected curricula during onboarding.
///
/// For each selected curriculum:
/// 1. Loads bundled JSON content (validates it's accessible)
/// 2. Activates the curriculum in the database
/// 3. Reports progress per curriculum
class CurriculumImportService {
  CurriculumImportService({
    required ContentRepository contentRepository,
    required CurriculumActivationService activationService,
  }) : _contentRepository = contentRepository,
       _activationService = activationService;

  final ContentRepository _contentRepository;
  final CurriculumActivationService _activationService;

  /// Import all selected curricula, yielding progress after each one.
  ///
  /// The stream emits a [CurriculumImportProgress] after each curriculum
  /// is processed (success or failure). Callers can retry failed ones
  /// individually via [importSingle].
  Stream<CurriculumImportProgress> importAll(
    List<CurriculumId> selectedCurricula,
  ) async* {
    final total = selectedCurricula.length;
    final results = <CurriculumImportResult>[];

    for (var i = 0; i < total; i++) {
      final curriculum = selectedCurricula[i];
      final result = await _importOne(curriculum);
      results.add(result);

      yield CurriculumImportProgress(
        current: i + 1,
        total: total,
        currentCurriculum: curriculum,
        results: List.unmodifiable(results),
      );
    }
  }

  /// Import a single curriculum. Used for retrying failed imports.
  Future<CurriculumImportResult> importSingle(CurriculumId curriculum) async {
    return _importOne(curriculum);
  }

  Future<CurriculumImportResult> _importOne(CurriculumId curriculum) async {
    try {
      // Load bundled content to validate it's accessible
      final items = await _contentRepository.getContentForCurriculum(
        curriculum,
      );

      // Activate in database (also initializes default tracks)
      await _activationService.activate(curriculum);

      AppLogger.instance.info(
        'CurriculumImportService: imported ${curriculum.displayNameEn} '
        '(${items.length} items)',
      );

      return CurriculumImportResult(
        curriculumId: curriculum,
        success: true,
        itemCount: items.length,
      );
    } catch (e) {
      AppLogger.instance.error(
        'CurriculumImportService: failed to import ${curriculum.displayNameEn}',
        e,
      );

      return CurriculumImportResult(
        curriculumId: curriculum,
        success: false,
        error: e.toString(),
      );
    }
  }
}

/// Progress snapshot during bulk import.
class CurriculumImportProgress {
  const CurriculumImportProgress({
    required this.current,
    required this.total,
    required this.currentCurriculum,
    required this.results,
  });

  /// How many curricula have been processed so far.
  final int current;

  /// Total number to process.
  final int total;

  /// The curriculum that was just processed.
  final CurriculumId currentCurriculum;

  /// Results accumulated so far.
  final List<CurriculumImportResult> results;

  /// Fraction complete (0.0 to 1.0).
  double get fraction => total > 0 ? current / total : 0;

  /// Whether all processed so far succeeded.
  bool get allSucceeded => results.every((r) => r.success);

  /// The failed results.
  List<CurriculumImportResult> get failures =>
      results.where((r) => !r.success).toList();

  /// Whether we're done (all processed).
  bool get isComplete => current == total;
}
