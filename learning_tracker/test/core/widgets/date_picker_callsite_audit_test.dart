import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Material date picker calls stay inside the shared helper', () {
    final pickerCall = RegExp(
      r'\b(?:showDatePicker|showDateRangePicker|DatePickerDialog|DateRangePickerDialog)\s*\(',
    );
    final sources = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));
    final matches = <String>[];

    for (final source in sources) {
      final content = source.readAsStringSync();
      if (!pickerCall.hasMatch(content)) continue;
      if (source.path != 'lib/core/widgets/learning_date_picker_theme.dart') {
        matches.add(source.path);
      }
    }

    expect(matches, isEmpty, reason: 'Use the shared date-picker helpers.');
  });
}
