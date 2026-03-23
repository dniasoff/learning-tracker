@Tags(['story_15_13'])
library;

import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/content_browsing/domain/services/content_version_check_service.dart';
import 'package:test/test.dart';

void main() {
  late ContentVersionCheckService service;

  setUp(() {
    service = ContentVersionCheckService();
  });

  group('ContentVersionCheckService', () {
    group('checkForUpdates', () {
      test('returns empty list (content is bundled)', () async {
        final result = await service.checkForUpdates([CurriculumId.bavli]);

        expect(result, isEmpty);
      });

      test('returns empty for multiple curricula', () async {
        final result = await service.checkForUpdates([
          CurriculumId.bavli,
          CurriculumId.mishnayos,
        ]);

        expect(result, isEmpty);
      });

      test('returns empty for empty input', () async {
        final result = await service.checkForUpdates(<CurriculumId>[]);

        expect(result, isEmpty);
      });
    });
  });
}
