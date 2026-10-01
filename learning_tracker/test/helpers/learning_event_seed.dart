/// Seeding helpers for the Story 1.2 (DNI-464) repository tests: N valid
/// AD-52 learning-event docs with ascending ULID ids in a fake Firestore.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

import 'learner_state_fixtures.dart';

const _crockford = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';

/// A valid ULID whose lexicographic order follows [n].
String seqUlid(int n) {
  final buffer = StringBuffer();
  var v = n;
  for (var i = 0; i < 16; i++) {
    buffer.write(_crockford[v & 31]);
    v >>= 5;
  }
  return '01ARZ3NDEK${buffer.toString().split('').reversed.join()}';
}

/// A valid stored learn-event map (Firestore form).
Map<String, Object?> storedLearnEvent(int n) => {
  'kind': 'learn',
  'curriculum_id': 'mishnayos',
  'ref': 'Mishnah Berakhot 1:${n + 1}',
  'source': 'main',
  'date_state': 'dated',
  'learned_on': '2026-09-01',
  'recorded_at': Timestamp.fromDate(t0),
  'actor': Map<String, Object?>.of(parentActorMap),
};

/// `users/{owner}/learner_profiles/{profile}/{collection}`.
CollectionReference<Map<String, dynamic>> profileCollection(
  FakeFirebaseFirestore firestore,
  String owner,
  String profile,
  String collection,
) => firestore
    .collection('users')
    .doc(owner)
    .collection('learner_profiles')
    .doc(profile)
    .collection(collection);

/// Seeds [count] learn events (ids `seqUlid(0..count-1)`).
Future<void> seedLearningEvents(
  FakeFirebaseFirestore firestore,
  String owner,
  String profile,
  int count, {
  int from = 0,
}) async {
  final events = profileCollection(
    firestore,
    owner,
    profile,
    'learning_events',
  );
  for (var i = from; i < from + count; i++) {
    await events.doc(seqUlid(i)).set(storedLearnEvent(i));
  }
}
