// Story 1.11 (DNI-473) AC-2: the onboarding bulk mark and the settings
// Lifetime Marking screen write `before_tracking` learning events (R10: the
// retired 2000-01-01 sentinel) through the real `DefaultLearningCommands`:
// `date_state = before_tracking`, `learned_on` null, a whole node marked is
// one node event carrying its `level`, and no pts_ entry.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/content/content_index_corpus.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/network/sefaria/models/curriculum_hierarchy_config.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/domain/learner_state/actor.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_gate.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_commands.dart';
import 'package:learning_tracker/features/learning/domain/entities/bookmark.dart';
import 'package:learning_tracker/features/learning/domain/entities/learning_ledger_entry.dart';
import 'package:learning_tracker/features/learning/domain/repositories/bookmark_repository.dart';
import 'package:learning_tracker/features/learning/presentation/providers/learning_ledger_providers.dart';
import 'package:learning_tracker/features/onboarding/domain/services/before_tracking_recorder.dart';
import 'package:learning_tracker/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:learning_tracker/features/onboarding/presentation/screens/bulk_mark_screen.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/settings/presentation/screens/lifetime_marking_screen.dart';

import '../../../../helpers/learner_state/c0_fixtures.dart';
import '../../../../helpers/learner_state/engine_fixtures.dart';
import '../../../../helpers/learner_state/fake_learning_commands.dart';
import '../../../../helpers/learner_state/in_memory_ports.dart';
import '../../../../helpers/pump_app.dart';

const _m = CurriculumId.mishnayos;
const _profileId = '01JQ8M9Y7V3K2N6P4R5T8W0X1Z';

ContentItem _item(
  String ref,
  int order,
  String l1, {
  String? l2,
  bool leaf = false,
}) => ContentItem(
  curriculumId: 'mishnayos',
  level1: l1,
  level2: l2,
  displayNameHe: ref,
  displayNameEn: ref,
  sefariaRef: ref,
  sortOrder: order,
  isLeaf: leaf,
);

/// Two sedarim: Zeraim (two leaves) and Moed (one leaf).
final _items = [
  _item('Seder Zeraim', 0, 'Zeraim'),
  _item('Mishnah Berakhot 1:1', 1, 'Zeraim', l2: 'Berakhot', leaf: true),
  _item('Mishnah Peah 1:1', 2, 'Zeraim', l2: 'Peah', leaf: true),
  _item('Seder Moed', 3, 'Moed'),
  _item('Mishnah Shabbat 1:1', 4, 'Moed', l2: 'Shabbat', leaf: true),
];

final _sederLevel = contentLevelName(CurriculumLabels.labelsEn(_m), 1);

class _Content implements ContentRepository {
  @override
  Future<List<ContentItem>> getContentForCurriculum(CurriculumId id) async =>
      id == _m ? _items : const [];

  @override
  Future<CurriculumHierarchyConfig> getHierarchyConfig(CurriculumId id) async =>
      CurriculumHierarchyConfig(
        curriculumId: id.storageKey,
        levelLabels: const ['Seder', 'Masechta'],
        totalItems: _items.length,
      );

  @override
  Future<List<ContentItem>> filterByLevel({
    required CurriculumId curriculumId,
    String? level1,
    String? level2,
    String? level3,
    String? level4,
  }) async => _items;

  @override
  Future<List<ContentItem>> getScopedContent({
    required CurriculumId curriculumId,
    required int scopeLevel,
    required List<String> scopeValues,
  }) async => _items;

  @override
  Future<List<ContentItem>> search({
    required CurriculumId curriculumId,
    required String query,
  }) async => const [];

  @override
  Future<ContentItem?> getContentByRef({
    required CurriculumId curriculumId,
    required String sefariaRef,
  }) async => null;
}

class _Bookmarks extends Fake implements BookmarkRepository {
  @override
  Future<BookmarkEntity> setBookmark({
    required CurriculumId curriculumId,
    required String sefariaRef,
  }) async => BookmarkEntity(
    curriculumId: curriculumId,
    sefariaRef: sefariaRef,
    updatedAt: DateTime.utc(2026, 9, 1),
  );
}

