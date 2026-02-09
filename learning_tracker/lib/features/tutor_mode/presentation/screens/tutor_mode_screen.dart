import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

@RoutePage()
class TutorModeScreen extends StatelessWidget {
  const TutorModeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tutor Mode')),
      body: const Center(child: Text('Tutor Mode Screen')),
    );
  }
}
