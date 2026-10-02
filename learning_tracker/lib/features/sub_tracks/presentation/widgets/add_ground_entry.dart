/// The *+ Add ground* entry point of a sub-track detail and its tablet
/// split host (Story 2.7 / DNI-498 AC-1, AC-7, AC-8, AC-9).
///
/// [AddGroundButton] is shown on every parent view of a sub-track detail,
/// groundless included (UX-DR-54, UX-DR-122). It is absent for a child
/// session (FR-10, FR-11: ground is read-only for the child) and on a
/// calendar-program curriculum (AD-45), and while either is unresolved
/// (fail closed). On a phone it pushes the full-screen picker route; inside
/// a [GroundPickerSplitView] at ≥ [groundPickerTabletBreakpoint] it opens
/// the picker as a right pane beside the detail (UX-DR-164). Either way
/// focus returns to the button when the picker closes (UX-DR-160).
///
/// Story 2.6's detail screen (DNI-497) hosts these: it wraps its body in
/// [GroundPickerSplitView] and places [AddGroundButton] in its ground
/// section. Until DNI-497 lands on the integration branch they have no
/// production host: merge-gate bead learning-tracker-fyh.228, enforced by
/// `test/features/sub_tracks/presentation/screens/add_ground_host_gate_test.dart`,
/// which fails as soon as `SubTrackDetailScreen` exists without them.
library;

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/app/router/app_router.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/parent_session_provider.dart';
import 'package:learning_tracker/features/sub_tracks/data/repositories/ground_picker_sources.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/providers/ground_picker_provider.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/widgets/ground_picker_pane.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// The width from which the picker is a right pane beside the detail.
const double groundPickerTabletBreakpoint = 840;

/// *+ Add ground* for sub-track [subTrackId] of [curriculumId].
class AddGroundButton extends ConsumerStatefulWidget {
  /// Creates the entry point.
  const AddGroundButton({
    super.key,
    required this.subTrackId,
    required this.curriculumId,
  });

  /// The sub-track receiving ground.
  final String subTrackId;

  /// Its curriculum (for the calendar-program block).
  final String curriculumId;

  @override
  ConsumerState<AddGroundButton> createState() => _AddGroundButtonState();
}

class _AddGroundButtonState extends ConsumerState<AddGroundButton> {
  final _focus = FocusNode(debugLabel: 'addGround');

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    final split = GroundPickerSplitView.maybeOf(context);
    if (split != null &&
        MediaQuery.sizeOf(context).width >= groundPickerTabletBreakpoint) {
      split.open(widget.subTrackId, returnFocus: _focus);
      return;
    }
    await context.router.push(GroundPickerRoute(subTrackId: widget.subTrackId));
    if (mounted) _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final parent = ref.watch(parentSessionProvider).value ?? false;
    final scope = ref.watch(activeLearnerScopeProvider).value;
    if (!parent || scope == null) return const SizedBox.shrink();
    final calendar = ref.watch(
      groundPickerCalendarProgramProvider((
        scope: scope,
        curriculumId: widget.curriculumId,
      )),
    );
    // Unknown counts as blocked: the entry appears once it is known safe.
    if (calendar.value != false) return const SizedBox.shrink();
    return OutlinedButton.icon(
      focusNode: _focus,
      onPressed: _open,
      icon: const Icon(Icons.add),
      label: Text(AppLocalizations.of(context)!.groundPickerAddGround),
    );
  }
}

/// Opens and closes the tablet picker pane of a [GroundPickerSplitView].
abstract interface class GroundPickerSplitController {
  /// Opens the picker for [subTrackId]; focus returns to [returnFocus]
  /// when it closes.
  void open(String subTrackId, {FocusNode? returnFocus});

  /// Closes the picker pane.
  void close();
}

/// A sub-track detail with the ground picker as a right pane beside it on
/// a tablet (≥ [groundPickerTabletBreakpoint], UX-DR-164). Below the
/// breakpoint an open picker fills the host, keeping its pending
/// selection (the draft lives in `groundPickerControllerProvider`).
class GroundPickerSplitView extends StatefulWidget {
  /// Creates the host around [detail].
  const GroundPickerSplitView({super.key, required this.detail});

  /// The sub-track detail.
  final Widget detail;

  /// The nearest split host's controller, if any.
  static GroundPickerSplitController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_SplitScope>()?.controller;

  @override
  State<GroundPickerSplitView> createState() => _GroundPickerSplitViewState();
}

class _GroundPickerSplitViewState extends State<GroundPickerSplitView>
    implements GroundPickerSplitController {
  final _detailKey = GlobalKey(debugLabel: 'groundPickerSplitDetail');
  String? _openId;
  FocusNode? _returnFocus;

  @override
  void open(String subTrackId, {FocusNode? returnFocus}) => setState(() {
    _openId = subTrackId;
    _returnFocus = returnFocus;
  });

  @override
  void close() {
    final target = _returnFocus;
    setState(() {
      _openId = null;
      _returnFocus = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (target != null && target.context != null) target.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final openId = _openId;
    // The detail keeps its state (and *Add ground* its focus node) while
    // the pane opens and closes.
    final detail = KeyedSubtree(key: _detailKey, child: widget.detail);
    final Widget child;
    if (openId == null) {
      child = detail;
    } else {
      final pane = Material(
        child: GroundPickerPane(
          key: ValueKey('groundPickerPane-$openId'),
          subTrackId: openId,
          onClose: close,
        ),
      );
      child = LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < groundPickerTabletBreakpoint) {
            return Stack(
              fit: StackFit.expand,
              children: [
                Offstage(child: detail),
                pane,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: detail),
              const VerticalDivider(width: 1),
              SizedBox(width: constraints.maxWidth * 0.45, child: pane),
            ],
          );
        },
      );
    }
    return _SplitScope(controller: this, child: child);
  }
}

class _SplitScope extends InheritedWidget {
  const _SplitScope({required this.controller, required super.child});

  final GroundPickerSplitController controller;

  @override
  bool updateShouldNotify(_SplitScope oldWidget) =>
      oldWidget.controller != controller;
}
