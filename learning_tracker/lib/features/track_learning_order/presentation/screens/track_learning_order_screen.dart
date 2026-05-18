import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/labels/curriculum_label.dart';
import 'package:learning_tracker/core/labels/domain_term_labels.dart';
import 'package:learning_tracker/features/learning_order/domain/models/learning_order_item.dart';
import 'package:learning_tracker/features/learning_order/presentation/widgets/draggable_order_item.dart';
import 'package:learning_tracker/features/learning_order/presentation/widgets/reset_order_dialog.dart';
import 'package:learning_tracker/features/track_learning_order/presentation/providers/track_learning_order_providers.dart';

class TrackLearningOrderScreen extends ConsumerStatefulWidget {
  const TrackLearningOrderScreen({
    super.key,
    required this.trackId,
    required this.curriculumId,
  });

  final int trackId;
  final CurriculumId curriculumId;

  @override
  ConsumerState<TrackLearningOrderScreen> createState() =>
      _TrackLearningOrderScreenState();
}

class _TrackLearningOrderScreenState
    extends ConsumerState<TrackLearningOrderScreen> {
  List<LearningOrderItem>? _localSedarim;
  List<LearningOrderItem>? _localMasechtos;
  // Sequence counter so a slow sedarim-save can't overwrite a newer
  // local edit (race where invalidate fires multiple times in quick
  // reorders and the older fetch resolves last with stale data).
  int _sedarimSaveSeq = 0;

  @override
  Widget build(BuildContext context) {
    final args = (trackId: widget.trackId, curriculumId: widget.curriculumId);
    final sedarimAsync = ref.watch(trackSedarimOrderProvider(args));
    final masechtosAsync = ref.watch(trackMasechtosOrderProvider(args));

    sedarimAsync.whenData((items) {
      if (_localSedarim == null) _localSedarim = List.from(items);
    });
    masechtosAsync.whenData((items) {
      if (_localMasechtos == null) _localMasechtos = List.from(items);
    });

    final theme = Theme.of(context);
    final isLoading = sedarimAsync.isLoading || masechtosAsync.isLoading;
    final terms = domainTermLabels(ref);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${curriculumLabelText(ref, curriculum: widget.curriculumId)} • Reorder',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reset to Default Order',
            onPressed: () => _resetToDefault(context),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_localSedarim != null && _localSedarim!.isNotEmpty) ...[
                    _buildSectionHeader(
                      context,
                      theme,
                      CurriculumLabels.topSectionHeader(
                        widget.curriculumId,
                        useHebrew: terms.isHebrew,
                      ),
                    ),
                    ReorderableListView(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      onReorder: _onReorderSedarim,
                      children: [
                        for (var i = 0; i < _localSedarim!.length; i++)
                          DraggableOrderItem(
                            key: ValueKey(_localSedarim![i].sefariaRef),
                            item: _localSedarim![i],
                            index: i,
                          ),
                      ],
                    ),
                  ],
                  if (_localMasechtos != null &&
                      _localMasechtos!.isNotEmpty &&
                      CurriculumLabels.hasReorderableLevel2(
                        widget.curriculumId,
                      )) ...[
                    _buildSectionHeader(
                      context,
                      theme,
                      CurriculumLabels.containerSectionHeader(
                            widget.curriculumId,
                            useHebrew: terms.isHebrew,
                          ) ??
                          '',
                    ),
                    ReorderableListView(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      onReorder: _onReorderMasechtos,
                      children: [
                        for (var i = 0; i < _localMasechtos!.length; i++)
                          DraggableOrderItem(
                            key: ValueKey(_localMasechtos![i].sefariaRef),
                            item: _localMasechtos![i],
                            index: i,
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    ThemeData theme,
    String label,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        label,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  void _onReorderSedarim(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    final items = List<LearningOrderItem>.from(_localSedarim!);
    final moved = items.removeAt(oldIndex);
    items.insert(newIndex, moved);
    final updated = items
        .asMap()
        .entries
        .map(
          (e) => e.value.copyWith(userSortOrder: e.key, isCustomOrdered: true),
        )
        .toList();
    setState(() => _localSedarim = updated);
    _persistSedarim(updated);
  }

  void _onReorderMasechtos(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    final items = List<LearningOrderItem>.from(_localMasechtos!);
    final moved = items.removeAt(oldIndex);
    items.insert(newIndex, moved);
    final updated = items
        .asMap()
        .entries
        .map(
          (e) => e.value.copyWith(userSortOrder: e.key, isCustomOrdered: true),
        )
        .toList();
    setState(() => _localMasechtos = updated);
    _persistMasechtos(updated);
  }

  Future<void> _persistSedarim(List<LearningOrderItem> items) async {
    final mySeq = ++_sedarimSaveSeq;
    final args = (trackId: widget.trackId, curriculumId: widget.curriculumId);
    await ref
        .read(trackLearningOrderRepositoryProvider)
        .saveSedarimOrder(widget.trackId, items);
    if (!mounted || mySeq != _sedarimSaveSeq) return;
    ref.invalidate(trackSedarimOrderProvider(args));
    // Reordering sedarim shifts the natural grouping of masechtos below.
    // Wait for the fresh masechtos fetch before re-seeding the local
    // cache; the previous setState(null) approach could lock in the
    // stale cached value during the rebuild before the refetch landed.
    ref.invalidate(trackMasechtosOrderProvider(args));
    final freshMasechtos = await ref.read(
      trackMasechtosOrderProvider(args).future,
    );
    if (!mounted || mySeq != _sedarimSaveSeq) return;
    setState(() => _localMasechtos = List.from(freshMasechtos));
  }

  void _persistMasechtos(List<LearningOrderItem> items) {
    final args = (trackId: widget.trackId, curriculumId: widget.curriculumId);
    ref
        .read(trackLearningOrderRepositoryProvider)
        .saveMasechtosOrder(widget.trackId, items)
        .then((_) => ref.invalidate(trackMasechtosOrderProvider(args)));
  }

  Future<void> _resetToDefault(BuildContext context) async {
    final confirmed = await ResetOrderDialog.show(context);
    if (!confirmed) return;

    final args = (trackId: widget.trackId, curriculumId: widget.curriculumId);
    await ref
        .read(trackLearningOrderRepositoryProvider)
        .resetToDefault(widget.trackId);

    setState(() {
      _localSedarim = null;
      _localMasechtos = null;
    });
    ref.invalidate(trackSedarimOrderProvider(args));
    ref.invalidate(trackMasechtosOrderProvider(args));
  }
}