class _UseHebrewTermsOff extends UseHebrewTerms {
  @override
  bool build() => false;
}

class _ActiveProfile extends ActiveProfileId {
  @override
  String build() => _profileId;
}

final class _Capture {
  _Capture() {
    var seq = 50000;
    commands = DefaultLearningCommands(
      scope: c0Scope(),
      actor: const Actor(
        uid: 'owner-uid',
        role: ActorRole.parent,
        displayName: '',
      ),
      reads: FakeLearningCommandReads(history: c0SettingsHistory()),
      writePort: port,
      gate: const LockWindowCaptureGate(),
      analytics: RecordingLearningAnalytics(),
      failureReporter: RecordingLearningFailureReporter(),
      clock: () => engineAt(600),
      newUlid: (_) => engineUlid(seq++),
      ackWait: const Duration(milliseconds: 40),
      pointsWait: const Duration(milliseconds: 40),
    );
    recorder = BeforeTrackingRecorder(
      contentRepository: content,
      bookmarkRepository: _Bookmarks(),
      commands: () async => commands,
      events: () async => const [],
    );
  }

  final port = InMemoryLearningWritePort();
  final content = _Content();
  late final DefaultLearningCommands commands;
  late final BeforeTrackingRecorder recorder;

  List<LearningEvent> get written => [for (final c in port.chunks) ...c.events];

  void expectBeforeTracking() {
    expect(written, isNotEmpty);
    for (final e in written) {
      final stored = e.toStorage();
      expect(stored['date_state'], 'before_tracking');
      expect(stored['learned_on'], isNull);
      expect(stored['source'], 'main');
    }
    expect([for (final c in port.chunks) ...c.awards], isEmpty);
  }
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

void main() {
  testWidgets('onboarding bulk mark: a ticked seder is ONE before_tracking '
      'node event with its level and no learned_on', (tester) async {
    final flow = _Capture();
    addTearDown(flow.commands.dispose);
    await tester.pumpWidget(
      pumpApp(
        overrides: [
          contentRepositoryProvider.overrideWithValue(flow.content),
          curriculumContentProvider.overrideWith(
            (ref, id) => flow.content.getContentForCurriculum(id),
          ),
          contentSearchProvider.overrideWith((ref, args) => Future.value([])),
          beforeTrackingRecorderProvider.overrideWithValue(flow.recorder),
          useHebrewTermsProvider.overrideWith(_UseHebrewTermsOff.new),
        ],
        child: const BulkMarkScreen(curriculumId: _m),
      ),
    );
    await _settle(tester);

    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();
    await tester.tap(find.text('Next'));
    await _settle(tester);
    await tester.tap(find.text('Confirm'));
    await _settle(tester);

    flow.expectBeforeTracking();
    final event = flow.written.single;
    expect(event.ref, 'Seder Zeraim');
    expect(event.level, _sederLevel);
  });

  testWidgets('settings Lifetime Marking: Save writes before_tracking node '
      'events carrying their level, one capture, nothing to the ledger', (
    tester,
  ) async {
    final flow = _Capture();
    addTearDown(flow.commands.dispose);
    await tester.pumpWidget(
      pumpApp(
        overrides: [
          activeProfileIdProvider.overrideWith(_ActiveProfile.new),
          contentRepositoryProvider.overrideWithValue(flow.content),
          curriculumLedgerProvider.overrideWith(
            (ref, id) async => const <LearningLedgerEntry>[],
          ),
          useHebrewTermsProvider.overrideWith(_UseHebrewTermsOff.new),
          beforeTrackingRecorderProvider.overrideWithValue(flow.recorder),
        ],
        child: const LifetimeCurriculumMarkingScreen(curriculumId: 'mishnayos'),
      ),
    );
    await _settle(tester);

    await tester.tap(find.text('Select all in this list'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await _settle(tester);

    flow.expectBeforeTracking();
    expect(flow.port.chunks, hasLength(1), reason: 'one capture');
    expect(flow.written.map((e) => (e.ref, e.level)), [
      ('Seder Zeraim', _sederLevel),
      ('Seder Moed', _sederLevel),
    ]);
  });
}
