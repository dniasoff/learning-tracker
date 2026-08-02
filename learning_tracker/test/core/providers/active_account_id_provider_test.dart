import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/providers/active_account_id_provider.dart';
import 'package:learning_tracker/data/firestore/active_account_providers.dart'
    as active_account_providers;

/// This file exists purely to re-export `activeAccountIdProvider` for
/// `lib/features/**` call sites, which cannot import
/// `package:learning_tracker/data/firestore/...` directly (audit check 102,
/// AD-23/AD-28) — see its library doc comment.
///
/// The only behavior worth asserting is that the export IS the same top-level
/// provider instance declared in `active_account_providers.dart`, not a copy.
/// A mismatch would silently split "which account is active" into two
/// disconnected states: the seventeen feature call sites would write one
/// provider while `repository_providers.dart` read the other, and every
/// Firestore repository would resolve `null` forever with nothing failing.
void main() {
  test('activeAccountIdProvider re-exports the same provider instance as '
      'active_account_providers.dart', () {
    expect(
      identical(
        activeAccountIdProvider,
        active_account_providers.activeAccountIdProvider,
      ),
      isTrue,
    );
  });

  test('defaults to null and set() updates the shared provider', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(activeAccountIdProvider), isNull);

    container.read(activeAccountIdProvider.notifier).set('account-uuid-1');
    expect(container.read(activeAccountIdProvider), 'account-uuid-1');
    expect(
      container.read(active_account_providers.activeAccountIdProvider),
      'account-uuid-1',
      reason: 'Reading through either import path must see the same state.',
    );

    // Reset-to-default maps to real null here, unlike AccountDbFileName whose
    // rest state is the literal string 'learning_tracker'.
    container.read(activeAccountIdProvider.notifier).set(null);
    expect(container.read(activeAccountIdProvider), isNull);
    expect(
      container.read(active_account_providers.activeAccountIdProvider),
      isNull,
    );
  });
}
