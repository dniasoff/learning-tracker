import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/labels/curriculum_label_providers.dart';
import 'package:learning_tracker/core/labels/curriculum_label_renderer.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/features/scheduler/scheduler.dart';

/// The single entry point for rendering any curriculum-aware label in the UI.
///
/// The widget exposes modes — sync ([curriculum], [calendarProgram],
/// [learningProgram], [level], [item]) and async
/// ([breadcrumb], [local], [parent]). Every mode picks the Hebrew vs English
/// form from [useHebrewTermsProvider]. Whenever the rendered string is Hebrew
/// script the underlying `Text` is forced to `TextDirection.rtl`, satisfying
/// the AC even when surrounded by an LTR `Directionality`.
///
/// Async modes resolve `sefariaRef` through `contentIndexProvider` — an
/// O(1) lookup across all 9 curricula. Loading state renders a zero-width
/// space so line height stays stable.
class CurriculumLabel extends ConsumerWidget {
  const CurriculumLabel.curriculum(
    CurriculumId id, {
    this.style,
    this.maxLines,
    this.overflow,
    this.textAlign,
    this.textDirection,
    super.key,
  }) : _kind = _Kind.curriculum,
       _curriculumId = id,
       _calendarEntry = null,
       _learningProgram = null,
       _level = null,
       _rawValue = null,
       _parentL1Value = null,
       _hebrewName = null,
       _item = null,
       _itemMode = null,
       _sefariaRef = null;

  /// Renders a calendar program entry (e.g. "Daf Yomi" / "דף יומי").
  const CurriculumLabel.calendarProgram(
    CalendarProgramEntry entry, {
    this.style,
    this.maxLines,
    this.overflow,
    this.textAlign,
    this.textDirection,
    super.key,
  }) : _kind = _Kind.calendarProgram,
       _curriculumId = null,
       _calendarEntry = entry,
       _learningProgram = null,
       _level = null,
       _rawValue = null,
       _parentL1Value = null,
       _hebrewName = null,
       _item = null,
       _itemMode = null,
       _sefariaRef = null;

  /// Renders a learning program (e.g. "Daf Yomi" / "דף יומי"). The Hebrew
  /// form comes from [CalendarProgramRegistry] keyed by
  /// [LearningProgramData.name].
  const CurriculumLabel.learningProgram(
    LearningProgramData program, {
    this.style,
    this.maxLines,
    this.overflow,
    this.textAlign,
    this.textDirection,
    super.key,
  }) : _kind = _Kind.learningProgram,
       _curriculumId = null,
       _calendarEntry = null,
       _learningProgram = program,
       _level = null,
       _rawValue = null,
       _parentL1Value = null,
       _hebrewName = null,
       _item = null,
       _itemMode = null,
       _sefariaRef = null;

  /// Renders a single segment from level metadata. Use inside trees and
  /// hierarchical lists where the row's position supplies parent context —
  /// emits only the local segment (e.g. "פרק א" / "Perek 1" instead of
  /// "משנה דמאי א" / "Mishnah Demai 1"). [hebrewName] is the matching
  /// hierarchy row's `displayNameHe` (from `heLabelLookup`) for named levels;
  /// for ordinal levels it's ignored.
  const CurriculumLabel.level({
    required CurriculumId curriculumId,
    required int level,
    required String rawValue,
    String? parentL1Value,
    String? hebrewName,
    this.style,
    this.maxLines,
    this.overflow,
    this.textAlign,
    this.textDirection,
    super.key,
  }) : _kind = _Kind.level,
       _curriculumId = curriculumId,
       _calendarEntry = null,
       _learningProgram = null,
       _level = level,
       _rawValue = rawValue,
       _parentL1Value = parentL1Value,
       _hebrewName = hebrewName,
       _item = null,
       _itemMode = null,
       _sefariaRef = null;

  /// Renders a label from an already-loaded [ContentItem].
  ///
  /// [CurriculumLabelMode.leaf] is synchronous — it only needs the item's
  /// own `displayNameHe`/`displayNameEn`. [CurriculumLabelMode.breadcrumb]
  /// and [CurriculumLabelMode.parent] need every NAMED ancestor segment's
  /// Hebrew name (e.g. the Seder/Masechta above a Mishna), which isn't
  /// carried on the leaf item itself — those modes resolve it via
  /// `item.sefariaRef` through the same async provider path as
  /// [CurriculumLabel.breadcrumb]/[CurriculumLabel.parent]
  /// (`renderedDisplayForRefProvider`/`renderedParentForRefProvider`), so
  /// they render a zero-width-space placeholder for one frame while loading.
  const CurriculumLabel.item(
    ContentItem item, {
    CurriculumLabelMode mode = CurriculumLabelMode.leaf,
    this.style,
    this.maxLines,
    this.overflow,
    this.textAlign,
    this.textDirection,
    super.key,
  }) : _kind = _Kind.item,
       _curriculumId = null,
       _calendarEntry = null,
       _learningProgram = null,
       _level = null,
       _rawValue = null,
       _parentL1Value = null,
       _hebrewName = null,
       _item = item,
       _itemMode = mode,
       _sefariaRef = null;

