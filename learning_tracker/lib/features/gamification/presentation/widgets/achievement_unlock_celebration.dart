import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/labels/curriculum_label.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/features/gamification/domain/models/reward_milestone.dart';
import 'package:learning_tracker/features/gamification/presentation/providers/achievements_overview_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<String> _resolveTrackLabel(WidgetRef ref, int trackId) async {
  final db = ref.read(userDatabaseProvider);
  final track = await db.trackDao.getTrackById(trackId);
  if (track == null) return '';
  final c = CurriculumId.fromStorageKey(track.curriculumId);
  if (c != null) return curriculumLabelText(ref, curriculum: c);
  return track.curriculumId;
}

// ---------------------------------------------------------------------------
// Riverpod notifier — replaces the former static _dialogInFlight bool.
// ---------------------------------------------------------------------------

/// Whether the unlock-celebration dialog is currently on screen.
///
/// Using a Riverpod notifier instead of a static field makes the flag
/// reset correctly when the provider is disposed (e.g. on profile switch)
/// and allows the state to be inspected in tests without reaching into
/// private class internals.
final _celebrationInFlightProvider =
    NotifierProvider<_CelebrationInFlightNotifier, bool>(
      _CelebrationInFlightNotifier.new,
    );

class _CelebrationInFlightNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void start() => state = true;
  void finish() => state = false;
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/// Full-screen confetti + dialog when a reward milestone is newly unlocked.
class AchievementUnlockCelebration {
  AchievementUnlockCelebration._();

  static const _migratedPrefix = 'achievements_unlock_party_migrated_v1_';
  static const _donePrefix = 'achievements_unlock_party_done_v1_';

  /// One-time: seed "already seen" milestone ids from server/overview so an
  /// open of My Achievements does not show a surprise party. No confetti.
  static Future<void> migrateDoneKeysIfNeeded(
    WidgetRef ref,
    AchievementsOverview overview,
  ) async {
    final profileId = ref.read(activeProfileIdProvider);
    final prefs = await SharedPreferences.getInstance();
    final migratedKey = '$_migratedPrefix$profileId';
    final doneKey = '$_donePrefix$profileId';

    final unlockedRows = overview.rows.where((r) => r.isUnlocked).toList();
    final currentIds = unlockedRows.map((r) => r.milestone.id).toSet();

    if (prefs.getBool(migratedKey) != true) {
      await prefs.setString(doneKey, jsonEncode(currentIds.toList()..sort()));
      await prefs.setBool(migratedKey, true);
    }
  }

  static Future<void> _mergeMilestoneIdsIntoDonePrefs(
    int profileId,
    Set<String> addIds,
  ) async {
    if (addIds.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final doneKey = '$_donePrefix$profileId';
    var done = <String>{};
    final doneRaw = prefs.getString(doneKey);
    if (doneRaw != null && doneRaw.isNotEmpty) {
      try {
        final list = jsonDecode(doneRaw) as List<dynamic>?;
        if (list != null) {
          done = list.map((e) => e.toString()).toSet();
        }
      } catch (_) {
        // no-op: SharedPreferences read failure is non-fatal; proceed with empty set
      }
    }
    final merged = done.union(addIds);
    await prefs.setString(doneKey, jsonEncode(merged.toList()..sort()));
  }

  /// Call after "Mark learn complete" when [newUnlocks] is non-empty.
  /// Shows full-screen confetti on the **reading** screen, not on My Achievements.
  static Future<void> showForUnlockedMilestones({
    required BuildContext context,
    required WidgetRef ref,
    required List<RewardUnlockRecord> newUnlocks,
  }) async {
    if (!context.mounted) return;
    if (newUnlocks.isEmpty) return;

    // Guard via Riverpod notifier (replaces former static _dialogInFlight).
    final inFlight = ref.read(_celebrationInFlightProvider);
    if (inFlight) return;

    final profileId = ref.read(activeProfileIdProvider);
    final first = newUnlocks.first;
    final milestoneTitle = first.title;

    if (!context.mounted) return;
    final trackLabel = await _resolveTrackLabel(ref, first.trackId);
    if (!context.mounted) return;

    final l10n = AppLocalizations.of(context)!;
    String displayName;
    try {
      final prof = await ref.read(selectedProfileProvider.future);
      final name = prof?.displayName.trim();
      displayName = (name != null && name.isNotEmpty)
          ? name
          : l10n.achievementsUnlockPartyNameFallback;
    } catch (_) {
      displayName = l10n.achievementsUnlockPartyNameFallback;
    }

    if (!context.mounted) return;

    ref.read(_celebrationInFlightProvider.notifier).start();
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: true,
        barrierColor: Colors.black45,
        builder: (ctx) {
          return _UnlockPartyDialog(
            displayName: displayName,
            milestoneTitle: milestoneTitle,
            trackLabel: trackLabel,
            l10n: l10n,
          );
        },
      );
    } finally {
      ref.read(_celebrationInFlightProvider.notifier).finish();
    }

