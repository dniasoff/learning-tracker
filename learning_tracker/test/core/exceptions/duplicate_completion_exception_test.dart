// Tests for DuplicateCompletionException — covers toString and userMessage.
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/exceptions/duplicate_completion_exception.dart';

void main() {
  group('DuplicateCompletionException', () {
    test('toString contains curriculum, sefariaRef, stageId', () {
      final ex = DuplicateCompletionException(
        curriculumId: 'mishnayos',
        sefariaRef: 'Berakhot 1:1',
        stageId: 2,
        existingTrackName: 'Personal',
      );
      final str = ex.toString();
      expect(str, contains('DuplicateCompletionException'));
      expect(str, contains('Berakhot 1:1'));
      expect(str, contains('2'));
      expect(str, contains('mishnayos'));
    });

    test('userMessage contains existing track name', () {
      final ex = DuplicateCompletionException(
        curriculumId: 'bavli',
        sefariaRef: 'Daf 2a',
        stageId: 1,
        existingTrackName: 'Community Track',
      );
      expect(ex.userMessage, contains('Community Track'));
    });

    test('is an Exception', () {
      final ex = DuplicateCompletionException(
        curriculumId: 'mishnayos',
        sefariaRef: 'ref',
        stageId: 1,
        existingTrackName: 'Personal',
      );
      expect(ex, isA<Exception>());
    });
  });
}
