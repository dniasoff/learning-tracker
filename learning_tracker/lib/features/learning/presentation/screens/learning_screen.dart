import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:learning_tracker/core/widgets/app_bar_title.dart';

@RoutePage()
class LearningScreen extends StatelessWidget {
  const LearningScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const AppBarTitle(text: 'Learn')),
      body: const Center(child: Text('Learning Screen')),
    );
  }
}
