import 'package:learning_tracker/features/progress/domain/models/journey_view_model.dart';
import 'package:test/test.dart';

void main() {
  group('JourneySortModeValue', () {
    test('toggle between grouped and chronological', () {
      var mode = JourneySortModeValue.grouped;

      // Toggle to chronological
      mode = mode == JourneySortModeValue.grouped
          ? JourneySortModeValue.chronological
          : JourneySortModeValue.grouped;
      expect(mode, JourneySortModeValue.chronological);

      // Toggle back to grouped
      mode = mode == JourneySortModeValue.grouped
          ? JourneySortModeValue.chronological
          : JourneySortModeValue.grouped;
      expect(mode, JourneySortModeValue.grouped);
    });
  });
}
