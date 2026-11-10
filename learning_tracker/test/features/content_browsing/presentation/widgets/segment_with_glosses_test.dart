import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/content_browsing/domain/entities/text_content.dart';
import 'package:learning_tracker/features/content_browsing/presentation/widgets/segment_with_glosses.dart';

void main() {
  testWidgets('strips nikud and renders glosses in their requested direction', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SegmentWithGlosses(
            segment: TextSegment(
              sefariaRef: 'Genesis 1:1',
              hebrewText: 'בְּרֵאשִׁית',
              englishText: 'In the beginning',
              number: 1,
            ),
            glosses: [
              const SegmentGloss(
                text: 'In the beginning',
                direction: TextDirection.ltr,
                style: TextStyle(),
              ),
            ],
            showNumber: false,
            showNikud: false,
            hebrewStyle: const TextStyle(),
          ),
        ),
      ),
    );

    final lines = tester.widgetList<RichText>(find.byType(RichText)).toList();
    expect(lines, hasLength(2));
    expect(lines.first.text.toPlainText(), 'בראשית');
    expect(lines.first.textDirection, TextDirection.rtl);
    expect(lines.last.text.toPlainText(), 'In the beginning');
    expect(lines.last.textDirection, TextDirection.ltr);
  });
}
