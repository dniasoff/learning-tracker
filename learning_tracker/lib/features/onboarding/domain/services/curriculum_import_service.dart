import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/features/tracks/domain/services/curriculum_activation_service.dart';

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

/// Activates selected curricula during onboarding.
///
/// Content is bundled in assets, so no download is needed.
/// This service just activates curricula in the database.
class CurriculumImportService {
  CurriculumImportService({
    required CurriculumActivationService activationService,
  }) : _activationService = activationService;

  final CurriculumActivationService _activationService;

  /// Activate all selected curricula, yielding progress after each one.
  Stream<CurriculumImportProgress> importAll(
    List<CurriculumId> selectedCurricula,
  ) async* {
    final total = selectedCurricula.length;
    final results = <CurriculumImportResult>[];

    for (var i = 0; i < total; i++) {
      final curriculum = selectedCurricula[i];
      final result = await _activateOne(curriculum);
      results.add(result);

      yield CurriculumImportProgress(
        current: i + 1,
        total: total,
        currentCurriculum: curriculum,
        results: List.unmodifiable(results),
      );
    }
  }

  /// Activate a single curriculum. Used for retrying failed activations.
  Future<CurriculumImportResult> importSingle(CurriculumId curriculum) async {
    return _activateOne(curriculum);
  }

  Future<CurriculumImportResult> _activateOne(CurriculumId curriculum) async {
    try {
      await _activationService.activate(curriculum);

      AppLogger.instance.info(
        event: 'CurriculumImportService: activated ${curriculum.displayNameEn}',
      );

      return CurriculumImportResult(curriculumId: curriculum, success: true);
    } on Exception catch (e) {
      AppLogger.instance.error(
        event:
            'CurriculumImportService: failed to activate ${curriculum.displayNameEn}',
        exception: e,
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

  final int current;
  final int total;
  final CurriculumId currentCurriculum;
  final List<CurriculumImportResult> results;

  double get fraction => total > 0 ? current / total : 0;
  bool get allSucceeded => results.every((r) => r.success);
  List<CurriculumImportResult> get failures =>
      results.where((r) => !r.success).toList();
  bool get isComplete => current == total;
}
