import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/labels/curriculum_label.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/widgets/app_bar_title.dart';
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

  String _labelForLevel(int level) {
    final labels = CurriculumLabels.labelsEn(widget.curriculumId);
    return level <= labels.length ? labels[level - 1] : 'Level $level';
  }

  @override
  Widget build(BuildContext context) {
    final contentAsync = ref.watch(
      curriculumContentProvider(widget.curriculumId),
    );

    return Scaffold(
      appBar: AppBar(
        title: AppBarTitle(
          text:
              'Learning Scope — '
              '${curriculumLabelText(ref, curriculum: widget.curriculumId)}',
        ),
        actions: [TextButton(onPressed: _save, child: Text(AppLocalizations.of(context)!.scopeSelectionSave))],
      ),
      body: SafeArea(
        top: false,
        child: contentAsync.when(
          data: (items) => _buildBody(items),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text(AppLocalizations.of(context)!.errorGeneric(e.toString()))),
        ),
      ),
    );
  }

  Widget _buildBody(List<ContentItem> allItems) {
    return ListView(
      children: [
        // "All" option
        SwitchListTile(
          title: Text(AppLocalizations.of(context)!.scopeSelectionTrackEntireCurriculum),
          subtitle: Text(
            _selectAll
                ? 'All content is included'
                : 'Only selected sections are tracked',
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

        if (!_selectAll) ...[
          // Level selection
          if (_selectedLevel == null) ...[
            ListTile(
              title: const Text(
                'Select Scope Level',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(AppLocalizations.of(context)!.scopeSelectionChooseHierarchyLevel),
            ),
            // Only show levels that make sense for scoping (not leaf level)
            for (var level = 1; level < _maxLevels; level++)
              ListTile(
                title: Text(_labelForLevel(level)),
                subtitle: Text(
                  '${_getDistinctValuesAtLevel(allItems, level).length} options',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  setState(() {
                    _selectedLevel = level;
                    _selectedValues.clear();
                  });
                },
              ),
          ] else ...[
            // Show values at selected level for multi-select
            ListTile(
              title: Text(
                AppLocalizations.of(context)!.scopeSelectionSelectLevel(_labelForLevel(_selectedLevel!)),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(AppLocalizations.of(context)!.scopeSelectionCountSelected(_selectedValues.length)),
              trailing: TextButton(
                onPressed: () {
                  setState(() {
                    _selectedLevel = null;
                    _selectedValues.clear();
                  });
                },
                child: Text(AppLocalizations.of(context)!.scopeSelectionChangeLevel),
              ),
            ),
            const Divider(),
            ..._buildLevelValueTiles(allItems),
          ],
        ],

        // Summary
        if (_selectedValues.isNotEmpty) ...[
          const Divider(height: 32),
          ListTile(
            title: const Text(
              'Summary',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(_selectedValues.join(', ')),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '${_countLeafItems(allItems)} items will be tracked',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ],
    );
  }

  List<Widget> _buildLevelValueTiles(List<ContentItem> allItems) {
    final values = _getDistinctValuesAtLevel(allItems, _selectedLevel!);
    return values.map((value) {
      final isSelected = _selectedValues.contains(value);
      final leafCount = _countLeafItemsForValue(allItems, value);
      return CheckboxListTile(
        title: Text(value),
        subtitle: Text(AppLocalizations.of(context)!.scopeSelectionItemCount(leafCount)),
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
    }).toList();
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

  Future<void> _save() async {
    final db = ref.read(userDatabaseProvider);
    final profileId = ref.read(activeProfileIdProvider);

    // Look up trackId for this curriculum
    final track =
        await (db.select(db.curriculumTracks)
              ..where(
                (t) =>
                    t.profileId.equals(profileId) &
                    t.curriculumId.equals(widget.curriculumId.storageKey),
              )
              ..limit(1))
            .getSingleOrNull();
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
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _selectAll
                ? 'Scope set to entire curriculum'
                : 'Scope updated: ${_selectedValues.join(", ")}',
          ),
        ),
      );
    }
  }
}
