/// Story 25.9 (DNI-330) — guardrail lints.
///
/// These tests check that:
///   1. The `CurriculumLabels.curriculumName(useHebrew:)` static API has
///      been deleted from `lib/`.
///   2. No `lib/` files outside the allowed list read `displayNameEn` /
///      `displayNameHe` directly. Direct field-declaration files and
///      `core/labels/` are exempt; the goal is to keep call sites flowing
///      through `core/labels/`.
///
/// Failing greps mean a new dual-field caller leaked in — fix it by
/// routing through `core/labels/` accessors instead.
@Tags(['epic_25', 'story_25_9_lints'])
library;

import 'dart:io';

import 'package:test/test.dart';

/// Returns the project root regardless of cwd.
Directory _projectRoot() {
  for (final c in [Directory.current, Directory.current.parent]) {
    if (Directory('${c.path}/lib').existsSync()) return c;
  }
  throw StateError('cannot locate project root');
}

Iterable<File> _dartFilesUnder(Directory root) sync* {
  for (final e in root.listSync(recursive: true, followLinks: false)) {
    if (e is File && e.path.endsWith('.dart')) yield e;
  }
}

void main() {
  final root = _projectRoot();
  final libDir = Directory('${root.path}/lib');

  test('CurriculumLabels.curriculumName(useHebrew:) is deleted', () {
    final offenders = <String>[];
    for (final f in _dartFilesUnder(libDir)) {
      if (f.path.endsWith('.g.dart') || f.path.endsWith('.freezed.dart')) {
        continue;
      }
      final src = f.readAsStringSync();
      if (src.contains('CurriculumLabels.curriculumName(')) {
        offenders.add(f.path);
      }
      // Also catch the static-method declaration itself.
      if (src.contains(
        'static String curriculumName(CurriculumId id, {required bool useHebrew})',
      )) {
        offenders.add('${f.path} (declaration)');
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'CurriculumLabels.curriculumName(useHebrew:) is the deleted static '
          'API per AC. Use curriculumLabelText(ref, ...) or '
          'CurriculumLabel.curriculum(...) instead. Offenders:\n'
          '${offenders.join('\n')}',
    );
  });

  test('no inline displayNameEn/displayNameHe reads outside the allow-list', () {
    // Allow-list — files that legitimately declare or convert the dual fields.
    final allowList = <String>{
      // core/labels/ is the chokepoint — anything inside is allowed.
      'lib/core/labels/',
      // Data-class declarations and seed/registry files.
      'lib/core/network/sefaria/models/content_item.dart',
      'lib/features/scheduler/domain/services/calendar_program_registry.dart',
      'lib/features/scheduler/domain/services/calendar_program_service.dart',
      'lib/features/scheduler/domain/services/learning_program_service.dart',
      'lib/features/scheduler/domain/services/local_calendar_engine.dart',
      // Scheduler-side label resolver shim — bridges DomainTermLabels (core)
      // to scheduler types. Lives in features/scheduler to avoid the
      // core → features import that would otherwise violate Rule 1. The
      // displayNameEn/He reads here are inside a labels-layer file, not
      // arbitrary UI code. Introduced by W7-D / F4 of the Progress IA review.
      'lib/features/scheduler/domain/labels/program_label_resolver.dart',
      // Enum getters live on these types.
      'lib/core/enums/curriculum_id.dart',
      // Shared dual-form constants.
      'lib/core/constants/hebrew_terms.dart',
      'lib/core/constants/curriculum_defaults.dart',
      // ContentItem ↔ Drift row converters.
      'lib/features/content_browsing/data/repositories/content_repository_impl.dart',
      'lib/features/content_browsing/data/services/cloud_content_service.dart',
      'lib/features/content_browsing/domain/repositories/content_repository.dart',
      'lib/features/content_browsing/presentation/providers/content_providers.dart',
      // Shared renderer-bridge extracted from content_browser_tree /
      // bulk_mark_screen: groups items by next level, passes displayNameHe as
      // hebrewName: to CurriculumLabelRenderer, returns pre-rendered ContentItems.
      'lib/core/content/content_grouping.dart',
      // Drill-down navigation widget: captures item.displayNameHe (already
      // rendered by groupItemsByNextLevel) for breadcrumb Hebrew labels and
      // passes them to callers via onNavigationChanged.
      'lib/core/content/hierarchy_browser.dart',
      // Renderer-bridge: passes item.displayNameHe as hebrewName: to
      // CurriculumLabel.level (named segment Hebrew lookup), and builds
      // synthetic ContentItem instances to feed back through the renderer.
      'lib/features/content_browsing/presentation/screens/content_hierarchy_screen.dart',
      // Renderer-bridge: same pattern as content_hierarchy_screen — passes
      // item.displayNameHe as hebrewName: to CurriculumLabelRenderer.renderValue
      // and constructs synthetic ContentItem rows for the browse tree. DNI-issue-6.
      'lib/features/content_browsing/presentation/widgets/content_browser_tree.dart',
      'lib/features/onboarding/presentation/screens/bulk_mark_screen.dart',
      'lib/features/settings/presentation/screens/lifetime_marking_screen.dart',
      'lib/features/progress/presentation/providers/lifetime_knowledge_providers.dart',
      // items_learned_providers: builds the same Hebrew label lookup as
      // lifetime_knowledge_providers — item.displayNameHe is passed through
      // as hebrewName to LifetimeTreeNode (not displayed directly).
      'lib/features/progress/presentation/providers/items_learned_providers.dart',
      // Onboarding curriculum importer — Drift seed converter, not a UI surface.
      'lib/features/onboarding/domain/services/curriculum_import_service.dart',
      // Service builds bilingual storage entries (writes both forms into ledger).
      'lib/features/learning/domain/services/completion_detection_service.dart',
      // Repository converters — dual-field row → dual-field record.
      'lib/features/learning_order/data/repositories/learning_order_repository_impl.dart',
      'lib/features/learning_order/domain/models/learning_order_item.dart',
      'lib/features/track_learning_order/data/repositories/track_learning_order_repository_impl.dart',
      // S4-refactored equivalents under features/tracks/
      'lib/features/tracks/whole_curriculum_order/data/repositories/learning_order_repository_impl.dart',
      'lib/features/tracks/whole_curriculum_order/domain/models/learning_order_item.dart',
      'lib/features/tracks/track_order/data/repositories/track_learning_order_repository_impl.dart',
      // Progress domain service — builds bilingual tree nodes.
      'lib/features/progress/domain/services/lifetime_tree_builder.dart',
      // journey_view_model.dart and journey_providers.dart were removed from
      // this allow-list by DNI-362: UnitCompletion no longer carries
      // displayNameHe/displayNameEn; label resolution is deferred to
      // CurriculumLabel.level at render time.
      // Constructs CalendarProgramEntry instances directly.
      'lib/features/scheduler/presentation/providers/scheduler_providers.dart',
      // SefariaRefMatcher domain service — constructs sentinel ContentItem
      // instances (required constructor fields, not UI label reads). C5 extraction.
      'lib/features/scheduler/domain/services/sefaria_ref_matcher.dart',
      // Doc-comment reference only.
      'lib/features/tracks/setup/presentation/widgets/curriculum_picker_step.dart',
      // Composite curriculum strategy — constructs synthetic ContentItem
      // preamble rows (data layer, not a UI surface). DNI-358 / 26.15.
      'lib/features/content_browsing/domain/strategies/composite_curriculum_strategy.dart',
      // Sync codec — serialises/deserialises bilingual LearningOrderRow fields
      // for the pull pipeline (data layer, not a UI surface). W2.26 / C3.
      'lib/core/sync/codec/learning_order_codec.dart',
      // Domain ordering policy — reads dual-form fields to build bilingual sort
      // keys for masechta ordering (domain layer, not a UI surface). W3.
      'lib/features/tracks/track_order/domain/services/masechta_ordering_policy.dart',
    };

    final pattern = RegExp(r'\bdisplayName(En|He)\b');
    final offenders = <String>[];

    for (final f in _dartFilesUnder(libDir)) {
      if (f.path.endsWith('.g.dart') || f.path.endsWith('.freezed.dart')) {
        continue;
      }
      final rel = f.path.substring(root.path.length + 1);
      // Allow if path starts with any allow-list prefix.
      if (allowList.any((p) => rel == p || rel.startsWith(p))) continue;

      final src = f.readAsStringSync();
      if (pattern.hasMatch(src)) {
        offenders.add(rel);
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'New displayNameEn/displayNameHe caller(s) outside core/labels. '
          'Route through curriculumLabelText / calendarEntryLabelText / '
          'learningProgramLabelText (or '
          'CurriculumLabel.* widget) instead. Offenders:\n'
          '${offenders.join('\n')}',
    );
  });

  // B11-7 — No raw HebrewTerms. calls in lib/features/ presentation code.
  //
  // All presentation code must go through domainTermLabels(ref).* accessors.
  // The only allowed consumers of raw HebrewTerms.* are lib/core/labels/ and
  // lib/core/constants/ themselves.
  test('no raw HebrewTerms. calls in lib/features/ (B11-7)', () {
    final pattern = RegExp(r'\bHebrewTerms\.');
    final offenders = <String>[];

    final featuresDir = Directory('${root.path}/lib/features');
    if (!featuresDir.existsSync()) {
      fail('lib/features/ not found — run from learning_tracker/ root');
    }

    for (final f in _dartFilesUnder(featuresDir)) {
      if (f.path.endsWith('.g.dart') || f.path.endsWith('.freezed.dart')) {
        continue;
      }
      if (f.path.endsWith('_test.dart')) continue;

      final src = f.readAsStringSync();
      if (pattern.hasMatch(src)) {
        final rel = f.path.substring(root.path.length + 1);
        offenders.add(rel);
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Raw HebrewTerms.* call(s) found in lib/features/. '
          'Use domainTermLabels(ref).chazaraStage(n), .stageLearn, '
          '.talmidChochom, etc. instead. Offenders:\n'
          '${offenders.join('\n')}',
    );
  });
}
