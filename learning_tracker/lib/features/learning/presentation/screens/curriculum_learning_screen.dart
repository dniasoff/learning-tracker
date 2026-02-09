import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

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
      appBar: AppBar(title: Text('Learn - $curriculumId')),
      body: Center(child: Text('Curriculum Learning: $curriculumId')),
    );
  }
}
