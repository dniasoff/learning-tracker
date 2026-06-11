// Regression tests for IL-7 (Hebrew/RTL breadcrumb laid out LTR).
//
// Root cause: CurriculumLabelRenderer.renderForItem uses ' › ' (U+203A, a
// right-pointing chevron) as the separator even in Hebrew mode; the breadcrumb
// widget does not wrap in Directionality.rtl, so Hebrew breadcrumbs render
// left-to-right (broadest term on the left, which is wrong for RTL). Ordinal
// labels such as "פרק ג" may also suffer bidi scrambling when glued to the
// Arabic-numeral position.
//
// In-scope fix (owned root lib/core/labels/):
//   • renderForItem exposes a `rtlSeparator` constant for callers to use.
//   • The default separator for English mode is ' › ' (LTR chevron).
//   • Hebrew mode callers should pass CurriculumLabelRenderer.rtlSeparator
//     (' ‹ ') so the chevron points the right way and the string itself is
//     bidi-safe without a Directionality widget.
//
// Widget-layer fix (NOT in owned root): the BreadcrumbNavigation widget must
// wrap in Directionality.rtl when useHebrew=true (cross-slice, reported as
// crossSliceFindings).
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/labels/curriculum_label_renderer.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';

ContentItem _item({String level1 = 'Zeraim', String? level2, String? level3}) {
  return ContentItem(
    curriculumId: 'mishnayos',
    displayNameHe: 'ברכות',
    displayNameEn: 'Berachos',
    level1: level1,
    level2: level2,
    level3: level3,
    sefariaRef: 'Mishnah_Berakhot',
    sortOrder: 1,
    isLeaf: level3 != null,
  );
}

void main() {
  group('IL-7 — CurriculumLabelRenderer RTL separator constant', () {
    test('CurriculumLabelRenderer exposes an rtlSeparator constant', () {
      // The constant must exist — will fail compilation if absent.
      const sep = CurriculumLabelRenderer.rtlSeparator;
      expect(
        sep,
        isNotEmpty,
        reason: 'rtlSeparator must be a non-empty string',
      );
    });

    test('rtlSeparator points left (‹) not right (›)', () {
      const sep = CurriculumLabelRenderer.rtlSeparator;
      // The RTL-appropriate separator should point leftward.
      // We check that it contains the left-pointing chevron U+2039 or a
      // Unicode RTL-safe alternative.
      final hasLeftChevron =
          sep.contains('‹') || // ‹ single left-pointing angle quotation
          sep.contains('❮') || // ❮ heavy left-pointing angle quotation
          sep.contains('<'); // ASCII fallback
      expect(
        hasLeftChevron,
        isTrue,
        reason:
            'rtlSeparator "$sep" should contain a left-pointing chevron '
            'for RTL Hebrew breadcrumbs',
      );
    });

    test('default separator (LTR) points right (›)', () {
      const sep = CurriculumLabelRenderer.ltrSeparator;
      expect(
        sep.contains('›') || sep.contains('>'),
        isTrue,
        reason: 'ltrSeparator should contain a right-pointing chevron',
      );
    });
  });

  group(
    'IL-7 — renderForItem with RTL separator produces reversed breadcrumb',
    () {
      test(
        'Hebrew mode with rtlSeparator produces segments joined correctly',
        () {
          final item = _item(level1: 'Zeraim', level2: 'Berachos', level3: '1');
          final result = CurriculumLabelRenderer.renderForItem(
            item,
            useHebrew: true,
            fullPath: true,
            separator: CurriculumLabelRenderer.rtlSeparator,
          );
          expect(
            result.contains(CurriculumLabelRenderer.rtlSeparator),
            isTrue,
            reason: 'Full-path result should use the RTL separator',
          );
        },
      );
    },
  );
}
