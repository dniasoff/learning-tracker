import 'package:flutter/material.dart';

/// Displays a profile avatar based on an avatar index.
///
/// Uses a color and icon combination derived from the index.
class ProfileAvatar extends StatelessWidget {
  final int avatarIndex;
  final double radius;

  const ProfileAvatar({super.key, required this.avatarIndex, this.radius = 24});

  static const _colors = [
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.teal,
    Colors.red,
    Colors.indigo,
    Colors.amber,
    Colors.cyan,
    Colors.pink,
  ];

  static const _icons = [
    Icons.person,
    Icons.star,
    Icons.favorite,
    Icons.school,
    Icons.auto_stories,
    Icons.emoji_nature,
    Icons.pets,
    Icons.rocket_launch,
    Icons.music_note,
    Icons.sports_soccer,
  ];

  @override
  Widget build(BuildContext context) {
    final color = _colors[avatarIndex % _colors.length];
    final icon = _icons[avatarIndex % _icons.length];

    return CircleAvatar(
      radius: radius,
      backgroundColor: color.withValues(alpha: 0.2),
      child: Icon(icon, size: radius, color: color),
    );
  }
}
