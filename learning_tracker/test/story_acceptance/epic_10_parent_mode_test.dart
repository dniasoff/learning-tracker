/// Story acceptance coverage for Epic 10 — parent mode.
@Tags(['epic_10'])
library;

import 'package:learning_tracker/features/profiles/domain/services/pin_service.dart';
import 'package:test/test.dart';

import '../helpers/fake_secure_storage.dart';

void main() {
  group('Story 10.1 — parent PIN setup', tags: ['story_10_1'], () {
    test('PIN hashing and verification use device-local storage', () async {
      final storage = createMockStorage();
      final service = PinService(storage);
      await service.setParentPin('1234');
      expect(await storage.read(key: 'parent_pin_hash'), startsWith(r'$2'));
      expect(await service.verifyParentPin('1234'), isTrue);
      expect(await service.verifyParentPin('0000'), isFalse);
    });

    test('five failed attempts trigger lockout', () async {
      final storage = createMockStorage();
      final service = PinService(storage);
      await service.setParentPin('1234');
      for (var i = 0; i < 5; i++) {
        await service.verifyParentPin('0000');
      }
      expect(
        () => service.verifyParentPin('1234'),
        throwsA(isA<PinLockoutException>()),
      );
    });
  });

  group('Story 10.2 — parent dashboard', tags: ['story_10_2'], skip:
      'Blocked: dashboard aggregation and points services in this acceptance flow still read Drift DAOs; the Firestore adapters are not wired into these services.',
      () {
    test('placeholder for the pending Firestore parent-dashboard seam', () {});
  });

  group('Story 10.4 — point configuration', tags: ['story_10_4'], skip:
      'Blocked: point configuration screen tests still require the Drift userDatabaseProvider; Firestore point-config wiring is not exposed here.',
      () {
    test('placeholder for the pending Firestore point-config seam', () {});
  });
}
