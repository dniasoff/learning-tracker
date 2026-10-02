// Mirror test for
// `lib/features/learning/domain/commands/learning_write_chunker.dart`
// (DNI-469 AC-3: ≤ 450 writes per chunk, event and pts_ never split).
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/ports/learning_write_port.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_write_chunker.dart';

import '../../../../helpers/learner_state/engine_fixtures.dart';

WriteUnit _paired(int n) {
  final e = engineLearn(n, 'Mishnah Berakhot 1:1');
  return WriteUnit(
    [e],
    [PointsAward(eventId: e.id, amount: 10, createdAt: engineAt(0))],
  );
}

WriteUnit _single(int n) => WriteUnit([engineVoid(n, 1)]);

void _expectSelfContained(List<LearningWriteChunk> chunks) {
  for (final c in chunks) {
    expect(c.events.length + c.awards.length, lessThanOrEqualTo(450));
    final ids = {for (final e in c.events) e.id};
    for (final a in c.awards) {
      expect(ids, contains(a.eventId));
    }
  }
}

void main() {
  test('empty input gives no chunks', () {
    expect(chunkWrites(const []), isEmpty);
  });

  test('1,000 paired events pack into 225-pair chunks of 450 writes', () {
    final chunks = chunkWrites([for (var i = 0; i < 1000; i++) _paired(i)]);
    expect(chunks.map((c) => c.events.length), [
      for (var i = 0; i < 4; i++) 225,
      100,
    ]);
    _expectSelfContained(chunks);
    expect(
      [for (final c in chunks) ...c.events.map((e) => e.id)],
      [for (var i = 0; i < 1000; i++) engineUlid(i)],
    );
  });

  test('a pair never straddles the 450-write boundary', () {
    // 449 single writes leave one slot: the next pair moves on whole.
    final chunks = chunkWrites([
      for (var i = 0; i < 449; i++) _single(i),
      _paired(1000),
    ]);
    expect(chunks, hasLength(2));
    expect(chunks.first.events, hasLength(449));
    expect(chunks.first.awards, isEmpty);
    expect(chunks.last.events.single.id, engineUlid(1000));
    expect(chunks.last.awards.single.eventId, engineUlid(1000));
    _expectSelfContained(chunks);
  });

  test('exactly 450 writes stay in one chunk; 451 split', () {
    expect(
      chunkWrites([for (var i = 0; i < 225; i++) _paired(i)]),
      hasLength(1),
    );
    expect(
      chunkWrites([for (var i = 0; i < 225; i++) _paired(i), _single(999)]),
      hasLength(2),
    );
  });

  test('a unit wider than a chunk splits per event, in order', () {
    final wide = WriteUnit([for (var i = 0; i < 460; i++) engineVoid(i, 5000)]);
    final chunks = chunkWrites([wide]);
    expect(chunks.map((c) => c.events.length), [450, 10]);
    expect(chunks.last.events.last.id, engineUlid(459));
  });

  test('a unit that fits is kept whole in the next chunk', () {
    final chunks = chunkWrites([
      for (var i = 0; i < 445; i++) _single(i),
      WriteUnit([for (var i = 0; i < 10; i++) engineVoid(2000 + i, 1)]),
    ]);
    expect(chunks.map((c) => c.events.length), [445, 10]);
  });

  test('WriteUnit counts events and awards', () {
    expect(_paired(1).writes, 2);
    expect(_single(1).writes, 1);
    expect(_single(1).events.single.kind, LearningEventKind.void_);
  });
}
