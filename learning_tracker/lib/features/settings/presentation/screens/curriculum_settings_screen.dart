import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/constants/app_constants.dart';
import 'package:learning_tracker/core/database/app_database.dart' as db;
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/widgets/app_bar_title.dart';
import 'package:learning_tracker/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:learning_tracker/features/onboarding/presentation/screens/bulk_mark_screen.dart';
import 'package:learning_tracker/features/onboarding/presentation/screens/learning_process_wizard_screen.dart';
import 'package:learning_tracker/features/stages/presentation/providers/stage_providers.dart';
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

    return Scaffold(
      appBar: AppBar(
        title: AppBarTitle(text: 'Settings - ${_curriculum.displayNameEn}'),
      ),
      body: ListView(
        children: [
          // Task 1: Program display
          programInfo.when(
            loading: () => const ListTile(
              leading: Icon(Icons.school),
              title: Text('Loading program...'),
            ),
            error: (e, _) => ListTile(
              leading: const Icon(Icons.school),
              title: const Text('Program'),
              subtitle: Text('Error: $e'),
            ),
            data: (info) => ListTile(
              leading: const Icon(Icons.school),
              title: Text(
                info != null
                    ? 'Program: ${info.displayName}'
                    : 'Custom schedule',
              ),
              subtitle: info != null ? Text(info.description) : null,
            ),
          ),

          // Task 2: Change Program button
          ListTile(
            leading: const Icon(Icons.swap_horiz),
            title: const Text('Change Program'),
            subtitle: const Text('Switch to a different learning program'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _onChangeProgram(context),
          ),

          const Divider(),

          // Task 4: Request New Program
          ListTile(
            leading: const Icon(Icons.mail_outline),
            title: const Text("Don't see your program?"),
            subtitle: const Text('Request a new program'),
            trailing: const Icon(Icons.open_in_new),
            onTap: () => _onRequestProgram(context),
          ),
        ],
      ),
    );
  }

  Future<void> _onChangeProgram(BuildContext context) async {
    final wizardService = ref.read(learningProcessWizardServiceProvider);
    final presets = await wizardService.getPresetsForCurriculum(_curriculum);

    if (!context.mounted) return;

    final result = await Navigator.of(context).push<LearningProcessWizardResult>(
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
          content: const Text(
            'No email app found. Copy address instead?',
          ),
          action: SnackBarAction(
            label: 'Copy',
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

/// Provider that fetches the current program for a curriculum.
///
/// Returns null if the user has a custom schedule (no preset program).
final _currentProgramProvider =
    FutureProvider.family<db.LearningProgram?, CurriculumId>((
  ref,
  curriculum,
) async {
  final database = ref.watch(appDatabaseProvider);
  // profileId 0 = default/current profile (same as wizard service uses)
  final profileProgram =
      await database.profileProgramDao.getProgramForProfileAndCurriculum(
    0,
    curriculum.storageKey,
  );
  if (profileProgram == null) return null;
  return database.learningProgramDao.getProgramById(profileProgram.programId);
});
