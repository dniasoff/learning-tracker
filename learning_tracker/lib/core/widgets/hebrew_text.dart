import 'package:flutter/material.dart';
import 'package:learning_tracker/core/theme/text_styles.dart';

/// A [Text]-like widget that automatically enforces RTL directionality and
/// applies the Hebrew font family.
///
/// Wraps [Text] with [Directionality] set to [TextDirection.rtl] so that even
/// when placed inside an LTR scaffold the text renders correctly.
///
/// Usage:
/// ```dart
/// HebrewText('מִשְׁנָיוֹת', style: AppTextStyles.hebrewBodyLarge)
/// ```
class HebrewText extends StatelessWidget {
  const HebrewText(
    this.data, {
    super.key,
    this.style,
    this.textAlign = TextAlign.right,
    this.maxLines,
    this.overflow,
    this.softWrap,
  });

  final String data;
  final TextStyle? style;
  final TextAlign textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool? softWrap;

  @override
  Widget build(BuildContext context) {
    // AUD-core-theme-01: the fallback branch used to overwrite fontFamily
    // outright, discarding the ambient theme's real typography (Plus Jakarta
    // Sans) in favour of the Hebrew font. Instead, keep the themed family as
    // primary and add the Hebrew font as a fallback purely for glyph
    // coverage — Plus Jakarta Sans has no Hebrew glyphs, so Flutter's text
    // layout falls through to "Noto Sans Hebrew" per-glyph automatically,
    // and non-Hebrew characters (verse numerals, punctuation) keep
    // rendering in the app's real font instead of always switching to the
    // Hebrew face.
    final effectiveStyle =
        style ??
        DefaultTextStyle.of(context).style.copyWith(
          fontFamilyFallback: [
            AppTextStyles.hebrewFontFamily,
            ...?DefaultTextStyle.of(context).style.fontFamilyFallback,
          ],
        );

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Text(
        data,
        style: effectiveStyle,
        textDirection: TextDirection.rtl,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
        softWrap: softWrap,
      ),
    );
  }
}
