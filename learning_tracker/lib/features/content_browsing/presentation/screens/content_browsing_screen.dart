import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

@RoutePage()
class ContentBrowsingScreen extends StatelessWidget {
  const ContentBrowsingScreen({
    super.key,
    @PathParam('curriculumId') required this.curriculumId,
  });

  final String curriculumId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Browse - $curriculumId')),
      body: Center(child: Text('Content Browsing: $curriculumId')),
    );
  }
}
