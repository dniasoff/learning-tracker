/// AD-54 chunking of a command's writes into self-contained batches.
library;

import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/ports/learning_write_port.dart';

/// A group of writes that should land in one batch: a capture's event
/// with its `pts_` award, a replacement with the void of its target, or an
/// un-learn's re-issues with the void of the node event they replace.
final class WriteUnit {
  /// Creates a unit. Every award's event must be in [events].
  WriteUnit(List<LearningEvent> events, [List<PointsAward> awards = const []])
    : events = List.unmodifiable(events),
      awards = List.unmodifiable(awards);

  /// The events, in write order.
  final List<LearningEvent> events;

  /// Their AD-50 awards.
  final List<PointsAward> awards;

  /// Documents written.
  int get writes => events.length + awards.length;
}

/// Packs [units] into chunks of at most [maxWrites] writes, in order.
///
/// A unit is never split while it fits in one chunk. A unit larger than a
/// chunk (only a very wide un-learn) is split per event, and an event and
/// its `pts_` award are NEVER separated (AD-54: each chunk is
/// self-contained). Empty input gives no chunks.
List<LearningWriteChunk> chunkWrites(
  List<WriteUnit> units, {
  int maxWrites = LearningWriteChunk.maxWrites,
}) {
  final chunks = <LearningWriteChunk>[];
  var events = <LearningEvent>[];
  var awards = <PointsAward>[];

  void flush() {
    if (events.isEmpty) return;
    chunks.add(LearningWriteChunk(events: events, awards: awards));
    events = [];
    awards = [];
  }

  void add(List<LearningEvent> e, List<PointsAward> a) {
    if (events.length + awards.length + e.length + a.length > maxWrites) {
      flush();
    }
    events.addAll(e);
    awards.addAll(a);
  }

  for (final unit in units) {
    if (unit.writes <= maxWrites) {
      add(unit.events, unit.awards);
      continue;
    }
    for (final event in unit.events) {
      add([event], [
        for (final award in unit.awards)
          if (award.eventId == event.id) award,
      ]);
    }
  }
  flush();
  return chunks;
}
