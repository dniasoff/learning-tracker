import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/core/widgets/app_bar_title.dart';

@RoutePage()
class CurriculumSettingsScreen extends StatelessWidget {
  const CurriculumSettingsScreen({
    super.key,
    @PathParam('curriculumId') required this.curriculumId,
  });

  final String curriculumId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: AppBarTitle(text: 'Settings - $curriculumId')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.layers),
            title: const Text('Manage Stages'),
            subtitle: const Text('Add, edit, or reorder learning stages'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () =>
                context.pushRoute(StageEditorRoute(curriculumId: curriculumId)),
          ),
        ],
      ),
    );
  }
}
