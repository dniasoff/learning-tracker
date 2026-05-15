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
      'lib/core/services/calendar_program_registry.dart',
      'lib/core/services/calendar_program_service.dart',
      'lib/core/services/learning_program_service.dart',
      'lib/core/services/local_calendar_engine.dart',
      // Enum getters live on these types.
      'lib/core/enums/curriculum_id.dart',
      'lib/core/enums/track_type.dart',
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
      // Onboarding curriculum importer — Drift seed converter, not a UI surface.
      'lib/features/onboarding/domain/services/curriculum_import_service.dart',
      // Service builds bilingual storage entries (writes both forms into ledger).
      'lib/features/learning/domain/services/completion_detection_service.dart',
      // Repository converters — dual-field row → dual-field record.
      'lib/features/learning_order/data/repositories/learning_order_repository_impl.dart',
      'lib/features/learning_order/domain/models/learning_order_item.dart',
      'lib/features/track_learning_order/data/repositories/track_learning_order_repository_impl.dart',
      // journey_view_model.dart and journey_providers.dart were removed from
      // this allow-list by DNI-362: UnitCompletion no longer carries
      // displayNameHe/displayNameEn; label resolution is deferred to
      // CurriculumLabel.level at render time.
      // Constructs CalendarProgramEntry instances directly.
      'lib/features/scheduler/presentation/providers/scheduler_providers.dart',
      // Doc-comment reference only.
      'lib/features/track_setup/presentation/widgets/curriculum_picker_step.dart',
      // Composite curriculum strategy — constructs synthetic ContentItem
      // preamble rows (data layer, not a UI surface). DNI-358 / 26.15.
      'lib/features/content_browsing/domain/strategies/composite_curriculum_strategy.dart',
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
          'learningProgramLabelText / trackTypeLabelText (or '
          'CurriculumLabel.* widget) instead. Offenders:\n'
          '${offenders.join('\n')}',
    );
  });
}
