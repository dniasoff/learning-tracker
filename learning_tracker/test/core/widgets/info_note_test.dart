import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/widgets/info_note.dart';

import '../../helpers/pump_app.dart';

void main() {
  testWidgets('renders the info icon and one static sentence', (tester) async {
    await tester.pumpWidget(
      pumpApp(
        child: const Scaffold(body: InfoNote(text: 'A note.')),
      ),
    );
    expect(find.byIcon(Icons.info_outline), findsOneWidget);
    expect(find.text('A note.'), findsOneWidget);
    expect(find.byType(InkWell), findsNothing);
    expect(find.byType(TextButton), findsNothing);
  });

  testWidgets('renders an optional action under the sentence', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      pumpApp(
        child: Scaffold(
          body: InfoNote(
            text: 'A note.',
            action: TextButton(
              onPressed: () => tapped = true,
              child: const Text('Act'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Act'));
    expect(tapped, isTrue);
  });
}
