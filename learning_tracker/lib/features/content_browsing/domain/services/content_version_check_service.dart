import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/logging/logger.dart';

/// Service that checks for content updates.
///
/// With bundled assets, this is a no-op placeholder.
/// Could be extended to check for OTA content updates in the future.
class ContentVersionCheckService {
  /// Check for updates. Returns empty list (content is bundled).
  Future<List<CurriculumId>> checkForUpdates(
    List<CurriculumId> activeCurricula,
  ) async {
    AppLogger.instance.info(
      'ContentVersionCheckService: content is bundled, no update check needed',
    );
    return [];
  }
}