  /// Full breadcrumb for [sefariaRef] (e.g. "זרעים › ברכות › פרק א"). Async.
  const CurriculumLabel.breadcrumb(
    String sefariaRef, {
    this.style,
    this.maxLines,
    this.overflow,
    this.textAlign,
    this.textDirection,
    super.key,
  }) : _kind = _Kind.breadcrumb,
       _curriculumId = null,
       _calendarEntry = null,
       _learningProgram = null,
       _level = null,
       _rawValue = null,
       _parentL1Value = null,
       _hebrewName = null,
       _item = null,
       _itemMode = null,
       _sefariaRef = sefariaRef;

  /// Leaf segment of [sefariaRef] (e.g. "משנה א"). Async.
  const CurriculumLabel.local(
    String sefariaRef, {
    this.style,
    this.maxLines,
    this.overflow,
    this.textAlign,
    this.textDirection,
    super.key,
  }) : _kind = _Kind.local,
       _curriculumId = null,
       _calendarEntry = null,
       _learningProgram = null,
       _level = null,
       _rawValue = null,
       _parentL1Value = null,
       _hebrewName = null,
       _item = null,
       _itemMode = null,
       _sefariaRef = sefariaRef;

  /// Parent segment of [sefariaRef] (one level above leaf). Async. Renders
  /// nothing if the ref is already at level 1.
  const CurriculumLabel.parent(
    String sefariaRef, {
    this.style,
    this.maxLines,
    this.overflow,
    this.textAlign,
    this.textDirection,
    super.key,
  }) : _kind = _Kind.parent,
       _curriculumId = null,
       _calendarEntry = null,
       _learningProgram = null,
       _level = null,
       _rawValue = null,
       _parentL1Value = null,
       _hebrewName = null,
       _item = null,
       _itemMode = null,
       _sefariaRef = sefariaRef;

