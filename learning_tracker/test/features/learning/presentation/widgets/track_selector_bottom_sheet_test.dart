import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/track_type.dart';
import 'package:learning_tracker/features/learning/presentation/widgets/track_selector_bottom_sheet.dart';

void main() {
  group('TrackSelectorBottomSheet', () {
    testWidgets('displays all active tracks', (tester) async {
      final activeTracks = [TrackType.personal, TrackType.school];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TrackSelectorBottomSheet(
              activeTracks: activeTracks,
              onTrackSelected: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('Select Track'), findsOneWidget);
      expect(find.text('Personal'), findsOneWidget);
      expect(find.text('School'), findsOneWidget);
      expect(find.text('Tutor'), findsNothing);
    });

    testWidgets('calls onTrackSelected when track is tapped', (tester) async {
      TrackType? selectedTrack;
      final activeTracks = [TrackType.personal, TrackType.school];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TrackSelectorBottomSheet(
              activeTracks: activeTracks,
              onTrackSelected: (track) => selectedTrack = track,
            ),
          ),
        ),
      );

      await tester.tap(find.text('School'));
      await tester.pumpAndSettle();

      expect(selectedTrack, TrackType.school);
    });

    testWidgets('shows correct icons for each track', (tester) async {
      final activeTracks = [
        TrackType.personal,
        TrackType.school,
        TrackType.tutor,
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TrackSelectorBottomSheet(
              activeTracks: activeTracks,
              onTrackSelected: (_) {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.person), findsOneWidget);
      expect(find.byIcon(Icons.school), findsOneWidget);
      expect(find.byIcon(Icons.groups), findsOneWidget);
    });

    testWidgets('static show method displays bottom sheet', (tester) async {
      final activeTracks = [TrackType.personal, TrackType.school];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  await TrackSelectorBottomSheet.show(
                    context: context,
                    activeTracks: activeTracks,
                  );
                },
                child: const Text('Show'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      expect(find.text('Select Track'), findsOneWidget);
      expect(find.text('Personal'), findsOneWidget);
      expect(find.text('School'), findsOneWidget);
    });

    testWidgets('returns selected track when tapped in modal', (tester) async {
      final activeTracks = [TrackType.personal, TrackType.school];
      TrackType? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await TrackSelectorBottomSheet.show(
                    context: context,
                    activeTracks: activeTracks,
                  );
                },
                child: const Text('Show'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('School'));
      await tester.pumpAndSettle();

      expect(result, TrackType.school);
    });
  });
}
