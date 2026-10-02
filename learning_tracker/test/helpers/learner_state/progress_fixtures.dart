/// Shared fixtures for the LearnerState-backed progress readers (DNI-474):
/// a small Mishnayos ContentIndex (the same leaf refs as
/// `engine_fixtures.dart`'s corpus), its corpus through the production
/// `contentIndexCorpus` adapter, real engine states over it, and the
/// provider overrides that wire them into a container or `pumpApp`.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override, ProviderListenable;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/content/content_index_corpus.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/network/sefaria/models/curriculum_hierarchy_config.dart';
import 'package:learning_tracker/domain/learner_state/change_log_entry.dart';
import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/learner_state_engine.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/main_track_intent.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/learner_state/presentation/providers/learner_state_provider.dart';
import 'package:learning_tracker/features/settings/presentation/providers/curriculum_scope_providers.dart';

import 'c0_fixtures.dart';
import 'engine_fixtures.dart';
import 'learner_state_overrides.dart';

/// The fixture hierarchy labels.
const progressLevelLabels = ['Seder', 'Masechta', 'Perek', 'Mishna'];

ContentItem _item(
  int order,
  String ref, {
  required String l1,
  String? l2,
  String? l3,
  String? l4,
  bool leaf = false,
  String? he,
}) => ContentItem(
  curriculumId: engineCurriculum,
  level1: l1,
  level2: l2,
  level3: l3,
  level4: l4,
  displayNameHe: he ?? 'he:$ref',
  displayNameEn: ref,
  sefariaRef: ref,
  sortOrder: order,
  isLeaf: leaf,
);

/// The fixture Mishnayos content, in ContentIndex order:
///
/// * Zeraim (Seder Zeraim)
///   * Berakhot: perek 1 (1:1, 1:2, 1:3), perek 2 (2:1, 2:2)
///   * Peah: perek 1 (1:1, 1:2)
/// * Moed (Seder Moed)
///   * Shabbat: perek 1 (1:1, 1:2)
///
/// Masechet containers' refs equal their `level2`, so the production
/// adapter yields the siyum levels `[seder, masechta]`.
List<ContentItem> progressContent() {
  var order = 0;
  ContentItem leaf(String l1, String l2, String l3, String l4, String ref) =>
      _item(++order, ref, l1: l1, l2: l2, l3: l3, l4: l4, leaf: true);
  return [
    _item(++order, 'Seder Zeraim', l1: 'Zeraim'),
    _item(++order, 'Mishnah Berakhot', l1: 'Zeraim', l2: 'Mishnah Berakhot'),
    _item(
      ++order,
      'Mishnah Berakhot 1',
      l1: 'Zeraim',
      l2: 'Mishnah Berakhot',
      l3: '1',
    ),
    leaf('Zeraim', 'Mishnah Berakhot', '1', '1', 'Mishnah Berakhot 1:1'),
    leaf('Zeraim', 'Mishnah Berakhot', '1', '2', 'Mishnah Berakhot 1:2'),
    leaf('Zeraim', 'Mishnah Berakhot', '1', '3', 'Mishnah Berakhot 1:3'),
    _item(
      ++order,
      'Mishnah Berakhot 2',
      l1: 'Zeraim',
      l2: 'Mishnah Berakhot',
      l3: '2',
    ),
    leaf('Zeraim', 'Mishnah Berakhot', '2', '1', 'Mishnah Berakhot 2:1'),
    leaf('Zeraim', 'Mishnah Berakhot', '2', '2', 'Mishnah Berakhot 2:2'),
    _item(++order, 'Mishnah Peah', l1: 'Zeraim', l2: 'Mishnah Peah'),
    _item(++order, 'Mishnah Peah 1', l1: 'Zeraim', l2: 'Mishnah Peah', l3: '1'),
    leaf('Zeraim', 'Mishnah Peah', '1', '1', 'Mishnah Peah 1:1'),
    leaf('Zeraim', 'Mishnah Peah', '1', '2', 'Mishnah Peah 1:2'),
    _item(++order, 'Seder Moed', l1: 'Moed'),
    _item(++order, 'Mishnah Shabbat', l1: 'Moed', l2: 'Mishnah Shabbat'),
    _item(
      ++order,
      'Mishnah Shabbat 1',
      l1: 'Moed',
      l2: 'Mishnah Shabbat',
      l3: '1',
    ),
    leaf('Moed', 'Mishnah Shabbat', '1', '1', 'Mishnah Shabbat 1:1'),
    leaf('Moed', 'Mishnah Shabbat', '1', '2', 'Mishnah Shabbat 1:2'),
  ];
}

/// The fixture corpus through the production adapter.
Corpus progressCorpus() => contentIndexCorpus(
  curriculumId: engineCurriculum,
  items: progressContent(),
  levelLabels: progressLevelLabels,
);