  final _Kind _kind;
  final CurriculumId? _curriculumId;
  final CalendarProgramEntry? _calendarEntry;
  final LearningProgramData? _learningProgram;
  final int? _level;
  final String? _rawValue;
  final String? _parentL1Value;
  final String? _hebrewName;
  final ContentItem? _item;
  final CurriculumLabelMode? _itemMode;
  final String? _sefariaRef;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;
  final TextDirection? textDirection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    switch (_kind) {
      case _Kind.curriculum:
        final useHebrew = ref.watch(effectiveUseHebrewTermsProvider);
        if (useHebrew) {
          return _text(_curriculumId!.displayNameHe, useHebrew: true);
        }
        // English mode: the curriculum's `displayNameEn` is the Ashkenazi
        // transliteration. Run it through the single transliteration source so
        // Sephardi users see the Sephardi form (e.g. "Mishnayot" not
        // "Mishnayos"). Names that are identical in both nuschaos fall through
        // to the raw Ashkenazi value.
        final variant = ref.watch(currentTransliterationVariantProvider);
        return _text(
          CurriculumLabels.transliterateNamedValue(
            _curriculumId!.displayNameEn,
            variant: variant,
          ),
          useHebrew: false,
        );
      case _Kind.calendarProgram:
        final useHebrew = ref.watch(effectiveUseHebrewTermsProvider);
        return _text(
          useHebrew
              ? _calendarEntry!.displayNameHe
              : _calendarEntry!.displayNameEn,
          useHebrew: useHebrew,
        );
      case _Kind.learningProgram:
        final useHebrew = ref.watch(effectiveUseHebrewTermsProvider);
        final program = _learningProgram!;
        final text = !useHebrew
            ? program.displayName
            : (CalendarProgramRegistry.hebrewNameFor(
                    name: program.name,
                    apiKey: program.apiProgramKey,
                  ) ??
                  program.displayName);
        return _text(text, useHebrew: useHebrew);
      case _Kind.level:
        final useHebrew = ref.watch(effectiveUseHebrewTermsProvider);
        final variant = ref.watch(currentTransliterationVariantProvider);
        return _text(
          CurriculumLabelRenderer.renderValue(
            curriculumId: _curriculumId!,
            level: _level!,
            rawValue: _rawValue!,
            useHebrew: useHebrew,
            hebrewName: _hebrewName,
            parentL1Value: _parentL1Value,
            transliterationVariant: variant,
          ),
          useHebrew: useHebrew,
        );
      case _Kind.item:
        final useHebrew = ref.watch(effectiveUseHebrewTermsProvider);
        final variant = ref.watch(currentTransliterationVariantProvider);
        final item = _item!;
        switch (_itemMode!) {
          case CurriculumLabelMode.leaf:
            // Only the leaf's own displayNameHe/displayNameEn is needed —
            // no ancestor lookup required, so this stays synchronous.
            return _text(
              CurriculumLabelRenderer.renderForItem(
                item,
                useHebrew: useHebrew,
                transliterationVariant: variant,
              ),
              useHebrew: useHebrew,
            );
          case CurriculumLabelMode.breadcrumb:
            // AUD-core-labels-01: route through the same ref-based async
            // provider as CurriculumLabel.breadcrumb so every named
            // ancestor segment (not just the leaf) resolves its Hebrew
            // name via curriculumContentProvider instead of falling back
            // to the raw storage-key value.
            return ref
                .watch(renderedDisplayForRefProvider(item.sefariaRef))
                .when(
                  data: (s) => _text(s, useHebrew: useHebrew),
                  loading: () => _text('​', useHebrew: useHebrew),
                  error: (_, __) => _text(
                    CurriculumLabelRenderer.renderForItem(
                      item,
                      useHebrew: useHebrew,
                      fullPath: true,
                      transliterationVariant: variant,
                    ),
                    useHebrew: useHebrew,
                  ),
                );
          case CurriculumLabelMode.parent:
            // AUD-core-labels-01: same fix as breadcrumb above, via
            // renderedParentForRefProvider.
            return ref
                .watch(renderedParentForRefProvider(item.sefariaRef))
                .when(
                  data: (s) => _text(s ?? '', useHebrew: useHebrew),
                  loading: () => _text('​', useHebrew: useHebrew),
                  error: (_, __) => _text(
                    CurriculumLabelRenderer.renderParentForItem(
                          item,
                          useHebrew: useHebrew,
                          transliterationVariant: variant,
                        ) ??
                        '',
                    useHebrew: useHebrew,
                  ),
                );
        }
      case _Kind.breadcrumb:
        final useHebrew = ref.watch(effectiveUseHebrewTermsProvider);
        final r = _sefariaRef!;
        return ref
            .watch(renderedDisplayForRefProvider(r))
            .when(
              data: (s) => _text(s, useHebrew: useHebrew),
              loading: () => _text('​', useHebrew: useHebrew),
              error: (_, __) =>
                  _text(r.replaceAll('_', ' '), useHebrew: useHebrew),
            );
      case _Kind.local:
        final useHebrew = ref.watch(effectiveUseHebrewTermsProvider);
        final r = _sefariaRef!;
        return ref
            .watch(renderedLeafForRefProvider(r))
            .when(
              data: (s) => _text(s, useHebrew: useHebrew),
              loading: () => _text('​', useHebrew: useHebrew),
              error: (_, __) =>
                  _text(r.replaceAll('_', ' '), useHebrew: useHebrew),
            );
      case _Kind.parent:
        final useHebrew = ref.watch(effectiveUseHebrewTermsProvider);
        final r = _sefariaRef!;
        return ref
            .watch(renderedParentForRefProvider(r))
            .when(
              data: (s) => _text(s ?? '', useHebrew: useHebrew),
              loading: () => _text('​', useHebrew: useHebrew),
              error: (_, __) => _text('', useHebrew: useHebrew),
            );
    }
  }

  /// Build the underlying `Text` widget. Forces `TextDirection.rtl` whenever
  /// the rendered string is Hebrew script, so the script reads correctly
  /// even when the ambient `Directionality` is LTR. Explicit
  /// `textDirection:` on the constructor overrides this default.
  Widget _text(String text, {required bool useHebrew}) => Text(
    text,
    style: style,
    maxLines: maxLines,
    overflow: overflow,
    textAlign: textAlign,
    // DNI-341: when no explicit textDirection is supplied, infer RTL from
    // the rendered text so Hebrew-script labels render correctly regardless
    // of the surrounding Directionality (e.g. an LTR app shell embedding
    // a Hebrew curriculum name).
    textDirection: textDirection ?? _inferDirection(text),
  );

  static TextDirection? _inferDirection(String text) =>
      isHebrewText(text) ? TextDirection.rtl : null;

  /// True when [text] contains any Hebrew-script character (Unicode block
  /// U+0590..U+05FF).
  ///
  /// This is the single canonical Hebrew-script detector for `core/labels`
  /// (AUD-tracks-18): other call sites that need bidi-aware handling of a
  /// plain label string — not a [CurriculumLabel] widget itself, e.g.
  /// `TrackLearningOrderScreen`'s section headers — call this instead of
  /// hand-rolling a private copy of the same Unicode range.
  static bool isHebrewText(String text) => _hebrew.hasMatch(text);

  static final RegExp _hebrew = RegExp('[֐-׿]');
}

