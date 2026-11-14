import 'package:flutter/material.dart';

/// Opens a modal sheet with its content kept clear of Android's system bars.
///
/// Every application modal bottom sheet should use this helper so bottom
/// actions remain tappable with both gesture and three-button navigation.
Future<T?> showSafeModalBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  Color? backgroundColor,
  bool isScrollControlled = false,
  bool showDragHandle = false,
  ShapeBorder? shape,
  Clip? clipBehavior,
  BoxConstraints? constraints,
}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: backgroundColor,
    isScrollControlled: isScrollControlled,
    showDragHandle: showDragHandle,
    shape: shape,
    clipBehavior: clipBehavior,
    constraints: constraints,
    useSafeArea: true,
    builder: (sheetContext) => SafeArea(
      top: false,
      left: false,
      right: false,
      child: builder(sheetContext),
    ),
  );
}
