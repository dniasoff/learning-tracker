// Story 2.9 (DNI-500) — the shared `Disabled action` primitive.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/widgets/sub_track_read_only.dart';

import '../../../../helpers/pump_app.dart';

void main() {
  testWidgets('40% opacity, disabled semantics, and a tap never reaches '
      'the enclosing row', (tester) async {
    final handle = tester.ensureSemantics();
    var rowTaps = 0;
    await tester.pumpWidget(
      pumpApp(
        child: Scaffold(
          body: InkWell(
            onTap: () => rowTaps++,
            child: const Padding(
              padding: EdgeInsets.all(40),
              child: SubTrackDisabledAction(
                child: TextButton(onPressed: null, child: Text('Go')),
              ),
            ),
          ),
        ),
      ),
    );
    final opacity = tester.widget<Opacity>(
      find.ancestor(of: find.text('Go'), matching: find.byType(Opacity)),
    );
    expect(opacity.opacity, 0.4);
    expect(
      tester.getSemantics(find.text('Go')),
      isSemantics(isButton: true, hasEnabledState: true, isEnabled: false),
    );
    await tester.tap(find.text('Go'));
    expect(rowTaps, 0);
    handle.dispose();
  });
}
