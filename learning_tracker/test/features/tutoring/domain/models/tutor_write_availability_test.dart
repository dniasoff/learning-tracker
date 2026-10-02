// Story 1.24 (DNI-486) — only an owner session or an available tutor may
// use a write control; every blocked tutor state shows it disabled.

@Tags(['tutor_mode'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_write_availability.dart';

void main() {
  test('allowsWrite / blocksTutor', () {
    const allowed = {
      TutorWriteAvailability.owner,
      TutorWriteAvailability.available,
    };
    for (final a in TutorWriteAvailability.values) {
      expect(a.allowsWrite, allowed.contains(a), reason: a.name);
      expect(a.blocksTutor, !allowed.contains(a), reason: a.name);
    }
  });
}
