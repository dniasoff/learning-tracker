import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/scheduler/domain/models/delta_value.dart';
import 'package:learning_tracker/features/scheduler/domain/models/pace_status.dart';
import 'package:learning_tracker/features/scheduler/presentation/widgets/pace_indicator.dart';

void main() {
  Widget wrapWidget(Widget child) {
    return MaterialApp(home: Scaffold(body: child));
  }

  group('PaceIndicator', () {
    testWidgets('renders green indicator for ahead', (tester) async {
      final pace = PaceStatus(
        status: PaceStatusType.ahead,
        daysDelta: 5,
        delta: const DateScheduleDelta(DateDelta(5)),
        rollingAverage: 2.0,
        projectedCompletionDate: DateTime.utc(2026, 5, 1),
      );

      await tester.pumpWidget(wrapWidget(PaceIndicator(paceStatus: pace)));

      expect(find.text('+5 days ahead'), findsOneWidget);
      // Verify green color on the icon
      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.color, Colors.green);
    });

    testWidgets('renders yellow indicator for onPace', (tester) async {
      const pace = PaceStatus(
        status: PaceStatusType.onPace,
        daysDelta: 0,
        delta: DateScheduleDelta(DateDelta(0)),
        rollingAverage: 1.0,
      );

      await tester.pumpWidget(
        wrapWidget(const PaceIndicator(paceStatus: pace)),
      );

      expect(find.text('On pace'), findsOneWidget);
      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.color, Colors.amber);
    });

    testWidgets('renders red indicator for behind', (tester) async {
      const pace = PaceStatus(
        status: PaceStatusType.behind,
        daysDelta: -3,
        delta: DateScheduleDelta(DateDelta(-3)),
        rollingAverage: 0.5,
      );

      await tester.pumpWidget(
        wrapWidget(const PaceIndicator(paceStatus: pace)),
      );

      expect(find.text('3 days behind'), findsOneWidget);
      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.color, Colors.red);
    });
  });

  group('ProjectedCompletionText', () {
    testWidgets('displays projected date with qualifying text', (tester) async {
      final date = DateTime.utc(2026, 6, 15);
      await tester.pumpWidget(
        wrapWidget(ProjectedCompletionText(projectedDate: date)),
      );

      // MaterialLocalizations.formatMediumDate uses locale-aware formatting
      final localizations = MaterialLocalizations.of(
        tester.element(find.byType(ProjectedCompletionText)),
      );
      final formatted = localizations.formatMediumDate(date);
      expect(
        find.text("At current pace, you'll finish by $formatted"),
        findsOneWidget,
      );
    });

    testWidgets('renders nothing when projectedDate is null', (tester) async {
      await tester.pumpWidget(
        wrapWidget(const ProjectedCompletionText(projectedDate: null)),
      );

      expect(find.byType(SizedBox), findsOneWidget);
    });
  });
}