/// A `learn` event of [ref] at [minutes] learnt on [learnedOn].
LearningEvent progressLearn(
  int id,
  String ref, {
  int minutes = 0,
  String learnedOn = '2026-09-01',
  DateState dateState = DateState.dated,
  int? stage,
}) => engineLearn(
  id,
  ref,
  minutes: minutes,
  learnedOn: learnedOn,
  dateState: dateState,
  stage: stage,
);

/// A `before_tracking` node event over [nodeRef] at [level].
LearningEvent progressGround(
  int id,
  String nodeRef,
  String level, {
  int minutes = 0,
}) => engineLearn(
  id,
  nodeRef,
  level: level,
  dateState: DateState.beforeTracking,
  minutes: minutes,
);

/// The real engine's state over the fixture corpus for [events].
LearnerState progressState(
  List<LearningEvent> events, {
  List<ChangeLogEntry> intentHistory = const [],
  Map<String, MainTrackIntent>? intents,
  DateTime? nowUtc,
}) => const LearnerStateEngine().run(
  engineInputs(
    events: events,
    corpora: {engineCurriculum: progressCorpus()},
    intentHistory: intentHistory,
    intents: intents,
    nowUtc: nowUtc,
  ),
);

/// A [ContentRepository] serving [progressContent] for Mishnayos and no
/// content for every other curriculum.
final class FixtureContentRepository implements ContentRepository {
  /// Creates the repository.
  FixtureContentRepository({List<ContentItem>? items})
    : items = items ?? progressContent();

  /// The Mishnayos items.
  final List<ContentItem> items;

  List<ContentItem> _of(CurriculumId c) =>
      c == CurriculumId.mishnayos ? items : const [];

  @override
  Future<List<ContentItem>> getContentForCurriculum(CurriculumId c) async =>
      _of(c);

  @override
  Future<CurriculumHierarchyConfig> getHierarchyConfig(CurriculumId c) async =>
      CurriculumHierarchyConfig(
        curriculumId: c.storageKey,
        levelLabels: progressLevelLabels,
        totalItems: _of(c).where((i) => i.isLeaf).length,
      );

  @override
  Future<ContentItem?> getContentByRef({
    required CurriculumId curriculumId,
    required String sefariaRef,
  }) async {
    for (final item in _of(curriculumId)) {
      if (item.sefariaRef == sefariaRef) return item;
    }
    return null;
  }

  @override
  Future<List<ContentItem>> filterByLevel({
    required CurriculumId curriculumId,
    String? level1,
    String? level2,
    String? level3,
    String? level4,
  }) async => [
    for (final i in _of(curriculumId))
      if ((level1 == null || i.level1 == level1) &&
          (level2 == null || i.level2 == level2) &&
          (level3 == null || i.level3 == level3) &&
          (level4 == null || i.level4 == level4))
        i,
  ];

  @override
  Future<List<ContentItem>> getScopedContent({
    required CurriculumId curriculumId,
    required int scopeLevel,
    required List<String> scopeValues,
  }) async => _of(curriculumId);

  @override
  Future<List<ContentItem>> search({
    required CurriculumId curriculumId,
    required String query,
  }) async => const [];
}

/// Overrides wiring [state] (the active learner's state) and the fixture
/// content/corpus into a container or `pumpApp`.
///
/// [states], when given, drives the learner state instead of [state].
/// [state] null with [learner] true keeps the state loading; [learner]
/// false models no active learner (`activeLearnerStateProvider` is
/// `AsyncData(null)`).
List<Override> progressOverrides(
  LearnerState? state, {
  List<ContentItem>? items,
  bool learner = true,
  Stream<LearnerState>? states,
}) {
  final content = items ?? progressContent();
  final corpus = contentIndexCorpus(
    curriculumId: engineCurriculum,
    items: content,
    levelLabels: progressLevelLabels,
  );
  return [
    ...learnerStateOverrides(scope: learner ? c0Scope() : null, state: state),
    if (states != null)
      learnerStateProvider.overrideWith((ref, _) => states)
    else if (state == null && learner)
      learnerStateProvider.overrideWith((ref, _) => const Stream.empty()),
    corporaProvider.overrideWith(
      (ref) async => <String, Corpus>{engineCurriculum: corpus},
    ),
    contentRepositoryProvider.overrideWithValue(
      FixtureContentRepository(items: content),
    ),
    scopedCurriculumContentProvider.overrideWith(
      (ref, c) async => c == CurriculumId.mishnayos ? content : const [],
    ),
  ];
}

/// Reads an (auto-dispose) async provider's future while keeping it
/// listened to until the test ends, so it is not disposed mid-await.
Future<T> readFuture<T>(
  ProviderContainer container,
  ProviderListenable<Future<T>> provider,
) {
  final sub = container.listen(provider, (_, _) {});
  addTearDown(sub.close);
  return sub.read();
}
