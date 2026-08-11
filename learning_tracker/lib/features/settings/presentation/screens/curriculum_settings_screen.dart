import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/constants/app_constants.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/labels/curriculum_label.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/widgets/app_bar_title.dart';
import 'package:learning_tracker/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:learning_tracker/features/onboarding/presentation/screens/bulk_mark_screen.dart';
import 'package:learning_tracker/features/onboarding/presentation/screens/learning_process_wizard_screen.dart';
import 'package:learning_tracker/features/scheduler/scheduler.dart';
import 'package:learning_tracker/features/settings/presentation/widgets/siyum_granularity_selector.dart';
import 'package:learning_tracker/features/tracks/setup/data/repositories/profile_program_repository_impl.dart';
import 'package:learning_tracker/features/tracks/tracks.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

@RoutePage()
class CurriculumSettingsScreen extends ConsumerStatefulWidget {
  const CurriculumSettingsScreen({
    super.key,
    @PathParam('curriculumId') required this.curriculumId,
  });

  final String curriculumId;

  @override
  ConsumerState<CurriculumSettingsScreen> createState() =>
      _CurriculumSettingsScreenState();
}

class _CurriculumSettingsScreenState
    extends ConsumerState<CurriculumSettingsScreen> {
  late CurriculumId _curriculum;

  @override
  void initState() {
    super.initState();
    _curriculum = CurriculumId.values.firstWhere(
      (c) => c.storageKey == widget.curriculumId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final programInfo = ref.watch(_currentProgramProvider(_curriculum));

    // P2 fix (deferred/track-rename-propagation): this screen is reached
    // exclusively from the curriculum-progress screen's settings icon for
    // one specific track (W3.22 guarantees a single track per {profileId,
    // curriculumId}), so its header is that track's own identity label —
    // honour a custom track name the same way Track Detail does
    // (trackDisplayTitle / commit 00048c68).
    final activeTracksAsync = ref.watch(activeTracksProvider);
    final matchingTrack = activeTracksAsync.asData?.value
        .where((t) => t.curriculumId == _curriculum)
        .firstOrNull;
    final trackCustomName = matchingTrack == null
        ? null
        : ref
              .watch(trackCustomNameProvider(matchingTrack.curriculumId))
              .asData
              ?.value;
    final titleText = resolveTrackTitle(
      customName: trackCustomName,
      curriculumFallback: curriculumLabelText(ref, curriculum: _curriculum),
    );

    return Scaffold(
      appBar: AppBar(
        title: AppBarTitle(
          text: AppLocalizations.of(
            context,
          )!.curriculumSettingsTitle(titleText),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          children: [
            // Task 1: Program display
            programInfo.when(
              loading: () => ListTile(
                leading: const Icon(Icons.school),
                title: Text(
                  AppLocalizations.of(
                    context,
                  )!.curriculumSettingsLoadingProgram,
                ),
              ),
              error: (e, stackTrace) {
                // EH-5/ST-4: never surface the raw exception's toString() in
                // the UI (untranslated, un-RTL-shaped English leaks through
                // to Hebrew users) — log it for diagnostics and show only
                // the fixed, localized fallback copy instead.
                AppLogger.instance.error(
                  event: 'curriculum_settings_program_load_failed',
                  fields: {'curriculumId': _curriculum.storageKey},
                  exception: e,
                  stackTrace: stackTrace,
                );
                return ListTile(
                  leading: const Icon(Icons.school),
                  title: Text(
                    AppLocalizations.of(
                      context,
                    )!.curriculumSettingsProgramTitle,
                  ),
                  subtitle: Text(
                    AppLocalizations.of(
                      context,
                    )!.curriculumSettingsProgramError,
                  ),
                );
              },
              data: (info) => ListTile(
                leading: const Icon(Icons.school),
                title: Text(
                  info != null
                      ? AppLocalizations.of(
                          context,
                        )!.curriculumSettingsProgramLabel(
                          learningProgramLabelText(ref, program: info),
                        )
                      : AppLocalizations.of(
                          context,
                        )!.curriculumSettingsCustomSchedule,
                ),
                subtitle: info != null ? Text(info.description) : null,
              ),
            ),

            // Task 2: Change Program button
            ListTile(
              leading: const Icon(Icons.swap_horiz),
              title: Text(
                AppLocalizations.of(context)!.curriculumSettingsChangeProgram,
              ),
              subtitle: Text(
                AppLocalizations.of(
                  context,
                )!.curriculumSettingsChangeProgramSubtitle,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _onChangeProgram(context),
            ),

            const Divider(),

            // Siyum granularity: the finest milestone level celebrated for
            // this curriculum (per-profile, per-curriculum).
            SiyumGranularitySelector(curriculum: _curriculum),

            const Divider(),

            // Task 4: Request New Program
            ListTile(
              leading: const Icon(Icons.mail_outline),
              title: Text(
                AppLocalizations.of(context)!.curriculumSettingsDontSeeProgram,
              ),
              subtitle: Text(
                AppLocalizations.of(context)!.curriculumSettingsRequestProgram,
              ),
              trailing: const Icon(Icons.open_in_new),
              onTap: () => _onRequestProgram(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onChangeProgram(BuildContext context) async {
    final wizardService = ref.read(learningProcessWizardServiceProvider);
    final presets = wizardService.getPresetsForCurriculum(_curriculum);

    if (!context.mounted) return;

    final result = await Navigator.of(context)
        .push<LearningProcessWizardResult>(
          MaterialPageRoute(
            builder: (_) => LearningProcessWizardScreen(
              curriculumId: _curriculum,
              presets: presets,
              isChildMode: false,
            ),
          ),
        );

    if (result == null || !context.mounted) return;

    // Apply the wizard result (deletes old stages, creates new ones).
    await wizardService.applyWizardResult(result.wizardResult);

    // Invalidate providers so UI reflects new stages.
    ref.invalidate(stageListProvider(_curriculum));
    ref.invalidate(stageEditorProvider(_curriculum));
    ref.invalidate(_currentProgramProvider(_curriculum));

    if (!context.mounted) return;

    // Launch bulk mark for the new stages.
    await Navigator.of(context).push<BulkMarkResult>(
      MaterialPageRoute(
        builder: (_) => BulkMarkScreen(curriculumId: _curriculum),
      ),
    );
  }

  Future<void> _onRequestProgram(BuildContext context) async {
    final uri = Uri(
      scheme: 'mailto',
      path: AppConstants.supportEmail,
      queryParameters: {
        'subject': 'Program Request — ${AppConstants.appName}',
        'body': 'Program name: ___\nCurriculum: ___\nDescription: ___',
      },
    );

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.errorNoEmailApp),
          action: SnackBarAction(
            label: AppLocalizations.of(context)!.curriculumSettingsCopy,
            onPressed: () {
              Clipboard.setData(
                const ClipboardData(text: AppConstants.supportEmail),
              );
            },
          ),
        ),
      );
    }
  }
}

/// See track_detail_screen.dart's identical `_curriculumTrackRepositoryProvider`
/// doc comment for why this is a top-level `Provider` rather than an inline
/// construction inside a `WidgetRef`-scoped method.
final _profileProgramRepositoryProvider =
    Provider<FirestoreProfileProgramRepositoryAdapter>(
      (ref) => FirestoreProfileProgramRepositoryAdapter(ref: ref),
    );

/// Provider that fetches the current program for a curriculum.
///
/// Returns null if the user has a custom schedule (no preset program).
final _currentProgramProvider =
    FutureProvider.family<LearningProgramData?, CurriculumId>((
      ref,
      curriculum,
    ) async {
      final profileProgram = await ref
          .watch(_profileProgramRepositoryProvider)
          .getProgram(curriculum);
      if (profileProgram == null) return null;
      return ref
          .read(learningProgramRepositoryProvider)
          .getProgramById(profileProgram.programId);
    });
