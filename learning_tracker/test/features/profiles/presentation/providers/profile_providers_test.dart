import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/providers/active_profile_doc_id_provider.dart';
import 'package:learning_tracker/features/profiles/data/repositories/profile_repository_impl.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';

/// Covers only the NEW behavior added to [SelectedProfileId] — bridging a
/// Drift profile-id selection to its cached Firestore ULID via
/// [activeProfileDocIdProvider] (see [ProfileUlidSessionCache]'s doc comment
/// in `profile_repository_impl.dart` for the "why a session cache" reasoning
/// this leans on). The rest of `profile_providers.dart` (self-heal,
/// `profileList`, etc.) predates this change and is intentionally left
/// untouched here.
void main() {
  group('SelectedProfileId — activeProfileDocIdProvider wiring', () {
    test(
      'select() activates the session-cached ULID for a known profile id',
      () {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        container
            .read(profileUlidSessionCacheProvider.notifier)
            .put(5, 'ulid-5');

        container.read(selectedProfileIdProvider.notifier).select(5);

        expect(container.read(selectedProfileIdProvider), 5);
        expect(container.read(activeProfileDocIdProvider), 'ulid-5');
      },
    );

    test('select() clears activeProfileDocIdProvider for a profile with no '
        'known ULID this session — accurate, not a regression (see class doc '
        'comment: nothing here invents an identity)', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(activeProfileDocIdProvider.notifier).set('stale-ulid');

      container.read(selectedProfileIdProvider.notifier).select(99);

      expect(container.read(activeProfileDocIdProvider), isNull);
    });

    test('clear() clears both selectedProfileIdProvider and '
        'activeProfileDocIdProvider', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(profileUlidSessionCacheProvider.notifier).put(1, 'ulid-1');
      container.read(selectedProfileIdProvider.notifier).select(1);
      expect(container.read(activeProfileDocIdProvider), 'ulid-1');

      container.read(selectedProfileIdProvider.notifier).clear();

      expect(container.read(selectedProfileIdProvider), isNull);
      expect(container.read(activeProfileDocIdProvider), isNull);
    });
  });
}
