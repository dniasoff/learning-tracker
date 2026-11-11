import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/data/repositories/firestore_social_summary_repository.dart';

void main() {
  test(
    'reads only the requested sanitized summary from the server source',
    () async {
      final firestore = FakeFirebaseFirestore();
      final id = List.filled(64, 'a').join();
      await firestore.collection('social_summaries').doc(id).set({
        'display_name': 'Learner',
        'avatar_id': 1,
        'streak': {'by_curriculum': <Object?>[]},
        'current_tracks': <Object?>[],
        'weekly_learning': {
          'week_start': '2026-11-08',
          'by_curriculum': <Object?>[],
        },
        'siyumim': <Object?>[],
        'computed_at': DateTime.utc(2026, 11, 10),
        'schema_version': 1,
      });

      final summary = await FirestoreSocialSummaryRepository(
        firestore,
      ).read(id);

      expect(summary?.displayName, 'Learner');
      expect(summary?.weeklyLearning.weekStart, '2026-11-08');
    },
  );

  test('rejects non-hash summary ids before querying Firestore', () async {
    final repository = FirestoreSocialSummaryRepository(
      FakeFirebaseFirestore(),
    );

    await expectLater(repository.read('../profile'), throwsFormatException);
  });

  test(
    'returns null when the granted summary has no published projection',
    () async {
      final repository = FirestoreSocialSummaryRepository(
        FakeFirebaseFirestore(),
      );

      expect(await repository.read(List.filled(64, 'b').join()), isNull);
    },
  );
}
