import 'package:flutter/material.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Amber tip card shown below the achievements list with a pro-tip about
/// earning more points.
class ProTipCard extends StatelessWidget {
  const ProTipCard({super.key, required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFFEFD5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFCC80)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 1),
              child: Icon(
                Icons.lightbulb_rounded,
                size: 26,
                color: Color(0xFF212121),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text.rich(
                TextSpan(
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF4E342E),
                    height: 1.4,
                  ),
                  children: [
                    TextSpan(
                      text: '${l10n.achievementsProTipTitle} ',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFBF360C),
                      ),
                    ),
                    TextSpan(text: l10n.achievementsProTipBody),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
