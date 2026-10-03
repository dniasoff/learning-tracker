// Mirror test for `lib/features/sub_tracks/domain/sub_track_detail.dart`
// (DNI-497): the detail reads the engine's values as-is and gates edits
// and the shortfall by role.
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/features/sub_tracks/domain/sub_track_detail.dart';
import 'package:learning_tracker/features/sub_tracks/domain/sub_track_ground_projection.dart';

import '../../../helpers/learner_state/engine_fixtures.dart';
import '../sub_track_detail_harness.dart';

SubTrackDetail _detail({
  SubTrackDetailRole role = SubTrackDetailRole.parent,
  SubTrack? track,
  int? capacity,
  bool noDeadline = true,
  bool holdsGround = true,
  bool writesBlocked = false,
}) {
  final t = track ?? detailSubTrack(10, 'School', const [peah]);
  return SubTrackDetail(
    track: t,
    role: role,
    noDeadline: noDeadline,
    writesBlocked: writesBlocked,
    state: SubTrackState(
      subTrackId: t.id,
      holdsGround: holdsGround,
      inForecast: holdsGround,
      onHome: holdsGround,
      position: 'Mishnah Peah 1:2',
      ticked: 1,
      remainingPath: const ['Mishnah Peah 1:2'],
      capacity: capacity,
      shortfall: 4,
    ),
    ground: SubTrackGroundProjection.project(
      track: t,
      ground: t.ground,
      corpus: mishnayosCorpus(),
      learntLeaves: const {},
      countedLearns: const [],
      subTracks: [t],
      holdsGround: (_) => true,
    ),
  );
}

void main() {
  test('reads the engine values unchanged', () {
    final d = _detail(capacity: 9, noDeadline: false);
    expect(d.upNext, 'Mishnah Peah 1:2');
    expect(d.ticked, 1);
    expect(d.remainingPath, 1);
    expect(d.capacity, 9);
    expect(d.shortfall, 4);
    expect(d.hasCapacity, isTrue);
    expect(d.noDeadline, isFalse);
  });

  test('no engine capacity: nothing to draw', () {
    expect(_detail().hasCapacity, isFalse);
  });

  test('the parent and the tutor edit, never the child nor an ended '
      'sub-track; a blocked tutor sees the controls disabled (Story 4.2)', () {
    expect(_detail().canEdit, isTrue);
    expect(_detail().canWrite, isTrue);
    expect(_detail(role: SubTrackDetailRole.child).canEdit, isFalse);
    expect(_detail(role: SubTrackDetailRole.tutor).canEdit, isTrue);
    expect(_detail(role: SubTrackDetailRole.tutor).canWrite, isTrue);
    final blocked = _detail(
      role: SubTrackDetailRole.tutor,
      writesBlocked: true,
    );
    expect(blocked.canEdit, isTrue, reason: 'visible');
    expect(blocked.canWrite, isFalse, reason: 'disabled');
    final ended = detailSubTrack(11, 'Old', const [peah], ended: true);
    expect(_detail(track: ended).canEdit, isFalse);
  });

  test('DNI-499 AC-5: a sub-track whose window passed (no tombstone) is '
      'ended and read-only for the parent too', () {
    final elapsed = detailSubTrack(12, 'Last year', const [
      peah,
    ], windowEnd: '2026-07-31');
    final d = _detail(track: elapsed, holdsGround: false);
    expect(elapsed.isEnded, isFalse, reason: 'no ended_at is ever written');
    expect(d.isEnded, isTrue);
    expect(d.canEdit, isFalse);
    expect(_detail().isEnded, isFalse);
    final tombstoned = detailSubTrack(11, 'Old', const [peah], ended: true);
    expect(_detail(track: tombstoned).isEnded, isTrue);
  });

  test('the shortfall is never shown to the child', () {
    expect(_detail().showsShortfall, isTrue);
    expect(_detail(role: SubTrackDetailRole.tutor).showsShortfall, isTrue);
    expect(_detail(role: SubTrackDetailRole.child).showsShortfall, isFalse);
  });
}
