// Story 4.3 (DNI-511) T1: the roster provider is account-scoped, re-reads
// the live grant set and keeps a failed read an error (AC-1, AC-6).
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/sub_tracks/domain/repositories/tutor_roster_repository.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/providers/talmid_roster_provider.dart';

import '../../talmidim_fixtures.dart';

void main() {
  ProviderContainer containerFor(
    ScriptedTutorRosterRepository repo, {
    String? account = 'tutor-uid',
  }) {
    final container = ProviderContainer(
      overrides: [
        tutorRosterRepositoryProvider.overrideWithValue(repo),
        talmidRosterAccountKeyProvider.overrideWithValue(account),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('a refresh drops a grant that is no longer active', () async {
    final repo = ScriptedTutorRosterRepository([
      [talmidEntry(1), talmidEntry(2)],
      [talmidEntry(1)],
    ]);
    final container = containerFor(repo);
    final sub = container.listen(talmidRosterProvider, (_, _) {});
    addTearDown(sub.close);

    expect(await container.read(talmidRosterProvider.future), hasLength(2));
    container.invalidate(talmidRosterProvider);
    expect(
      (await container.read(talmidRosterProvider.future)).map((e) => e.grantId),
      ['grant-1'],
    );
  });

  test('a failed read is an error, not an empty roster', () async {
    final repo = ScriptedTutorRosterRepository([
      const TutorRosterLoadException(),
    ]);
    final container = containerFor(repo);
    final sub = container.listen(talmidRosterProvider, (_, _) {});
    addTearDown(sub.close);

    await expectLater(
      container.read(talmidRosterProvider.future),
      throwsA(isA<TutorRosterLoadException>()),
    );
    expect(container.read(talmidRosterProvider).hasValue, isFalse);
  });

  test('an account switch re-reads the roster', () async {
    final repo = ScriptedTutorRosterRepository([
      [talmidEntry(1)],
      [talmidEntry(2)],
    ]);
    final container = ProviderContainer(
      overrides: [
        tutorRosterRepositoryProvider.overrideWithValue(repo),
        talmidRosterAccountKeyProvider.overrideWith(
          (ref) => ref.watch(_account),
        ),
      ],
    );
    addTearDown(container.dispose);
    final sub = container.listen(talmidRosterProvider, (_, _) {});
    addTearDown(sub.close);

    expect(
      (await container.read(talmidRosterProvider.future)).single.grantId,
      'grant-1',
    );
    container.read(_account.notifier).switchTo('other-tutor');
    expect(
      (await container.read(talmidRosterProvider.future)).single.grantId,
      'grant-2',
    );
    expect(repo.loads, 2);
  });
}

final _account = NotifierProvider<_Account, String?>(_Account.new);

class _Account extends Notifier<String?> {
  @override
  String? build() => 'tutor-uid';

  void switchTo(String? uid) => state = uid;
}
