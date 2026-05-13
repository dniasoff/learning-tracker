import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/track_type.dart';
import 'package:learning_tracker/core/labels/curriculum_label_providers.dart';
import 'package:learning_tracker/core/labels/curriculum_label_renderer.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/services/calendar_program_registry.dart';
import 'package:learning_tracker/core/services/calendar_program_service.dart';
import 'package:learning_tracker/core/services/learning_program_service.dart';

/// The single entry point for rendering any curriculum-aware label in the UI.
///
/// The widget exposes six modes — three sync ([curriculum], [trackType],
/// [calendarProgram], [learningProgram], [level], [item]) and three async
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
       _trackType = null,
       _calendarEntry = null,
       _learningProgram = null,
       _level = null,
       _rawValue = null,
       _parentL1Value = null,
       _hebrewName = null,
       _item = null,
       _itemMode = null,
       _sefariaRef = null;

  /// Renders a `TrackType` label (e.g. "Personal" / "אישי").
  const CurriculumLabel.trackType(
    TrackType trackType, {
    this.style,
    this.maxLines,
    this.overflow,
    this.textAlign,
    this.textDirection,
    super.key,
  }) : _kind = _Kind.trackType,
       _curriculumId = null,
       _trackType = trackType,
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
       _trackType = null,
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
       _trackType = null,
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
       _trackType = null,
       _calendarEntry = null,
       _learningProgram = null,
       _level = level,
       _rawValue = rawValue,
       _parentL1Value = parentL1Value,
       _hebrewName = hebrewName,
       _item = null,
       _itemMode = null,
       _sefariaRef = null;

  /// Renders a label from an already-loaded [ContentItem]. Sync.
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
       _trackType = null,
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
       _trackType = null,
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
       _trackType = null,
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
       _trackType = null,
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
  final TrackType? _trackType;
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
        final useHebrew = ref.watch(useHebrewTermsProvider);
        return _text(
          useHebrew
              ? _curriculumId!.displayNameHe
              : _curriculumId!.displayNameEn,
          useHebrew: useHebrew,
        );
      case _Kind.trackType:
        final useHebrew = ref.watch(useHebrewTermsProvider);
        return _text(
          useHebrew ? _trackType!.displayNameHe : _trackType!.displayNameEn,
          useHebrew: useHebrew,
        );
      case _Kind.calendarProgram:
        final useHebrew = ref.watch(useHebrewTermsProvider);
        return _text(
          useHebrew
              ? _calendarEntry!.displayNameHe
              : _calendarEntry!.displayNameEn,
          useHebrew: useHebrew,
        );
      case _Kind.learningProgram:
        final useHebrew = ref.watch(useHebrewTermsProvider);
        final program = _learningProgram!;
        final text = !useHebrew
            ? program.displayName
            : (CalendarProgramRegistry.byId(program.name)?.displayNameHe ??
                  program.displayName);
        return _text(text, useHebrew: useHebrew);
      case _Kind.level:
        final useHebrew = ref.watch(useHebrewTermsProvider);
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
        final useHebrew = ref.watch(useHebrewTermsProvider);
        final variant = ref.watch(currentTransliterationVariantProvider);
        return _text(_renderItem(useHebrew, variant), useHebrew: useHebrew);
      case _Kind.breadcrumb:
        final useHebrew = ref.watch(useHebrewTermsProvider);
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
        final useHebrew = ref.watch(useHebrewTermsProvider);
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
        final useHebrew = ref.watch(useHebrewTermsProvider);
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

  String _renderItem(bool useHebrew, TransliterationVariant variant) {
    switch (_itemMode!) {
      case CurriculumLabelMode.leaf:
        return CurriculumLabelRenderer.renderForItem(
          _item!,
          useHebrew: useHebrew,
          transliterationVariant: variant,
        );
      case CurriculumLabelMode.breadcrumb:
        return CurriculumLabelRenderer.renderForItem(
          _item!,
          useHebrew: useHebrew,
          fullPath: true,
          transliterationVariant: variant,
        );
      case CurriculumLabelMode.parent:
        return CurriculumLabelRenderer.renderParentForItem(
              _item!,
              useHebrew: useHebrew,
              transliterationVariant: variant,
            ) ??
            '';
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

  static TextDirection? _inferDirection(String text) {
    // Hebrew code block U+0590..U+05FF.
    return _hebrew.hasMatch(text) ? TextDirection.rtl : null;
  }

  static final RegExp _hebrew = RegExp('[֐-׿]');
}

enum _Kind {
  curriculum,
  trackType,
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

String _curriculumLabel(CurriculumId curriculum, bool useHebrew) =>
    useHebrew ? curriculum.displayNameHe : curriculum.displayNameEn;

/// Pure-string variant of [CurriculumLabel.curriculum] for AppBar titles,
/// dialog messages, sort keys, semantics labels — places that need a `String`
/// rather than a widget. Watches [useHebrewTermsProvider]. Use this from
/// widgets (ConsumerWidget, Consumer, hooks_riverpod).
String curriculumLabelText(WidgetRef ref, {required CurriculumId curriculum}) =>
    _curriculumLabel(curriculum, ref.watch(useHebrewTermsProvider));

/// Same as [curriculumLabelText] but takes a provider-side [Ref]. Use this
/// from inside provider/notifier closures where the closure parameter is
/// [Ref] rather than [WidgetRef]. Watches [useHebrewTermsProvider] so the
/// containing provider re-runs when the toggle changes.
String curriculumLabelTextFromRef(
  Ref ref, {
  required CurriculumId curriculum,
}) => _curriculumLabel(curriculum, ref.watch(useHebrewTermsProvider));

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

/// Pure-string variant of [CurriculumLabel.trackType]. Watches
/// [useHebrewTermsProvider].
String trackTypeLabelText(WidgetRef ref, {required TrackType trackType}) {
  final useHebrew = ref.watch(useHebrewTermsProvider);
  return useHebrew ? trackType.displayNameHe : trackType.displayNameEn;
}
