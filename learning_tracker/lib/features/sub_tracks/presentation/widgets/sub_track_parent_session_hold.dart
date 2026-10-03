import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/providers/sub_track_editor_session.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/providers/sub_track_providers.dart';

/// Shows [child] — a sub-track write surface (the school-year form, the
/// goal setup its no-deadline link opens) — only while the parent session
/// is live (DNI-495 AC-3).
///
/// Before the session was ever granted the child is not built: [loading]
/// while the session resolves, [locked] when it is refused. Once granted,
/// a session that ends (PIN lock) hides the child instead of dropping it:
/// it stays mounted offstage, with no painting, input, focus or tickers,
/// so nothing on it can be submitted and the values entered so far come
/// back if the parent session returns. Writes still re-check the session
/// at their command boundary ([readSubTrackParentSession]).
class SubTrackParentSessionHold extends ConsumerStatefulWidget {
  const SubTrackParentSessionHold({
    required this.child,
    this.allowTutor = false,
    this.loading = const Center(child: CircularProgressIndicator()),
    this.locked = const SizedBox.shrink(
      key: ValueKey('subTrackParentSessionLocked'),
    ),
    super.key,
  });

  /// The parent-only surface.
  final Widget child;

  /// Whether a tutored session holds it too (Story 4.2, DNI-510: the shared
  /// sub-track forms; [subTrackEditorSessionProvider]). The goal setup the
  /// no-deadline link opens stays parent-only.
  final bool allowTutor;

  /// Shown while the session resolves for the first time.
  final Widget loading;

  /// Shown instead of [child] while there is no parent session.
  final Widget locked;

  @override
  ConsumerState<SubTrackParentSessionHold> createState() =>
      _SubTrackParentSessionHoldState();
}

class _SubTrackParentSessionHoldState
    extends ConsumerState<SubTrackParentSessionHold> {
  /// Whether the session was live at least once: from then on [child]
  /// stays mounted (hidden while locked).
  bool _granted = false;

  @override
  Widget build(BuildContext context) {
    final session = widget.allowTutor
        ? ref.watch(subTrackEditorSessionProvider)
        : ref.watch(subTrackParentSessionProvider);
    final live = !session.hasError && session.value == true;
    if (live) _granted = true;
    if (!_granted) {
      return session.isLoading && !session.hasValue
          ? widget.loading
          : widget.locked;
    }
    return Stack(
      fit: StackFit.passthrough,
      children: [
        Offstage(
          offstage: !live,
          child: TickerMode(
            enabled: live,
            child: ExcludeFocus(excluding: !live, child: widget.child),
          ),
        ),
        if (!live) widget.locked,
      ],
    );
  }
}
