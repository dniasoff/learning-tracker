import 'dart:async' show unawaited;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/labels/curriculum_label.dart';
import 'package:learning_tracker/core/labels/domain_term_labels.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/widgets/app_error_view.dart';
import 'package:learning_tracker/features/tracks/track_order/presentation/providers/track_learning_order_providers.dart';
import 'package:learning_tracker/features/tracks/whole_curriculum_order/domain/models/learning_order_item.dart';
import 'package:learning_tracker/features/tracks/whole_curriculum_order/presentation/widgets/draggable_order_item.dart';
import 'package:learning_tracker/features/tracks/whole_curriculum_order/presentation/widgets/reorder_amnesty_guard_mixin.dart';
import 'package:learning_tracker/features/tracks/whole_curriculum_order/presentation/widgets/reset_order_dialog.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

class TrackLearningOrderScreen extends ConsumerStatefulWidget {
  const TrackLearningOrderScreen({super.key, required this.curriculumId});

  final CurriculumId curriculumId;

  @override
  ConsumerState<TrackLearningOrderScreen> createState() =>
      _TrackLearningOrderScreenState();
}

class _TrackLearningOrderScreenState
    extends ConsumerState<TrackLearningOrderScreen>
    with ReorderAmnestyGuardMixin<TrackLearningOrderScreen> {
  List<LearningOrderItem>? _localSedarim;
  List<LearningOrderItem>? _localMasechtos;
  // Sequence counter so a slow sedarim-save can't overwrite a newer
  // local edit (race where invalidate fires multiple times in quick
  // reorders and the older fetch resolves last with stale data).
  int _sedarimSaveSeq = 0;

  @override
  Widget build(BuildContext context) {
    final curriculumId = widget.curriculumId;
    final sedarimAsync = ref.watch(trackSedarimOrderProvider(curriculumId));
    final masechtosAsync = ref.watch(trackMasechtosOrderProvider(curriculumId));

    sedarimAsync.whenData((items) {
      if (_localSedarim == null) _localSedarim = List.from(items);
    });
    masechtosAsync.whenData((items) {
      if (_localMasechtos == null) _localMasechtos = List.from(items);
    });

    final theme = Theme.of(context);
    final isLoading = sedarimAsync.isLoading || masechtosAsync.isLoading;
    final terms = domainTermLabels(ref);
    final variant = ref.watch(currentTransliterationVariantProvider);
    final failedOrder = sedarimAsync.hasError
        ? sedarimAsync
        : masechtosAsync.hasError
        ? masechtosAsync
        : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context)!.trackReorderScreenTitle(
            curriculumLabelText(ref, curriculum: widget.curriculumId),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: AppLocalizations.of(context)!.resetToDefaultOrder,
            onPressed: () => _resetToDefault(context),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : failedOrder != null
          ? AppErrorView(
              error: failedOrder.error!,
              stackTrace: failedOrder.stackTrace,
              onRetry: () {
                ref.invalidate(trackSedarimOrderProvider(curriculumId));
                ref.invalidate(trackMasechtosOrderProvider(curriculumId));
              },
            )
          : CustomScrollView(
              slivers: [
                if (_localSedarim != null && _localSedarim!.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: _buildSectionHeader(
                      context,
                      theme,
                      CurriculumLabels.topSectionHeader(
                        widget.curriculumId,
                        useHebrew: terms.isHebrew,
                        variant: variant,
                      ),
                    ),
                  ),
                  SliverReorderableList(
                    itemCount: _localSedarim!.length,
                    itemBuilder: (context, index) => DraggableOrderItem(
                      key: ValueKey(_localSedarim![index].sefariaRef),
                      item: _localSedarim![index],
                      index: index,
                    ),
                    onReorderItem: _onReorderSedarim,
                    proxyDecorator: _dragProxyDecorator,
                  ),
                ],
                if (_localMasechtos != null &&
                    _localMasechtos!.isNotEmpty &&
                    CurriculumLabels.hasReorderableLevel2(
                      widget.curriculumId,
                    )) ...[
                  SliverToBoxAdapter(
                    child: _buildSectionHeader(
                      context,
                      theme,
                      CurriculumLabels.containerSectionHeader(
                            widget.curriculumId,
                            useHebrew: terms.isHebrew,
                            variant: variant,
                          ) ??
                          '',
                    ),
                  ),
                  SliverReorderableList(
                    itemCount: _localMasechtos!.length,
                    itemBuilder: (context, index) => DraggableOrderItem(
                      key: ValueKey(_localMasechtos![index].sefariaRef),
                      item: _localMasechtos![index],
                      index: index,
                    ),
                    onReorderItem: _onReorderMasechtos,
                    proxyDecorator: _dragProxyDecorator,
                  ),
                ],
                const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
              ],
            ),
    );
  }

  // Unlike ReorderableListView, SliverReorderableList (used directly here
  // so the masechtos section can stay lazy — AUD-tracks-05) ships no
  // default proxyDecorator: while a drag is underway it lifts the dragged
  // item into the Overlay, outside the Scaffold's Material ancestry, so
  // DraggableOrderItem's bare ListTile hits debugCheckHasMaterial. Mirror
  // ReorderableListView's own default decorator (Material + elevation
  // animation) so the drag proxy has an ancestor Material of its own.
  Widget _dragProxyDecorator(
    Widget child,
    int index,
    Animation<double> animation,
  ) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final animValue = Curves.easeInOut.transform(animation.value);
        final elevation = lerpDouble(0, 6, animValue)!;
        return Material(elevation: elevation, child: child);
      },
      child: child,
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
        // DNI-341: infer RTL for Hebrew-script labels so the header aligns
        // with the list items below it even inside an LTR Directionality.
        // AUD-tracks-18: shares CurriculumLabel's canonical detector instead
        // of a private RegExp copy.
        textDirection: CurriculumLabel.isHebrewText(label)
            ? TextDirection.rtl
            : null,
      ),
    );
  }

  Future<void> _onReorderSedarim(int oldIndex, int newIndex) async {
    if (!await confirmReorderAmnesty(ref, context, widget.curriculumId)) {
      return;
    }

    final previous = _localSedarim;
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
    unawaited(_persistSedarim(updated, previous));
  }

  Future<void> _onReorderMasechtos(int oldIndex, int newIndex) async {
    if (!await confirmReorderAmnesty(ref, context, widget.curriculumId)) {
      return;
    }

    final previous = _localMasechtos;
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
    unawaited(_persistMasechtos(updated, previous));
  }

  Future<void> _persistSedarim(
    List<LearningOrderItem> items,
    List<LearningOrderItem>? previous,
  ) async {
    final mySeq = ++_sedarimSaveSeq;
    final curriculumId = widget.curriculumId;
    try {
      await ref
          .read(trackLearningOrderRepositoryProvider)
          .saveSedarimOrder(widget.curriculumId, items);
    } on Exception catch (e, st) {
      AppLogger.instance.error(
        event:
            'track_sedarim_order_save_failed: curriculumId=${widget.curriculumId}',
        exception: e,
        stackTrace: st,
      );
      if (!mounted || mySeq != _sedarimSaveSeq) return;
      setState(() => _localSedarim = previous);
      _showOrderSaveError();
      return;
    }
    if (!mounted || mySeq != _sedarimSaveSeq) return;
    ref.invalidate(trackSedarimOrderProvider(curriculumId));
    // Reordering sedarim shifts the natural grouping of masechtos below.
    // Wait for the fresh masechtos fetch before re-seeding the local
    // cache; the previous setState(null) approach could lock in the
    // stale cached value during the rebuild before the refetch landed.
    ref.invalidate(trackMasechtosOrderProvider(curriculumId));
    final freshMasechtos = await ref.read(
      trackMasechtosOrderProvider(curriculumId).future,
    );
    if (!mounted || mySeq != _sedarimSaveSeq) return;
    setState(() => _localMasechtos = List.from(freshMasechtos));
  }

  Future<void> _persistMasechtos(
    List<LearningOrderItem> items,
    List<LearningOrderItem>? previous,
  ) async {
    final curriculumId = widget.curriculumId;
    try {
      await ref
          .read(trackLearningOrderRepositoryProvider)
          .saveMasechtosOrder(widget.curriculumId, items);
    } on Exception catch (e, st) {
      AppLogger.instance.error(
        event:
            'track_masechtos_order_save_failed: curriculumId=${widget.curriculumId}',
        exception: e,
        stackTrace: st,
      );
      if (!mounted) return;
      setState(() => _localMasechtos = previous);
      _showOrderSaveError();
      return;
    }
    if (!mounted) return;
    ref.invalidate(trackMasechtosOrderProvider(curriculumId));
  }

  void _showOrderSaveError() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context)!.learningOrderSaveFailed),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showOrderResetError() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context)!.learningOrderResetFailed),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _resetToDefault(BuildContext context) async {
    final confirmed = await ResetOrderDialog.show(context);
    if (!confirmed) return;

    final curriculumId = widget.curriculumId;
    // Bump the save sequence so any in-flight sedarim persist can't resolve
    // last and clobber the reset with its stale masechtos snapshot.
    final mySeq = ++_sedarimSaveSeq;
    try {
      await ref
          .read(trackLearningOrderRepositoryProvider)
          .resetToDefault(widget.curriculumId);
    } on Exception catch (e, st) {
      AppLogger.instance.error(
        event: 'track_order_reset_failed: curriculumId=${widget.curriculumId}',
        exception: e,
        stackTrace: st,
      );
      if (!mounted) return;
      _showOrderResetError();
      return;
    }
    if (!mounted || mySeq != _sedarimSaveSeq) return;

    // Invalidate both providers, then await the fresh default orders and seed
    // them into local state directly. Relying on a `_local* = null` reset plus
    // re-seeding via `whenData` in build() is racy: an invalidated
    // FutureProvider keeps exposing its previous (custom-order) value while the
    // refetch is loading, so a rebuild that lands first re-seeds the stale
    // custom order and the later default emission is then ignored — leaving the
    // UI showing the old order until manual re-navigation.
    ref.invalidate(trackSedarimOrderProvider(curriculumId));
    ref.invalidate(trackMasechtosOrderProvider(curriculumId));
    final defaultSedarim = await ref.read(
      trackSedarimOrderProvider(curriculumId).future,
    );
    final defaultMasechtos = await ref.read(
      trackMasechtosOrderProvider(curriculumId).future,
    );
    if (!mounted || mySeq != _sedarimSaveSeq) return;
    setState(() {
      _localSedarim = List.from(defaultSedarim);
      _localMasechtos = List.from(defaultMasechtos);
    });
  }
}