    if (!context.mounted) return;
    await _mergeMilestoneIdsIntoDonePrefs(
      profileId,
      newUnlocks.map((u) => u.milestoneId).toSet(),
    );
  }
}

List<Color> _partyColors(BuildContext context) => <Color>[
  context.colors.gamifPartyColorCoral,
  context.colors.gamifPartyColorYellow,
  context.colors.chartGreen,
  context.colors.chartBlue,
  context.colors.gamifPartyColorPink,
  context.colors.gamifPartyColorOrange,
  context.colors.gamifPartyColorPurple,
];

class _UnlockPartyDialog extends StatefulWidget {
  const _UnlockPartyDialog({
    required this.displayName,
    required this.milestoneTitle,
    required this.trackLabel,
    required this.l10n,
  });

  final String displayName;
  final String milestoneTitle;
  final String trackLabel;
  final AppLocalizations l10n;

  @override
  State<_UnlockPartyDialog> createState() => _UnlockPartyDialogState();
}

class _UnlockPartyDialogState extends State<_UnlockPartyDialog> {
  late final ConfettiController _burstCenter;
  late final ConfettiController _shower;
  Timer? _autoClose;

  @override
  void initState() {
    super.initState();
    const playDuration = Duration(seconds: 5);
    _burstCenter = ConfettiController(duration: playDuration);
    _shower = ConfettiController(duration: playDuration);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _burstCenter.play();
      _shower.play();
    });
    _autoClose = Timer(const Duration(seconds: 5), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  void dispose() {
    _autoClose?.cancel();
    _burstCenter.stop();
    _shower.stop();
    _burstCenter.dispose();
    _shower.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: SizedBox.expand(
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: ConfettiWidget(
                confettiController: _shower,
                blastDirectionality: BlastDirectionality.directional,
                blastDirection: pi / 2,
                numberOfParticles: 14,
                maxBlastForce: 28,
                minBlastForce: 8,
                gravity: 0.2,
                colors: _partyColors(context),
                emissionFrequency: 0.04,
                shouldLoop: true,
                minimumSize: const Size(12, 6),
                maximumSize: const Size(20, 10),
                child: const Align(
                  alignment: Alignment.topCenter,
                  child: SizedBox(width: 400, height: 1),
                ),
              ),
            ),
            Positioned.fill(
              child: Center(
                child: ConfettiWidget(
                  confettiController: _burstCenter,
                  blastDirectionality: BlastDirectionality.explosive,
                  numberOfParticles: 36,
                  maxBlastForce: 52,
                  minBlastForce: 18,
                  gravity: 0.22,
                  colors: _partyColors(context),
                  emissionFrequency: 0.06,
                  shouldLoop: true,
                  minimumSize: const Size(10, 7),
                  maximumSize: const Size(22, 15),
                  child: const SizedBox(width: 2, height: 2),
                ),
              ),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: AchievementUnlockCard(
                  displayName: widget.displayName,
                  milestoneTitle: widget.milestoneTitle,
                  trackLabel: widget.trackLabel,
                  l10n: widget.l10n,
                  onContinue: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The branded celebration card (emoji + title + message + button), extracted
/// from [_UnlockPartyDialog] so the overflow-prone surface can be rendered and
/// guarded without the looping confetti / auto-close timer.
///
/// Overflow-safe by construction: the card height is capped to the viewport
/// (minus safe-area + a small margin) and its content lives in a
/// [SingleChildScrollView], so a long milestone/track name at large text scales
/// shrinks-and-scrolls instead of overflowing the Column.
class AchievementUnlockCard extends StatelessWidget {
  const AchievementUnlockCard({
    super.key,
    required this.displayName,
    required this.milestoneTitle,
    required this.trackLabel,
    required this.l10n,
    required this.onContinue,
  });

  final String displayName;
  final String milestoneTitle;
  final String trackLabel;
  final AppLocalizations l10n;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);
    final maxCardHeight = media.size.height - media.padding.vertical - 48;
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 340,
        constraints: BoxConstraints(
          maxHeight: maxCardHeight > 0 ? maxCardHeight : media.size.height,
        ),
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              context.colors.gamifUnlockCardGradientCream,
              context.colors.gamifUnlockCardGradientPink,
              context.colors.accentTealSoft,
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: context.colors.gamifUnlockCardShadow,
              blurRadius: 32,
              offset: const Offset(0, 12),
            ),
          ],
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.9),
            width: 3,
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🎉', style: TextStyle(fontSize: 52)),
              const SizedBox(height: 4),
              Text(
                l10n.achievementsUnlockPartyTitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: context.colors.accentBurntOrange,
                  letterSpacing: 0.3,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                l10n.achievementsUnlockPartyMessage(
                  displayName,
                  milestoneTitle,
                  trackLabel,
                ),
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                  color: context.colors.gamifInkCharcoal,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: onContinue,
                style: FilledButton.styleFrom(
                  backgroundColor: context.colors.brandBlue,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: Text(
                  l10n.achievementsUnlockPartyButton,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
