import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';

@RoutePage()
class ParentModeScreen extends StatelessWidget {
  const ParentModeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Parent Mode')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.lock),
            title: const Text('Change PIN'),
            subtitle: const Text('Update your parent access PIN'),
            onTap: () => context.router.push(const PinChangeRoute()),
          ),
        ],
      ),
    );
  }
}
