import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/features/dashboard/domain/models/track_card_view_model.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/dashboard_helpers.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Full-width CTA button at the bottom of [TrackCard].
///
/// Navigates to [NextTaskData.sefariaRef] when a next task is available,
/// or to the Learn tab as a fallback when nothing is scheduled.
class TrackContinueButton extends StatelessWidget {
  const TrackContinueButton({super.key, required this.vm, required this.l10n});

  final TrackCardViewModel vm;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: () => _onPressed(context),
      style: FilledButton.styleFrom(
        backgroundColor: kActiveTrackPrimaryBlue,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 48),
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
        ),
      ),
      child: Text(l10n.continueCta),
    );
  }

  void _onPressed(BuildContext context) {
    final sefariaRef = vm.nextTask.sefariaRef;
    if (sefariaRef != null && sefariaRef.isNotEmpty) {
      context.router.push(TextDisplayRoute(sefariaRef: sefariaRef));
    } else {
      context.router.navigate(const LearningRoute());
    }
  }
}
