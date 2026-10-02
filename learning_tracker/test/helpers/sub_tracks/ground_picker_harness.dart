/// Shared rig for the Story 2.7 (DNI-498) ground-picker widget tests: the
/// picker's C0 seams (`corporaProvider`, `learnerStateProvider`,
/// `learningCommandsProvider`) and repositories over in-memory fakes, plus
/// the session, labels and preferences it reads.
library;

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:learning_tracker/app/router/app_router.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/content/content_index.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/navigation/guards/child_mode_guard.dart';
import 'package:learning_tracker/core/navigation/guards/parent_session_guard.dart';
import 'package:learning_tracker/core/navigation/guards/pin_guard.dart';
import 'package:learning_tracker/core/navigation/guards/profile_guard.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/data/firestore/learner_state_repository_providers.dart';
import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/main_track_intent.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/domain/learner_state/ports/governed_intent_repository.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/features/learner_state/presentation/providers/learner_state_provider.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_commands.dart';
import 'package:learning_tracker/features/learning/presentation/providers/learning_command_providers.dart';
import 'package:learning_tracker/features/profiles/domain/services/pin_service.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/parent_session_provider.dart';
import 'package:mocktail/mocktail.dart';

import '../learner_state/c0_fixtures.dart';
import '../learner_state/fake_learner_state.dart';
import '../learner_state/in_memory_ports.dart';
import '../learner_state_fixtures.dart';

/// The receiving sub-track's id.
const schoolId = ulidA;

/// Another holding sub-track's id.
const rebbeId = ulidB;

/// A fixture sub-track of [curriculumId].
SubTrack fixtureTrack(
  String id,
  String name, {
  required String curriculumId,
  List<NodeEntry> ground = const [],
  bool ended = false,
  String? windowEnd,
}) => SubTrack(
  id: id,
  curriculumId: curriculumId,
  name: name,
  type: SubTrackType.ongoing,
  windowStart: '2026-09-01',
  windowEnd: windowEnd,
  ratePerWeek: 10,
  weeksPerYear: 39,
  learnsOnShabbos: false,
  ground: ground,
  lastChangeId: ulidE,
  endedAt: ended ? t1 : null,
  endReason: ended ? SubTrackEndReason.ended : null,
);

/// ContentIndex rows for a [Corpus] fixture: one item per node, with
/// English names the refs and the given Hebrew names (or the refs).
List<ContentItem> contentItemsOf(
  Corpus corpus, {
  Map<String, String> hebrew = const {},
}) {
  final items = <ContentItem>[];
  var order = 0;
  void walk(NodeEntry node, List<String> path) {
    final here = [...path, node.ref];
    items.add(
      ContentItem(
        curriculumId: corpus.curriculumId,
        level1: here[0],
        level2: here.length > 1 ? here[1] : null,
        level3: here.length > 2 ? here[2] : null,
        level4: here.length > 3 ? here[3] : null,
        displayNameHe: hebrew[node.ref] ?? node.ref,
        displayNameEn: node.ref,
        sefariaRef: node.ref,
        sortOrder: order++,
        isLeaf: corpus.isLeaf(node),
      ),
    );
    for (final child in corpus.childrenOf(node)) {
      walk(child, here);
    }
  }

  corpus.roots.forEach((r) => walk(r, const []));
  return items;
}

/// The picker's world for one test: the stored sub-tracks, the corpus, the
/// learner state and the commands.
final class GroundPickerWorld {
  /// Creates the world over [corpus].
  GroundPickerWorld({
    required this.corpus,
    List<SubTrack> tracks = const [],
    Set<LeafRef> learnt = const {},
    Map<String, SubTrackState>? subTrackStates,
    this.parent = true,
    this.calendarProgram = false,
    this.commands,
    this.commandsOverride,
    this.labelItems,
    this.stateStream,
  }) : scope = c0Scope() {
    subTracks.seed(scope, tracks);
    intent.emit(scope, _intent());
    state = fakeLearnerState(
      curricula: {
        corpus.curriculumId: FakeCurriculumState(
          curriculumId: corpus.curriculumId,
          learntLeaves: learnt,
          subTracks: subTrackStates ?? _liveStates(tracks),
        ),
      },
    );
  }

  /// The engine's default answer when a test gives no [SubTrackState]s:
  /// every non-ended sub-track holds its ground (a window still open). A
  /// test of an expired window or of missing engine state passes its own
  /// map, since the providers read `holdsGround` from the engine only.
  static Map<String, SubTrackState> _liveStates(List<SubTrack> tracks) => {
    for (final t in tracks)
      t.id: SubTrackState(
        subTrackId: t.id,
        holdsGround: !t.isEnded,
        inForecast: false,
        onHome: false,
      ),
  };

  /// The curriculum tree.
  final Corpus corpus;

  /// The learner.
  final LearnerScope scope;

  /// Whether the session is a parent's.
  bool parent;

  /// Whether the main track follows a live calendar program.
  final bool calendarProgram;

