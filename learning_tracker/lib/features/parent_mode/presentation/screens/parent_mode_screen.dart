import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

@RoutePage()
class ParentModeScreen extends StatelessWidget {
  const ParentModeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Parent Mode')),
      body: const Center(child: Text('Parent Mode Screen')),
    );
  }
}
