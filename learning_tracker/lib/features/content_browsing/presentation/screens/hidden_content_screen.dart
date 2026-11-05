import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/features/content_browsing/domain/hidden_content.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/active_tutored_profile_provider.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

@RoutePage()
class HiddenContentScreen extends ConsumerStatefulWidget {
  const HiddenContentScreen({super.key});

  @override
  ConsumerState<HiddenContentScreen> createState() =>
      _HiddenContentScreenState();
}

class _HiddenContentScreenState extends ConsumerState<HiddenContentScreen> {
  Set<String>? _selected;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final refsAsync = ref.watch(hiddenContentRefsProvider);
    final rowsAsync = ref.watch(_hiddenContentRowsProvider);
    final current = refsAsync.asData?.value ?? const <String>{};
    final selected = _selected ?? current;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.hiddenContentTitle),
        actions: [
          TextButton(
            onPressed: _saving || rowsAsync.hasError
                ? null
                : () => setState(
                    () => _selected = {...suggestedHiddenContentRefs},
                  ),
            child: Text(l10n.hiddenContentSuggested),
          ),
          TextButton(
            onPressed: _saving || refsAsync.isLoading || rowsAsync.hasError
                ? null
                : () => _save(selected),
            child: Text(l10n.save),
          ),
        ],
      ),
      body: rowsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text(l10n.hiddenContentLoadError(error.toString()))),
        data: (rows) => ListView.builder(
          itemCount: rows.length,
          itemBuilder: (context, index) {
            final row = rows[index];
            if (row.isHeader) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                child: Text(
                  row.label,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              );
            }
            return CheckboxListTile(
              value: selected.contains(row.ref),
              contentPadding: EdgeInsets.only(
                left: 16.0 + row.depth * 24,
                right: 16,
              ),
              title: Text(row.label),
              onChanged: _saving
                  ? null
                  : (checked) => setState(() {
                      final next = {...selected};
                      if (checked ?? false) {
                        next.add(row.ref!);
                      } else {
                        next.remove(row.ref);
                      }
                      _selected = next;
                    }),
            );
          },
        ),
      ),
    );
  }

  Future<void> _save(Set<String> refs) async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _saving = true);
    try {
      final selection = ref.read(activeTutoredProfileSelectionProvider);
      if (selection != null) {
        final repository = await ref.read(
          hiddenContentRepositoryProvider.future,
        );
        if (repository == null) throw StateError('Profile is not ready');
        await repository.setHiddenRefs(
          refs,
          grantId: selection.grantId,
          ownerUid: selection.ownerUid,
        );
      } else {
        final repository = await ref.read(
          hiddenContentRepositoryProvider.future,
        );
        if (repository == null) throw StateError('Profile is not ready');
        await repository.setHiddenRefs(refs);
      }
      ref.invalidate(hiddenContentRefsProvider);
      if (mounted) {
        setState(() => _selected = refs);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.hiddenContentSaved)));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.hiddenContentSaveError(error.toString())),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

final _hiddenContentRowsProvider =
    FutureProvider.autoDispose<List<_HiddenContentRow>>((ref) async {
      final raw = ref.read(contentRepositoryProvider);
      final rows = <_HiddenContentRow>[];
      for (final curriculum in CurriculumId.all) {
        final items = await raw.getContentForCurriculum(curriculum);
        rows.add(_HiddenContentRow.header(curriculum.displayNameEn));
        rows.addAll(
          items.map(
            (item) => _HiddenContentRow.item(
              item.sefariaRef,
              item.displayNameEn,
              _depth(item),
            ),
          ),
        );
      }
      return rows;
    });

int _depth(ContentItem item) {
  if (item.level4 != null) return 3;
  if (item.level3 != null) return 2;
  if (item.level2 != null) return 1;
  return 0;
}

class _HiddenContentRow {
  const _HiddenContentRow._({required this.label, this.ref, this.depth = 0});

  const _HiddenContentRow.header(String label) : this._(label: label);

  const _HiddenContentRow.item(String ref, String label, int depth)
    : this._(label: label, ref: ref, depth: depth);

  final String label;
  final String? ref;
  final int depth;

  bool get isHeader => ref == null;
}