  /// The commands; null resolves `learningCommandsProvider` to null.
  final LearningCommands? commands;

  /// Commands built after the world (they need its repositories); wins
  /// over [commands].
  final LearningCommands Function()? commandsOverride;

  /// A live learner state (e.g. the real engine over [subTracks]); wins
  /// over [state].
  final Stream<LearnerState> Function(GroundPickerWorld world)? stateStream;

  /// ContentIndex rows for labels (default: none, names fall back to refs).
  final Map<CurriculumId, List<ContentItem>>? labelItems;

  /// The stored sub-tracks.
  final subTracks = InMemorySubTrackRepository();

  /// The governed intent.
  final intent = InMemoryGovernedIntentRepository();

  /// The learner state the picker reads.
  late LearnerState state;

  /// How many times the corpus was read.
  int corpusReads = 0;

  /// Fail the next [failCorpusReads] corpus reads (AC-2 retry).
  int failCorpusReads = 0;

  LearnerIntent _intent() => LearnerIntent(
    settings: c0Settings,
    mainTracks: {
      corpus.curriculumId: MainTrackIntent(
        curriculumId: corpus.curriculumId,
        track: MainTrack(
          curriculumId: corpus.curriculumId,
          state: MainTrackState.active,
        ),
        program: calendarProgram
            ? MainTrackProgram(
                curriculumId: corpus.curriculumId,
                programId: 'daf_yomi',
                trackingStartDate: '2026-01-01',
              )
            : null,
      ),
    },
    goals: const {},
  );

  /// The provider overrides wiring the picker to this world.
  List<Override> get overrides => [
    parentSessionProvider.overrideWith((ref) async => parent),
    activeLearnerScopeProvider.overrideWith((ref) async => scope),
    subTrackRepositoryProvider.overrideWith((ref) async => subTracks),
    governedIntentRepositoryProvider.overrideWith((ref) async => intent),
    corporaProvider.overrideWith((ref) async {
      corpusReads++;
      if (failCorpusReads > 0) {
        failCorpusReads--;
        throw StateError('corpus not ready');
      }
      return {corpus.curriculumId: corpus};
    }),
    learnerStateProvider.overrideWith(
      (ref, _) => stateStream?.call(this) ?? Stream.value(state),
    ),
    learningCommandsProvider.overrideWith(
      (ref) async => commandsOverride?.call() ?? commands,
    ),
    contentIndexProvider.overrideWith(
      (ref) async => ContentIndex.fromCurricula(labelItems ?? const {}),
    ),
    effectiveUseHebrewTermsProvider.overrideWithValue(false),
    currentTransliterationVariantProvider.overrideWithValue(
      TransliterationVariant.ashkenazi,
    ),
  ];

  /// Closes the fakes.
  Future<void> dispose() async {
    await subTracks.dispose();
    await intent.dispose();
  }
}

/// A phone-sized surface for [tester]-style tests.
const Size phoneSize = Size(412, 915);

/// A tablet-sized surface (≥ 840dp wide).
const Size tabletSize = Size(1280, 800);

class _AllowAll extends AutoRouteGuard {
  @override
  void onNavigation(NavigationResolver resolver, StackRouter router) =>
      resolver.next(true);
}

class _PinService extends Mock implements PinService {}

final class _AllowProfile extends ProfileGuard {
  _AllowProfile()
    : super(
        getProfiles: () async => const [],
        getSelectedProfileId: () => null,
        setSelectedProfileId: (_) {},
        isTutoredSession: () => false,
        profilePickerRoute: () => const SettingsRoute(),
      );

  @override
  Future<void> onNavigation(
    NavigationResolver resolver,
    StackRouter router,
  ) async => resolver.next(true);
}

final class _AllowChildMode extends ChildModeGuard {
  _AllowChildMode()
    : super(
        getProfileById: (_) async => null,
        getSelectedProfileId: () => null,
      );

  @override
  Future<void> onNavigation(
    NavigationResolver resolver,
    StackRouter router,
  ) async => resolver.next(true);
}

final class _AllowPin extends PinGuard {
  _AllowPin()
    : super(
        pinService: _PinService(),
        promptForPin: () async => true,
        getScope: () => null,
        pinSetupRoute: () => const SettingsRoute(),
      );

  @override
  Future<void> onNavigation(
    NavigationResolver resolver,
    StackRouter router,
  ) async => resolver.next(true);
}

/// A real [AppRouter] whose other guards let everything through, so a
/// test exercises exactly the picker route's parent-session guard, asking
/// [isParent].
AppRouter groundPickerTestRouter({required bool Function() isParent}) =>
    AppRouter(
      authGuard: _AllowAll(),
      profileGuard: _AllowProfile(),
      childModeGuard: _AllowChildMode(),
      pinGuard: _AllowPin(),
      parentSessionGuard: ParentSessionGuard(
        isParentSession: () async => isParent(),
      ),
    );
