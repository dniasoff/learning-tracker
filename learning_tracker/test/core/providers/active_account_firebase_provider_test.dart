import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/providers/active_account_firebase_provider.dart';

void main() {
  test('exports the active account Firebase provider', () {
    expect(activeAccountFirebaseProvider, isNotNull);
  });
}
