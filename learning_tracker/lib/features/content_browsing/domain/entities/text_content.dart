/// One inner sub-leaf within a [TextContent] — a single pasuk, mishna,
/// halacha, seif, amud, etc. When the user opens a perek/daf/siman, the
/// repository aggregates its child leaves into a list of [TextSegment]
/// so the reader can render each with a small in-line number badge
/// (e.g. `א ` before its pasuk).
class TextSegment {
  TextSegment({
    required this.sefariaRef,
    required this.hebrewText,
    required this.englishText,
    this.number,
  });

  final String sefariaRef;
  final String hebrewText;
  final String englishText;

  /// 1-based sub-position parsed from the ref (e.g. `Genesis 1:5` → 5,
  /// `Mishnah Berakhot 1:3` → 3). `null` when the ref carries no
  /// numeric suffix (e.g. `Berakhot 2a` for a Bavli amud, where there
  /// is only ever one segment anyway).
  final int? number;
}

/// Model for fetched text content.
class TextContent {
  TextContent({required this.sefariaRef, required this.segments});

  /// Convenience constructor for callers that have a single block of
  /// Hebrew + English text (no per-verse split). Mostly used by tests
  /// and legacy code paths.
  factory TextContent.single({
    required String sefariaRef,
    required String hebrewText,
    required String englishText,
  }) {
    return TextContent(
      sefariaRef: sefariaRef,
      segments: [
        TextSegment(
          sefariaRef: sefariaRef,
          hebrewText: hebrewText,
          englishText: englishText,
        ),
      ],
    );
  }

  final String sefariaRef;

  /// Ordered list of inner segments (1+). Single-segment for direct
  /// leaf opens; multi-segment for chapter-/perek-level aggregation.
  final List<TextSegment> segments;

  /// Convenience: joined Hebrew text (newline-separated). Preserved for
  /// callers that need a flat string — e.g. nikud stripping. The new
  /// per-segment renderer reads [segments] directly.
  String get hebrewText =>
      segments.map((s) => s.hebrewText).where((t) => t.isNotEmpty).join('\n');

  String get englishText =>
      segments.map((s) => s.englishText).where((t) => t.isNotEmpty).join('\n');
}
