import 'package:flutter/material.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';

/// The `info-note` component (DESIGN.md §Components): an info icon plus one
/// sentence on `brand-blue-soft`, flat, with a 12dp radius.
///
/// Used for form helpers and the one passive onboarding sub-track mention.
/// It is static text by default; [action] (e.g. a link) is optional and is
/// never used where the note must stay non-interactive.
class InfoNote extends StatelessWidget {
  const InfoNote({required this.text, this.action, super.key});

  /// The sentence.
  final String text;

  /// An optional trailing action under the sentence.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: colors.brandBlueSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 20, color: colors.brandBlueDeep),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: textTheme.bodyMedium?.copyWith(color: colors.brandInk),
                ),
                if (action case final action?) action,
              ],
            ),
          ),
        ],
      ),
    );
  }
}
