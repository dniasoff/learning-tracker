import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/labels/curriculum_label_providers.dart';
import 'package:learning_tracker/core/labels/curriculum_label_renderer.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/features/settings/presentation/providers/hebrew_terms_provider.dart';
import 'package:learning_tracker/features/settings/presentation/providers/transliteration_variant_provider.dart';

/// The single entry point for rendering any curriculum-aware label in the UI.
///
/// All six constructors delegate to [CurriculumLabelRenderer] and watch
/// [hebrewTermsScriptProvider] + [transliterationVariantProvider]. Callers
/// pass structured data ([CurriculumId], a level/value pair, a [ContentItem],
/// or a sefariaRef) — never a pre-rendered string. Screens that render labels
/// directly from enum fields are bypasses; the enforcement greps in the v1.0.60
/// release plan catch them.
///
/// Sync modes ([curriculum], [level], [item]) render immediately. Async modes
/// ([breadcrumb], [local], [parent]) look up a [ContentItem] from the
/// curriculum content provider and show a zero-width-space placeholder while
/// loading so line height stays stable across the fetch.
class CurriculumLabel extends ConsumerWidget {
  const CurriculumLabel.curriculum(
    CurriculumId id, {
    this.style,
    this.maxLines,
    this.overflow,
    this.textAlign,
    this.textDirection,
    super.key,
  })  : _kind = _Kind.curriculum,
        _curriculumId = id,
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
  })  : _kind = _Kind.level,
        _curriculumId = curriculumId,
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
  })  : _kind = _Kind.item,
        _curriculumId = null,
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
  })  : _kind = _Kind.breadcrumb,
        _curriculumId = null,
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
  })  : _kind = _Kind.local,
        _curriculumId = null,
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
  })  : _kind = _Kind.parent,
        _curriculumId = null,
        _level = null,
        _rawValue = null,
        _parentL1Value = null,
        _hebrewName = null,
        _item = null,
        _itemMode = null,
        _sefariaRef = sefariaRef;

  final _Kind _kind;
  final CurriculumId? _curriculumId;
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
        final useHebrew = ref.watch(hebrewTermsScriptProvider);
        return _text(
          useHebrew
              ? _curriculumId!.displayNameHe
              : _curriculumId!.displayNameEn,
        );
      case _Kind.level:
        final useHebrew = ref.watch(hebrewTermsScriptProvider);
        final variant = ref.watch(transliterationVariantProvider);
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
        );
      case _Kind.item:
        final useHebrew = ref.watch(hebrewTermsScriptProvider);
        final variant = ref.watch(transliterationVariantProvider);
        return _text(_renderItem(useHebrew, variant));
      case _Kind.breadcrumb:
        final r = _sefariaRef!;
        return ref.watch(renderedDisplayForRefProvider(r)).when(
              data: _text,
              loading: () => _text('​'),
              error: (_, __) => _text(r.replaceAll('_', ' ')),
            );
      case _Kind.local:
        final r = _sefariaRef!;
        return ref.watch(renderedLeafForRefProvider(r)).when(
              data: _text,
              loading: () => _text('​'),
              error: (_, __) => _text(r.replaceAll('_', ' ')),
            );
      case _Kind.parent:
        final r = _sefariaRef!;
        return ref.watch(renderedParentForRefProvider(r)).when(
              data: (s) => _text(s ?? ''),
              loading: () => _text('​'),
              error: (_, __) => _text(''),
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

  Widget _text(String text) => Text(
        text,
        style: style,
        maxLines: maxLines,
        overflow: overflow,
        textAlign: textAlign,
        textDirection: textDirection,
      );
}

enum _Kind { curriculum, level, item, breadcrumb, local, parent }

/// Mode for [CurriculumLabel.item]: which segment(s) of the item's path to
/// render.
enum CurriculumLabelMode { breadcrumb, leaf, parent }

String _curriculumLabel(CurriculumId curriculum, bool useHebrew) =>
    useHebrew ? curriculum.displayNameHe : curriculum.displayNameEn;

/// Pure-string variant of [CurriculumLabel.curriculum] for AppBar titles,
/// dialog messages, sort keys, semantics labels — places that need a `String`
/// rather than a widget. Watches [hebrewTermsScriptProvider]. Use this from
/// widgets (ConsumerWidget, Consumer, hooks_riverpod).
String curriculumLabelText(
  WidgetRef ref, {
  required CurriculumId curriculum,
}) =>
    _curriculumLabel(curriculum, ref.watch(hebrewTermsScriptProvider));

/// Same as [curriculumLabelText] but takes a provider-side [Ref]. Use this
/// from inside provider/notifier closures where the closure parameter is
/// [Ref] rather than [WidgetRef]. Watches [hebrewTermsScriptProvider] so the
/// containing provider re-runs when the toggle changes.
String curriculumLabelTextFromRef(
  Ref ref, {
  required CurriculumId curriculum,
}) =>
    _curriculumLabel(curriculum, ref.watch(hebrewTermsScriptProvider));

/// Returns the Hebrew form of a curriculum's name unconditionally. Use only
/// when both forms must be shown simultaneously (dual-language presentations
/// like the Lifetime curriculum row). Everywhere else, use [CurriculumLabel]
/// or [curriculumLabelText] so the Hebrew Terms toggle is respected.
String curriculumHebrewName(CurriculumId curriculum) => curriculum.displayNameHe;

/// Returns the English transliteration of a curriculum's name unconditionally.
/// Use ONLY for stable English-locale sort keys / locale-independent identifiers
/// (e.g. sort labels in filter dropdowns where the sort order must not flip
/// with the Hebrew Terms toggle). For user-facing display, use
/// [CurriculumLabel] or [curriculumLabelText].
String curriculumEnglishName(CurriculumId curriculum) =>
    curriculum.displayNameEn;
