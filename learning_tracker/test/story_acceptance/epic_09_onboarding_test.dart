/// Story acceptance coverage for Epic 9 — onboarding.
@Tags(['epic_9'])
library;

import 'package:flutter/widgets.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/content/content_index_corpus.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/onboarding/domain/services/before_tracking_recorder.dart';
import 'package:learning_tracker/features/onboarding/domain/validators/auth_validators.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../helpers/learner_state/fake_learning_commands.dart';

void main() {
  group('Story 9.1 — welcome flow', tags: ['story_9_1'], () {
    test('email and password validation rules are preserved', () {
      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(validateEmail('invalid', l10n), isNotNull);
      expect(validateEmail('user@example.com', l10n), isNull);
      expect(validatePassword('12345', l10n), isNotNull);
      expect(validatePassword('123456', l10n), isNull);
    });
  });

  group('Story 9.2 — curriculum selection', tags: ['story_9_2'], () {
    test('all selectable curricula have stable storage keys', () {
      for (final curriculum in CurriculumId.values) {
        expect(curriculum.storageKey, isNotEmpty);
      }
    });
  });

  group(
    'Story 9.3 — goal setup',
    tags: ['story_9_3'],
    skip:
        'Blocked: onboarding goal/stage persistence still constructs Drift-backed repositories; the Firestore provider seam is not available to this flow.',
    () {
      test('placeholder for the pending Firestore goal-setup seam', () {});
    },
  );

  // Story 1.11 (DNI-473, R10/R15 port): the onboarding bulk mark is ONE
  // `before_tracking` capture through LearningCommands — a whole ticked
  // node is one node event with its level, with no learned_on.
  group('Story 9.4 — bulk prior completions', tags: ['story_9_4'], () {
    test('a ticked masechta records one before_tracking node event', () async {
      final commands = FakeLearningCommands();
      addTearDown(commands.dispose);
      final recorder = BeforeTrackingRecorder(
        ownsBookmark: () => true,
        contentRepository: _Mishnayos(),
        commands: () async => commands,
        events: () async => const [],
      );

      final result = await recorder.recordScopes(
        curriculumId: CurriculumId.mishnayos,
        scopes: const [(level: 2, unitId: 'Zeraim|Mishnah Berakhot')],
      );

      expect(result.itemCount, 1);
      final capture = commands.calls.single;
      expect(capture.name, 'capture');
      expect(capture.args['dateState'], DateState.beforeTracking);
      expect(capture.args['learnedOn'], isNull);
      expect(capture.args['nodes'], [
        NodeEntry(
          level: contentLevelName(
            CurriculumLabels.labelsEn(CurriculumId.mishnayos),
            2,
          ),
          ref: 'Mishnah Berakhot',
        ),
      ]);
    });
  });
}

class _Mishnayos extends Fake implements ContentRepository {
  static ContentItem _item(
    String ref,
    int order,
    List<String> path,
    bool leaf,
  ) => ContentItem(
    curriculumId: 'mishnayos',
    level1: path[0],
    level2: path.length > 1 ? path[1] : null,
    level3: path.length > 2 ? path[2] : null,
    displayNameHe: ref,
    displayNameEn: ref,
    sefariaRef: ref,
    sortOrder: order,
    isLeaf: leaf,
  );

  @override
  Future<List<ContentItem>> getContentForCurriculum(CurriculumId id) async => [
    _item('Seder Zeraim', 0, ['Zeraim'], false),
    _item('Mishnah Berakhot', 1, ['Zeraim', 'Mishnah Berakhot'], false),
    _item('Mishnah Berakhot 1:1', 2, ['Zeraim', 'Mishnah Berakhot', '1'], true),
  ];
}
