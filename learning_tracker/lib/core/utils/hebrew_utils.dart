/// Utilities for Hebrew text processing.
class HebrewUtils {
  HebrewUtils._();

  /// Unicode ranges for Hebrew nikud (vowel/cantillation marks):
  /// U+0591-U+05BD, U+05BF, U+05C1-U+05C2, U+05C4-U+05C5, U+05C7
  static final RegExp _nikudPattern = RegExp('[֑-ׇֽֿׁׂׅׄ]');

  /// Strips all nikud (vowel marks) from Hebrew text.
  static String stripNikud(String text) {
    return text.replaceAll(_nikudPattern, '');
  }

  /// Returns true if the text contains any nikud characters.
  static bool hasNikud(String text) {
    return _nikudPattern.hasMatch(text);
  }

  static final RegExp _htmlTagPattern = RegExp('<[^>]+>');

  /// Sefaria footnote markup. A footnote is rendered as a marker letter inside
  /// a `<sup class="footnote-marker">` immediately followed by the footnote
  /// body inside an `<i class="footnote">`. Both the marker letter AND the
  /// footnote body (which itself begins by repeating the lemma) must be
  /// removed *whole* — a naive `<[^>]+>` tag-strip leaves the inner text
  /// behind, gluing the marker letter to the preceding word and dumping the
  /// footnote text mid-sentence (e.g.
  /// `createaWhen God began to create In contrast to others …`).
  ///
  /// `[\s\S]` (not `.`) so the body matches across newlines; non-greedy so
  /// adjacent footnotes are each removed individually.
  static final RegExp _footnoteMarkerPattern = RegExp(
    r'<sup\b[^>]*class="[^"]*footnote-marker[^"]*"[^>]*>[\s\S]*?</sup>',
    caseSensitive: false,
  );
  static final RegExp _footnotePattern = RegExp(
    r'<i\b[^>]*class="[^"]*footnote[^"]*"[^>]*>[\s\S]*?</i>',
    caseSensitive: false,
  );

  /// Runs of horizontal whitespace left behind where footnote markup used to
  /// sit (e.g. `create  heaven`). Collapsed to a single space. Newlines are
  /// preserved (parasha markers below depend on them).
  static final RegExp _horizontalWhitespaceRun = RegExp('[ \t]{2,}');

  /// Decodes HTML entities and removes markup found in Sefaria text — for both
  /// Hebrew and English. Footnote constructs (marker + body) are removed in
  /// full *before* the generic tag strip so neither the marker letter nor the
  /// footnote body survives as inline text.
  static String decodeHtmlEntities(String text) {
    var out = text
        .replaceAll(_footnoteMarkerPattern, '')
        .replaceAll(_footnotePattern, '')
        .replaceAll(_htmlTagPattern, '')
        .replaceAll('&thinsp;', ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('{פ}', '\n\n')
        .replaceAll('{ס}', '\n');
    out = out.replaceAll(_horizontalWhitespaceRun, ' ');
    return out;
  }

  /// Cleans a Sefaria English (or Hebrew) text fragment for display: removes
  /// footnote markup whole, strips remaining tags, decodes entities, and
  /// collapses whitespace. Alias of [decodeHtmlEntities] with an intent-named
  /// signature for callers cleaning the English translation column.
  static String cleanSefariaText(String text) => decodeHtmlEntities(text);
}
