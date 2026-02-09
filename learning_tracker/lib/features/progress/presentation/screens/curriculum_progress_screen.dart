import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

@RoutePage()
class CurriculumProgressScreen extends StatelessWidget {
  const CurriculumProgressScreen({
    super.key,
    @PathParam('curriculumId') required this.curriculumId,
  });

  final String curriculumId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Progress - $curriculumId')),
      body: Center(child: Text('Curriculum Progress: $curriculumId')),
    );
  }
}
