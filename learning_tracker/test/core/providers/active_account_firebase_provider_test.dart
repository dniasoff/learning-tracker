import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/providers/active_account_firebase_provider.dart';

void main() {
  test('resolves to null when no account is active', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(await container.read(activeAccountFirebaseProvider.future), isNull);
  });
}
