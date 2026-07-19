import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/labels/curriculum_label.dart';
import 'package:learning_tracker/core/labels/curriculum_label_renderer.dart';
import 'package:learning_tracker/core/labels/domain_term_labels.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/widgets/app_bar_title.dart';
import 'package:learning_tracker/core/widgets/app_error_view.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/settings/presentation/providers/curriculum_scope_providers.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Screen for selecting which parts of a curriculum to track.
///
/// Supports multi-select at a single hierarchy level.
/// Push this screen from Settings or Onboarding.
class ScopeSelectionScreen extends ConsumerStatefulWidget {
  const ScopeSelectionScreen({super.key, required this.curriculumId});

  final CurriculumId curriculumId;

  @override
  ConsumerState<ScopeSelectionScreen> createState() =>
      _ScopeSelectionScreenState();
}

class _ScopeSelectionScreenState extends ConsumerState<ScopeSelectionScreen> {
  /// The hierarchy level being selected (1-based). Null = choosing level.
  int? _selectedLevel;

  /// Currently selected scope values at the chosen level.
  final Set<String> _selectedValues = {};

  /// Hebrew proper name for each raw scope value at [_selectedLevel], keyed by
  /// the raw value (e.g. "Berakhos" → "ברכות"). Populated from the loaded
  /// content whenever a level is chosen so [CurriculumLabelRenderer.renderValue]
  /// can emit the real Hebrew name (named levels) rather than echoing the raw
  /// English storage key. Empty until content + a level are available.
  final Map<String, String> _hebrewNameByValue = {};

  /// Level-1 raw value for each scope value at [_selectedLevel] (its
  /// per-curriculum level-override context). Lets the renderer resolve
  /// book-specific level labels (e.g. Mussar's Shaarim vs Perakim).
  final Map<String, String> _parentL1ByValue = {};

