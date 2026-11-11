import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/social/domain/social_summary_visibility.dart';

void main() {
  test('all-on default enables every follower-visible section', () {
    expect(const SocialSummaryVisibility.allOn().toWire(), {
      'overallStreak': true,
      'overallWeekly': true,
      'perTrackStreaks': true,
      'perTrackWeekly': true,
      'currentTracks': true,
      'siyumim': true,
    });
  });

  test(
    'wire choices round-trip and copyWith changes only selected choices',
    () {
      const choices = SocialSummaryVisibility.allOn();
      final hidden = choices.copyWith(overallStreak: false, siyumim: false);

      expect(
        SocialSummaryVisibility.fromWire(hidden.toWire()).toWire(),
        hidden.toWire(),
      );
      expect(hidden.overallStreak, isFalse);
      expect(hidden.siyumim, isFalse);
      expect(hidden.overallWeekly, isTrue);
      expect(hidden.perTrackStreaks, isTrue);
      expect(hidden.perTrackWeekly, isTrue);
      expect(hidden.currentTracks, isTrue);
    },
  );

  test('rejects missing, unknown, or non-boolean choices', () {
    expect(
      () => SocialSummaryVisibility.fromWire({'overallStreak': true}),
      throwsFormatException,
    );
    expect(
      () => SocialSummaryVisibility.fromWire({
        ...const SocialSummaryVisibility.allOn().toWire(),
        'points': true,
      }),
      throwsFormatException,
    );
    expect(
      () => SocialSummaryVisibility.fromWire({
        ...const SocialSummaryVisibility.allOn().toWire(),
        'siyumim': 'yes',
      }),
      throwsFormatException,
    );
  });
}
