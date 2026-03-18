import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:learning_tracker/core/widgets/app_bar_title.dart';

@RoutePage()
class CurriculumLearningScreen extends StatelessWidget {
  const CurriculumLearningScreen({
    super.key,
    @PathParam('curriculumId') required this.curriculumId,
  });

  final String curriculumId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: AppBarTitle(text: 'Learn - $curriculumId')),
      body: SafeArea(top: false, child: Center(child: Text('Curriculum Learning: $curriculumId'))),
    );
  }
}
