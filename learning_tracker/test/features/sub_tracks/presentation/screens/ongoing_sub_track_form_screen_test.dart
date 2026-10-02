// DNI-496 (Story 2.5): the screen's entry point and constants. The form's
// acceptance coverage is test/features/sub_tracks/presentation/
// ongoing_sub_track_form_test.dart (the story's named suite).
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/screens/ongoing_sub_track_form_screen.dart';

void main() {
  test('the new-form rate and the tablet breakpoint', () {
    expect(kOngoingDefaultRatePerWeek, 5);
    expect(kOngoingFormTabletBreakpoint, 600);
  });

  test('a save outcome defaults to an acknowledged write', () {
    const saved = OngoingSubTrackSaved();
    expect(saved.queued, isFalse);
    expect(saved.changeIds, isEmpty);
  });
}