enum _Kind {
  curriculum,
  calendarProgram,
  learningProgram,
  level,
  item,
  breadcrumb,
  local,
  parent,
}

/// Mode for [CurriculumLabel.item]: which segment(s) of the item's path to
/// render.
enum CurriculumLabelMode { breadcrumb, leaf, parent }

/// Resolves the pure-string curriculum label. In English mode the curriculum's
/// `displayNameEn` (the Ashkenazi transliteration) is run through the single
/// transliteration source so Sephardi users see the Sephardi form (e.g.
/// "Mishnayot" not "Mishnayos"); names identical in both nuschaos fall through
/// to the raw Ashkenazi value. Hebrew mode is unaffected by [variant].
String _curriculumLabel(
  CurriculumId curriculum,
  bool useHebrew,
  TransliterationVariant variant,
) => useHebrew
    ? curriculum.displayNameHe
    : CurriculumLabels.transliterateNamedValue(
        curriculum.displayNameEn,
        variant: variant,
      );

/// Ref-free variant: resolves the curriculum label from an already-read
/// `useHebrewTerms` flag. Use inside async provider bodies where the
/// Hebrew-terms value must be captured BEFORE an `await` (calling
/// [curriculumLabelTextFromRef] after an async gap risks "Cannot use Ref
/// after dispose"). Pass `ref.watch(effectiveUseHebrewTermsProvider)` captured up-front.
/// [variant] should likewise be captured from
/// `ref.watch(currentTransliterationVariantProvider)`; it defaults to Ashkenazi
/// so existing callers keep today's behavior.
String curriculumLabelFor(
  CurriculumId curriculum, {
  required bool useHebrewTerms,
  TransliterationVariant variant = TransliterationVariant.ashkenazi,
}) => _curriculumLabel(curriculum, useHebrewTerms, variant);

/// Pure-string variant of [CurriculumLabel.curriculum] for AppBar titles,
/// dialog messages, sort keys, semantics labels — places that need a `String`
/// rather than a widget. Watches [useHebrewTermsProvider] and
/// [currentTransliterationVariantProvider]. Use this from widgets
/// (ConsumerWidget, Consumer, hooks_riverpod).
String curriculumLabelText(WidgetRef ref, {required CurriculumId curriculum}) =>
    _curriculumLabel(
      curriculum,
      ref.watch(effectiveUseHebrewTermsProvider),
      ref.watch(currentTransliterationVariantProvider),
    );

/// Same as [curriculumLabelText] but takes a provider-side [Ref]. Use this
/// from inside provider/notifier closures where the closure parameter is
/// [Ref] rather than [WidgetRef]. Watches [useHebrewTermsProvider] and
/// [currentTransliterationVariantProvider] so the containing provider re-runs
/// when either toggle changes.
String curriculumLabelTextFromRef(
  Ref ref, {
  required CurriculumId curriculum,
}) => _curriculumLabel(
  curriculum,
  ref.watch(effectiveUseHebrewTermsProvider),
  ref.watch(currentTransliterationVariantProvider),
);

/// Returns the Hebrew form of a curriculum's name unconditionally. Use only
/// when both forms must be shown simultaneously (dual-language presentations
/// like the Lifetime curriculum row). Everywhere else, use [CurriculumLabel]
/// or [curriculumLabelText] so the Hebrew Terms toggle is respected.
String curriculumHebrewName(CurriculumId curriculum) =>
    curriculum.displayNameHe;

/// Returns the English transliteration of a curriculum's name unconditionally.
/// Use ONLY for stable English-locale sort keys / locale-independent identifiers
/// (e.g. sort labels in filter dropdowns where the sort order must not flip
/// with the Hebrew Terms toggle). For user-facing display, use
/// [CurriculumLabel] or [curriculumLabelText].
String curriculumEnglishName(CurriculumId curriculum) =>
    curriculum.displayNameEn;
