import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

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
      appBar: AppBar(title: Text('Settings - $curriculumId')),
      body: Center(child: Text('Curriculum Settings: $curriculumId')),
    );
  }
}
