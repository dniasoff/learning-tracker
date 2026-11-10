import 'package:flutter/material.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/core/utils/gematriya.dart';
import 'package:learning_tracker/core/utils/hebrew_utils.dart';
import 'package:learning_tracker/features/content_browsing/domain/entities/text_content.dart';

/// One Hebrew text segment followed by its translated or parallel readings.
/// Shared by the general text reader and the Shnayim Mikra reader.
class SegmentWithGlosses extends StatelessWidget {
  const SegmentWithGlosses({
    super.key,
    required this.segment,
    required this.glosses,
    required this.showNumber,
    required this.showNikud,
    required this.hebrewStyle,
  });

  final TextSegment segment;
  final List<SegmentGloss> glosses;
  final bool showNumber;
  final bool showNikud;
  final TextStyle hebrewStyle;

  @override
  Widget build(BuildContext context) {
    var hebrew = segment.hebrewText;
    if (!showNikud) hebrew = HebrewUtils.stripNikud(hebrew);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hebrew.isNotEmpty)
          _SegmentTextLine(
            text: hebrew,
            direction: TextDirection.rtl,
            style: hebrewStyle,
            marker: showNumber && segment.number != null
                ? Gematriya.forNumber(segment.number!)
                : null,
          ),
        for (final gloss in glosses)
          if (gloss.text.isNotEmpty)
            Padding(
              padding: const EdgeInsetsDirectional.only(top: 2),
              child: _SegmentTextLine(
                text: gloss.text,
                direction: gloss.direction,
                style: gloss.style,
                marker: gloss.marker,
              ),
            ),
      ],
    );
  }
}

/// A translated or parallel text line displayed after its Hebrew segment.
class SegmentGloss {
  const SegmentGloss({
    required this.text,
    required this.direction,
    required this.style,
    this.marker,
  });

  final String text;
  final TextDirection direction;
  final TextStyle style;
  final String? marker;
}

class _SegmentTextLine extends StatelessWidget {
  const _SegmentTextLine({
    required this.text,
    required this.direction,
    required this.style,
    this.marker,
  });

  final String text;
  final TextDirection direction;
  final TextStyle style;
  final String? marker;

  @override
  Widget build(BuildContext context) {
    final spans = <InlineSpan>[];
    if (marker != null) {
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: Padding(
            padding: direction == TextDirection.rtl
                ? const EdgeInsetsDirectional.only(start: 6)
                : const EdgeInsetsDirectional.only(end: 6),
            child: _VerseNumberBadge(marker: marker!),
          ),
        ),
      );
    }
    spans.add(TextSpan(text: text, style: style));
    return Text.rich(
      TextSpan(children: spans, style: style),
      textDirection: direction,
      textAlign: TextAlign.start,
    );
  }
}

class _VerseNumberBadge extends StatelessWidget {
  const _VerseNumberBadge({required this.marker});

  final String marker;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
      decoration: BoxDecoration(
        color: context.colors.brandBlueSoft.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        marker,
        style: TextStyle(
          color: context.colors.brandBlueDeep,
          fontWeight: FontWeight.w800,
          fontSize: 13,
          height: 1.0,
        ),
      ),
    );
  }
}
