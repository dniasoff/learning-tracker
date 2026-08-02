import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/providers/active_profile_doc_id_provider.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart'
    as repository_providers;

/// This file exists purely to re-export `activeProfileDocIdProvider` for
/// `lib/features/**` call sites — see its class doc comment. The only
/// behavior worth asserting is that the export IS the same top-level
/// provider instance declared in `repository_providers.dart`, not a copy
/// (a mismatch here would silently split "which profile is active" into
/// two disconnected states).
void main() {
  test('activeProfileDocIdProvider re-exports the same provider instance as '
      'repository_providers.dart', () {
    expect(
      identical(
        activeProfileDocIdProvider,
        repository_providers.activeProfileDocIdProvider,
      ),
      isTrue,
    );
  });

  test('defaults to null and set() updates the shared provider', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(activeProfileDocIdProvider), isNull);

    container.read(activeProfileDocIdProvider.notifier).set('ulid-1');
    expect(container.read(activeProfileDocIdProvider), 'ulid-1');
    expect(
      container.read(repository_providers.activeProfileDocIdProvider),
      'ulid-1',
      reason: 'Reading through either import path must see the same state.',
    );

    container.read(activeProfileDocIdProvider.notifier).set(null);
    expect(container.read(activeProfileDocIdProvider), isNull);
  });
}
