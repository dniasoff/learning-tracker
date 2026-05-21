import 'package:flutter/material.dart';

/// Slim top banner shown above the app bar when a cloud-born user is
/// temporarily offline. Local-born users never see this banner — being
/// offline is their permanent state, not news (v2 §4.6).
///
/// Pure UI: the parent (app_shell) is the single source of truth for
/// "should the banner be visible" because it also sizes the appBar's
/// `PreferredSize` from the same answer. Watching the connectivity +
/// auth tier from two places risks drift; this widget renders what it
/// is told.
class OfflineTopBanner extends StatelessWidget {
  const OfflineTopBanner({super.key, required this.visible});

  /// Whether the banner should currently be shown.
  final bool visible;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      child: visible
          ? Semantics(
              liveRegion: true,
              label: "Offline — changes will sync when you're back online",
              child: Container(
                width: double.infinity,
                height: 32,
                color: Theme.of(context).colorScheme.secondaryContainer,
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.cloud_off, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      "Offline — changes will sync when you're back",
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ],
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}
