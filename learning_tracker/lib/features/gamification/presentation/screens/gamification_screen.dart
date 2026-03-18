import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:learning_tracker/core/widgets/app_bar_title.dart';

@RoutePage()
class GamificationScreen extends StatelessWidget {
  const GamificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const AppBarTitle(text: 'Gamification')),
      body: const SafeArea(top: false, child: Center(child: Text('Gamification Screen'))),
    );
  }
}