  /// Whether "All" is selected (no scope restrictions).
  bool _selectAll = true;

  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _loadExistingScopes();
    }
  }

  Future<void> _loadExistingScopes() async {
    final db = ref.read(userDatabaseProvider);
    final profileId = ref.read(activeProfileIdProvider);
    final scopes = await db.curriculumScopeDao.getScopes(
      profileId,
      widget.curriculumId,
    );
    if (scopes.isEmpty) {
      setState(() => _selectAll = true);
    } else {
      setState(() {
        _selectAll = false;
        _selectedLevel = scopes.first.scopeLevel;
        _selectedValues.addAll(scopes.map((s) => s.scopeValue));
      });
    }
  }

  int get _maxLevels => CurriculumLabels.depth(widget.curriculumId);

  /// Variant-aware level WORD (e.g. "Masechta" / "Masekhta" / "מסכת"),
  /// honouring the Hebrew Terms toggle and the current nusach.
  String _labelForLevel(int level) {
    final terms = domainTermLabels(ref);
    final variant = ref.watch(currentTransliterationVariantProvider);
    final labels = CurriculumLabels.labelsForVariant(
      widget.curriculumId,
      useHebrew: terms.isHebrew,
      variant: variant,
    );
    return level <= labels.length ? labels[level - 1] : 'Level $level';
  }

  /// Render a raw scope storage key (e.g. "Zeraim"/"Berakhos") into the
  /// proper display name for [level], honouring Hebrew Terms + nusach.
  ///
  /// Supplies the matching Hebrew proper name + level-1 context (captured in
  /// [_hebrewNameByValue]/[_parentL1ByValue] from the loaded content) so named
  /// levels render the real Hebrew name in Hebrew mode instead of echoing the
  /// raw English storage key.
  ///
  /// [useHebrew]/[variant] are passed in rather than read from `ref`
  /// internally: this is called both synchronously during `build()`
  /// (`_renderSelectedValues`, safe to `ref.watch`) and from
  /// [_buildValueTile], invoked lazily and on demand by the value list's
  /// `SliverChildBuilderDelegate` — including on later scroll frames, well
  /// after `build()` has returned. `ref.watch` must only be called while
  /// this widget is actively building; reading it from that later,
  /// lazily-invoked call would call `ref.watch` outside the build phase.
  /// Precomputing the toggle-derived values once during `build()` and
  /// threading them through as plain data keeps every call site safe,
  /// mirroring how `core/content/hierarchy_browser.dart` hoists its own
  /// `ref.watch(currentTransliterationVariantProvider)` out of its
  /// `itemBuilder`.
  String _renderValueForLevel(
    String rawValue,
    int level, {
    required bool useHebrew,
    required TransliterationVariant variant,
  }) {
    return CurriculumLabelRenderer.renderValue(
      curriculumId: widget.curriculumId,
      level: level,
      rawValue: rawValue,
      useHebrew: useHebrew,
      hebrewName: _hebrewNameByValue[rawValue],
      parentL1Value: _parentL1ByValue[rawValue],
      transliterationVariant: variant,
    );
  }

  /// Refresh [_hebrewNameByValue]/[_parentL1ByValue] for the current
  /// [_selectedLevel] from the loaded [items]. The representative row for a
  /// value is the container item whose deepest populated level is exactly the
  /// selected level (its Hebrew display name is the proper name for that level).
  void _refreshValueNames(List<ContentItem> items, int level) {
    _hebrewNameByValue.clear();
    _parentL1ByValue.clear();
    for (final item in items) {
      final value = _getItemLevelValue(item, level);
      if (value == null) continue;
      _parentL1ByValue.putIfAbsent(value, () => item.level1);
      // Prefer the container row (no deeper level) so the Hebrew name is the
      // name *at* this level, not a descendant leaf's name.
      final isContainerForLevel = _getItemLevelValue(item, level + 1) == null;
      if (isContainerForLevel && !_hebrewNameByValue.containsKey(value)) {
        // Use the sanctioned core/labels accessor (DNI-386: no direct
        // Hebrew-name field reads outside core/labels).
        final hebrewName = CurriculumLabelRenderer.hebrewNameOf(item);
        if (hebrewName != null) _hebrewNameByValue[value] = hebrewName;
      }
    }
  }

  /// Render every currently-selected raw value at [_selectedLevel] into a
  /// comma-joined display string. Falls back to the raw values when no level
  /// is chosen (should not happen while values are selected).
  String _renderSelectedValues() {
    final level = _selectedLevel;
    if (level == null) return _selectedValues.join(', ');
    final terms = domainTermLabels(ref);
    final variant = ref.watch(currentTransliterationVariantProvider);
    return _selectedValues
        .map(
          (v) => _renderValueForLevel(
            v,
            level,
            useHebrew: terms.isHebrew,
            variant: variant,
          ),
        )
        .join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final contentAsync = ref.watch(
      curriculumContentProvider(widget.curriculumId),
    );

    return Scaffold(
      appBar: AppBar(
        title: AppBarTitle(
          text: AppLocalizations.of(context)!.scopeSelectionTitle(
            curriculumLabelText(ref, curriculum: widget.curriculumId),
          ),
        ),
        actions: [
          TextButton(
            // Disabled for an empty subset: with "select all" OFF and no values
            // ticked, _save() would write nothing yet still pop with a success
            // snackbar — telling the user the scope was saved while the previous
            // scope silently survives. Require either "select all" or ≥1 value.
            onPressed: _canSave ? _save : null,
            child: Text(AppLocalizations.of(context)!.scopeSelectionSave),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: contentAsync.when(
          data: (items) => _buildBody(items),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => AppErrorView(
            error: e,
            stackTrace: st,
            onRetry: () =>
                ref.refresh(curriculumContentProvider(widget.curriculumId)),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(List<ContentItem> allItems) {
    // Keep the value→Hebrew-name lookup in step with the loaded content and
    // the currently chosen level so the summary / snackbar / checkbox titles
    // all render proper names (not raw storage keys).
    final selectedLevel = _selectedLevel;
    if (selectedLevel != null) {
      _refreshValueNames(allItems, selectedLevel);
    }
    // Computed once per build (not re-derived per row) — the list this
    // feeds can run into the hundreds for a deep curriculum level (e.g.
    // Mishna Berurah's "Siman" level, ~697 distinct values), so this is the
    // collection the AUD-settings-08 fix routes through a lazy
    // SliverList/SliverChildBuilderDelegate below instead of eagerly
    // realizing every CheckboxListTile up front.
    final valuesAtLevel = selectedLevel != null
        ? _getDistinctValuesAtLevel(allItems, selectedLevel)
        : const <String>[];
    // Read once here (safe — still synchronous inside build()) and threaded
    // through as plain data into the lazy SliverChildBuilderDelegate below;
    // see _renderValueForLevel's doc comment for why the itemBuilder itself
    // must never call ref.watch.
    final termsForValueTiles = domainTermLabels(ref);
    final variantForValueTiles = ref.watch(
      currentTransliterationVariantProvider,
    );

    return CustomScrollView(
      slivers: [
        // "All" option
        SliverToBoxAdapter(
          child: Column(
            children: [
              SwitchListTile(
                title: Text(
                  AppLocalizations.of(
                    context,
                  )!.scopeSelectionTrackEntireCurriculum,
                ),
                subtitle: Text(
                  _selectAll
                      ? AppLocalizations.of(
                          context,
                        )!.scopeSelectionAllContentIncluded
                      : AppLocalizations.of(
                          context,
                        )!.scopeSelectionOnlySelectedTracked,
                ),
                value: _selectAll,
                onChanged: (value) {
                  setState(() {
                    _selectAll = value;
                    if (value) {
                      _selectedLevel = null;
                      _selectedValues.clear();
                    }
                  });
                },
              ),
              const Divider(),
            ],
          ),
        ),

        if (!_selectAll) ...[
          // Level selection — always a handful of rows (bounded by the
          // curriculum's depth), so a plain (non-scrolling) Column inside
          // one sliver is fine; the unbounded collection is the per-value
          // list below, not this one.
          if (selectedLevel == null)
            SliverToBoxAdapter(
              child: Column(
                children: [
                  ListTile(
                    title: Text(
                      AppLocalizations.of(
                        context,
                      )!.scopeSelectionSelectScopeLevel,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      AppLocalizations.of(
                        context,
                      )!.scopeSelectionChooseHierarchyLevel,
                    ),
                  ),
                  // Only show levels that make sense for scoping (not leaf
                  // level).
                  for (var level = 1; level < _maxLevels; level++)
                    ListTile(
                      title: Text(_labelForLevel(level)),
                      subtitle: Text(
                        AppLocalizations.of(
                          context,
                        )!.scopeSelectionOptionsCount(
                          _getDistinctValuesAtLevel(allItems, level).length,
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        setState(() {
                          _selectedLevel = level;
                          _selectedValues.clear();
                        });
                      },
                    ),
                ],
              ),
            )
          else ...[
            SliverToBoxAdapter(
              child: Column(
                children: [
                  ListTile(
                    title: Text(
                      AppLocalizations.of(context)!.scopeSelectionSelectLevel(
                        _labelForLevel(selectedLevel),
                      ),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      AppLocalizations.of(
                        context,
                      )!.scopeSelectionCountSelected(_selectedValues.length),
                    ),
                    trailing: TextButton(
                      onPressed: () {
                        setState(() {
                          _selectedLevel = null;
                          _selectedValues.clear();
                        });
                      },
                      child: Text(
                        AppLocalizations.of(context)!.scopeSelectionChangeLevel,
                      ),
                    ),
                  ),
                  const Divider(),
                ],
              ),
            ),
            // AUD-settings-08 (PF-2): lazy — only the on-screen (plus a
            // small cache-extent overscan) subset of `valuesAtLevel` is
            // ever built, unlike the previous bare
            // `ListView(children: values.map(...).toList())`.
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _buildValueTile(
                  allItems,
                  valuesAtLevel,
                  index,
                  useHebrew: termsForValueTiles.isHebrew,
                  variant: variantForValueTiles,
                ),
                childCount: valuesAtLevel.length,
              ),
            ),
          ],
        ],

        // Summary
        if (_selectedValues.isNotEmpty)
          SliverToBoxAdapter(
            child: Column(
              children: [
                const Divider(height: 32),
                ListTile(
                  title: Text(
                    AppLocalizations.of(context)!.scopeSelectionSummary,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(_renderSelectedValues()),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    AppLocalizations.of(
                      context,
                    )!.scopeSelectionItemsWillBeTracked(
                      _countLeafItems(allItems),
                    ),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// Builds a single checkbox row for `values[index]` at [_selectedLevel].
  ///
  /// Called on demand by the [SliverChildBuilderDelegate] in [_buildBody]
  /// — only for indices actually realized (visible + cache-extent
  /// overscan), never eagerly for the whole [values] list. [useHebrew]/
  /// [variant] are precomputed by the caller — see
  /// [_renderValueForLevel]'s doc comment for why this method must never
  /// read them from `ref` itself.
  Widget _buildValueTile(
    List<ContentItem> allItems,
    List<String> values,
    int index, {
    required bool useHebrew,
    required TransliterationVariant variant,
  }) {
    final level = _selectedLevel!;
    final value = values[index];
    final isSelected = _selectedValues.contains(value);
    final leafCount = _countLeafItemsForValue(allItems, value);
    return CheckboxListTile(
      title: Text(
        _renderValueForLevel(
          value,
          level,
          useHebrew: useHebrew,
          variant: variant,
        ),
      ),
      subtitle: Text(
        AppLocalizations.of(context)!.scopeSelectionItemCount(leafCount),
      ),
      value: isSelected,
      onChanged: (checked) {
        setState(() {
          if (checked ?? false) {
            _selectedValues.add(value);
          } else {
            _selectedValues.remove(value);
          }
        });
      },
    );
  }

  List<String> _getDistinctValuesAtLevel(List<ContentItem> items, int level) {
    final seen = <String>{};
    final result = <String>[];
    for (final item in items) {
      final value = _getItemLevelValue(item, level);
      if (value != null && seen.add(value)) {
        result.add(value);
      }
    }
    return result;
  }

  String? _getItemLevelValue(ContentItem item, int level) {
    return switch (level) {
      1 => item.level1,
      2 => item.level2,
      3 => item.level3,
      4 => item.level4,
      _ => null,
    };
  }

  int _countLeafItems(List<ContentItem> allItems) {
    if (_selectedLevel == null || _selectedValues.isEmpty) {
      return allItems.where((i) => i.isLeaf).length;
    }
    return allItems
        .where(
          (item) =>
              item.isLeaf &&
              _selectedValues.contains(
                _getItemLevelValue(item, _selectedLevel!),
              ),
        )
        .length;
  }

  int _countLeafItemsForValue(List<ContentItem> allItems, String value) {
    return allItems
        .where(
          (item) =>
              item.isLeaf && _getItemLevelValue(item, _selectedLevel!) == value,
        )
        .length;
  }

  /// Save is meaningful only when the whole curriculum is selected, or a
  /// specific subset (≥1 value) has been ticked. An empty subset would no-op.
  bool get _canSave => _selectAll || _selectedValues.isNotEmpty;

  Future<void> _save() async {
    final db = ref.read(userDatabaseProvider);
    final profileId = ref.read(activeProfileIdProvider);

    // Look up trackId for this curriculum.
    // AUD-settings-06: reuse TrackDao's (profileId, curriculumId) -> track
    // lookup instead of re-implementing it inline (see the DAO method's doc
    // comment for the tutored-mirror id-resolution rule this centralizes).
    final track = await db.trackDao.getTrackByProfileAndCurriculum(
      profileId,
      widget.curriculumId.storageKey,
    );
    final trackId = track?.id ?? 0;

    if (_selectAll) {
      await db.curriculumScopeDao.clearScopes(profileId, widget.curriculumId);
    } else if (_selectedLevel != null && _selectedValues.isNotEmpty) {
      await db.curriculumScopeDao.setScopes(
        profileId,
        widget.curriculumId,
        trackId,
        _selectedLevel!,
        _selectedValues.toList(),
      );
    }

    // Invalidate dependent providers
    ref.invalidate(curriculumScopeSummaryProvider(widget.curriculumId));
    ref.invalidate(scopedCurriculumContentProvider(widget.curriculumId));
    ref.invalidate(scopedItemCountProvider(widget.curriculumId));

    if (mounted) {
      // Render values BEFORE pop() while `ref` is still valid; the
      // "Scope updated:" frame is localized, and the VALUES honour Hebrew
      // Terms + nusach.
      final renderedValues = _renderSelectedValues();
      final localizations = AppLocalizations.of(context)!;
      final message = _selectAll
          ? localizations.scopeSelectionScopeSetEntireCurriculum
          : localizations.scopeSelectionScopeUpdated(renderedValues);
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }
}
