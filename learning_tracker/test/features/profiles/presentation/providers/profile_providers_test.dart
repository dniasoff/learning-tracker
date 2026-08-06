import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/providers/active_profile_doc_id_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';

/// Covers only the NEW behavior added to [SelectedProfileId] — bridging a
/// Drift profile-id selection to a Firestore ULID via
/// [activeProfileDocIdProvider]. See `SelectedProfileId.select`'s own doc
/// comment (`profile_providers.dart`) for why this is a purely synchronous,
/// caller-supplied `ulid` parameter rather than an internal DB read: an
/// earlier version read `learner_profiles.ulid` back itself, which is
/// genuinely async and left dangling work behind whenever `select` was
/// called from a synchronous tap/callback context that never pumped for
/// it afterward — surfacing as "A Timer is still pending" in several
/// pre-existing widget tests across the app. The rest of
/// `profile_providers.dart` (self-heal, `profileList`, etc.) predates this
/// change and is intentionally left untouched here.
void main() {
  group('SelectedProfileId — activeProfileDocIdProvider wiring', () {
    late ProviderContainer container;

    setUp(() => container = ProviderContainer());
    tearDown(() => container.dispose());

    test('select() with a known ulid activates it synchronously — no '
        'pumping/awaiting required', () {
      container
          .read(selectedProfileIdProvider.notifier)
          .select(5, ulid: 'ulid-5');

      expect(container.read(selectedProfileIdProvider), 5);
      expect(container.read(activeProfileDocIdProvider), 'ulid-5');
    });

    test('clear() clears both selectedProfileIdProvider and '
        'activeProfileDocIdProvider', () {
      container
          .read(selectedProfileIdProvider.notifier)
          .select(1, ulid: 'ulid-1');
      expect(container.read(activeProfileDocIdProvider), 'ulid-1');

      container.read(selectedProfileIdProvider.notifier).clear();

      expect(container.read(selectedProfileIdProvider), isNull);
      expect(container.read(activeProfileDocIdProvider), isNull);
    });
  });
}
