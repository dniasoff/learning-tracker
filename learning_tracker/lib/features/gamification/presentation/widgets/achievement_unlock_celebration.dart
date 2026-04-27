import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/gamification/domain/models/reward_milestone.dart';
import 'package:learning_tracker/features/gamification/domain/services/reward_milestone_service.dart';
import 'package:learning_tracker/features/gamification/presentation/providers/achievements_overview_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

CurriculumId? _curriculumForStorageKey(String key) {
  for (final c in CurriculumId.values) {
    if (c.storageKey == key) return c;
  }
  return null;
}

Future<String> _resolveTrackLabel(
  WidgetRef ref,
  String languageCode,
  int trackId,
) async {
  final db = ref.read(userDatabaseProvider);
  final track = await db.trackDao.getTrackById(trackId);
  if (track == null) return '';
  final c = _curriculumForStorageKey(track.curriculumId);
  if (c != null) {
    return languageCode == 'he' ? c.displayNameHe : c.displayNameEn;
  }
  return track.curriculumId;
}

/// Full-screen confetti + dialog when a reward milestone is newly unlocked.
class AchievementUnlockCelebration {
  AchievementUnlockCelebration._();

  static const _migratedPrefix = 'achievements_unlock_party_migrated_v1_';
  static const _donePrefix = 'achievements_unlock_party_done_v1_';

  static bool _dialogInFlight = false;

  static Future<void> showIfNeeded({
    required WidgetRef ref,
    required BuildContext context,
    required AchievementsOverview overview,
  }) async {
    if (!context.mounted) return;
    if (_dialogInFlight) return;

    final profileId = ref.read(activeProfileIdProvider);
    final prefs = await SharedPreferences.getInstance();
    final migratedKey = '$_migratedPrefix$profileId';
    final doneKey = '$_donePrefix$profileId';

    final unlockedRows = overview.rows.where((r) => r.isUnlocked).toList();
    final currentIds = unlockedRows.map((r) => r.milestone.id).toSet();

    if (prefs.getBool(migratedKey) != true) {
      await prefs.setString(doneKey, jsonEncode(currentIds.toList()..sort()));
      await prefs.setBool(migratedKey, true);
      return;
    }

    final doneRaw = prefs.getString(doneKey);
    var done = <String>{};
    if (doneRaw != null && doneRaw.isNotEmpty) {
      try {
        final list = jsonDecode(doneRaw) as List<dynamic>?;
        if (list != null) {
          done = list.map((e) => e.toString()).toSet();
        }
      } catch (_) {}
    }

    final fresh = currentIds.difference(done);
    if (fresh.isEmpty) return;

    final db = ref.read(userDatabaseProvider);
    final service = RewardMilestoneService(db, profileId: profileId);
    final unlocks = await service.getAllUnlocks();

    RewardUnlockRecord? picked;
    for (final u in unlocks) {
      if (fresh.contains(u.milestoneId)) {
        picked = u;
        break;
      }
    }
    final row = unlockedRows.firstWhere((r) => fresh.contains(r.milestone.id));
    final milestoneTitle = picked?.title ?? row.milestone.title;

    if (!context.mounted) return;
    final languageCode = Localizations.localeOf(context).languageCode;
    final trackLabel = await _resolveTrackLabel(
      ref,
      languageCode,
      picked?.trackId ?? row.trackId,
    );
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

    _dialogInFlight = true;
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
      _dialogInFlight = false;
    }

    if (!context.mounted) return;
    final merged = done.union(fresh);
    final prefsAfter = await SharedPreferences.getInstance();
    await prefsAfter.setString(doneKey, jsonEncode(merged.toList()..sort()));
  }
}

const _partyColors = <Color>[
  Color(0xFFFF6B6B),
  Color(0xFFFFD93D),
  Color(0xFF6BCB77),
  Color(0xFF4D96FF),
  Color(0xFFFF9FF3),
  Color(0xFFFFA502),
  Color(0xFF5F27CD),
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
    final theme = Theme.of(context);
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
                colors: _partyColors,
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
                  colors: _partyColors,
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
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    width: 340,
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFFFFF4E0),
                          Color(0xFFFFE0F0),
                          Color(0xFFE0F4FF),
                        ],
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x4D0038A8),
                          blurRadius: 32,
                          offset: Offset(0, 12),
                        ),
                      ],
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.9),
                        width: 3,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🎉', style: TextStyle(fontSize: 52)),
                        const SizedBox(height: 4),
                        Text(
                          widget.l10n.achievementsUnlockPartyTitle,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFFE65100),
                            letterSpacing: 0.3,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          widget.l10n.achievementsUnlockPartyMessage(
                            widget.displayName,
                            widget.milestoneTitle,
                            widget.trackLabel,
                          ),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                            color: const Color(0xFF37474F),
                          ),
                        ),
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF0038A8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: Text(
                            widget.l10n.achievementsUnlockPartyButton,
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}
