import 'package:flutter/material.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/features/profiles/domain/models/profile_model.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// A tappable card representing a single owned learner profile in the picker.
class ProfileCard extends StatelessWidget {
  const ProfileCard({
    super.key,
    required this.profile,
    required this.onTap,
    this.onLongPress,
  });

  final ProfileModel profile;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final isChild = profile.profileMode.isChild;
    final modeColor = context.colors.brandBlue;
    final trimmedName = profile.displayName.trim();
    final firstLetter = trimmedName.isEmpty
        ? '?'
        : trimmedName.substring(0, 1).toUpperCase();
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Ink(
          decoration: BoxDecoration(
            color: context.colors.brandCreamCard,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: context.colors.brandOutline.withValues(alpha: 0.35),
            ),
            boxShadow: [
              BoxShadow(
                color: context.colors.brandInk.withValues(alpha: 0.05),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: modeColor,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      isChild
                          ? l10n.profileBadgeChildMode
                          : l10n.profileBadgeAdultMode,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.35,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: context.colors.brandInkMuted,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Center(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 92,
                      height: 92,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFFF2F5FC), Color(0xFFE6ECF8)],
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: context.colors.brandBlue.withValues(
                            alpha: 0.14,
                          ),
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          firstLetter,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: context.colors.brandBlueDeep,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    if (isChild)
                      // ExcludeSemantics must sit INSIDE Positioned — Positioned
                      // has to be a direct child of the Stack. The star badge is
                      // decorative (child-mode is already conveyed by the
                      // "CHILD MODE" pill), so it carries no semantics.
                      Positioned(
                        right: -1,
                        bottom: -1,
                        child: ExcludeSemantics(
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF96B82),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: context.colors.brandCreamCard,
                                width: 2,
                              ),
                            ),
                            child: const Icon(
                              Icons.star_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: Column(
                  children: [
                    Text(
                      profile.displayName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 22,
                        color: context.colors.brandInk,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.tapToContinue,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: context.colors.brandInkMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 2),
            ],
          ),
        ),
      ),
    );
  }
}
