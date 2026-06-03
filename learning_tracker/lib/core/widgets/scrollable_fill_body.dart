import 'package:flutter/widgets.dart';

/// Vertically overflow-safe wrapper for a screen/section body.
///
/// The recurring overflow trap: a body `Column` that uses
/// `mainAxisAlignment.center` / `Spacer` to fill the viewport overflows on
/// short screens or at large text, while naively wrapping it in
/// `SingleChildScrollView(ConstrainedBox(minHeight: maxHeight, IntrinsicHeight))`
/// crashes with "BoxConstraints forces an infinite height" the moment the
/// widget is placed in an UNBOUNDED-height context (inside another scroll view,
/// a non-Expanded Column, etc.). This widget gets it right in one place:
///
/// - **Bounded** parent height (a full-screen body): [child] may fill the
///   viewport — so centering/`Spacer` still center it — but scrolls when its
///   content exceeds the available height. No RenderFlex overflow.
/// - **Unbounded** parent height (embedded in a scroll view / intrinsic
///   context): returns [child] at its natural height; the enclosing scrollable
///   owns scrolling. (Wrapping here would force an infinite constraint.)
///
/// Prefer this over hand-rolling the LayoutBuilder/IntrinsicHeight dance.
class ScrollableFillBody extends StatelessWidget {
  const ScrollableFillBody({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!constraints.hasBoundedHeight) return child;
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(child: child),
          ),
        );
      },
    );
  }
}
