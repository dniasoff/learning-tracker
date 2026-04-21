import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';

@RoutePage()
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    // Auto-navigate after 1 second
    Timer(const Duration(seconds: 1), _navigateNext);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _navigateNext() async {
    if (mounted) {
      await context.router.replace(const AppIntroRoute());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFECEAE8),
      body: Stack(
        children: [
          // Main content centered
          Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Top decorative icon
                  Opacity(
                    opacity: 0.4,
                    child: Icon(
                      Icons.menu_book_rounded,
                      size: 48,
                      color: AppTheme.heritageNavy.withValues(alpha: 0.5),
                    ),
                  ),

                  const SizedBox(height: 60),

                  // White rounded square container with app logo
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Image.asset(
                        'assets/images/app_logo.png',
                        width: 80,
                        height: 80,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),

                  const SizedBox(height: 60),

                  // "READY FOR ADVENTURE?" button
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFE5D9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'READY FOR ADVENTURE?',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: const Color(0xFFD97B6D),
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.8,
                          ),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Loading bar - pulsing blue progress
                  Container(
                    width: 140,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, _) {
                        return Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            width: 140 * _pulseController.value,
                            height: 8,
                            decoration: BoxDecoration(
                              color: const Color(0xFF2D5A7B),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Loading text
                  Text(
                    'LOADING WISDOM...',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppTheme.heritageNavy.withValues(alpha: 0.4),
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Close button (top right)
          Positioned(
            top: 36,
            right: 20,
            child: FloatingActionButton(
              mini: true,
              backgroundColor: const Color(0xFFFF6B6B),
              shape: const CircleBorder(),
              onPressed: _navigateNext,
              child: const Icon(
                Icons.add,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),

          // Left floating star (bottom left)
          const Positioned(
            bottom: 80,
            left: 24,
            child: Opacity(
              opacity: 0.3,
              child: Icon(
                Icons.star_rounded,
                size: 32,
                color: AppTheme.heritageNavy,
              ),
            ),
          ),

          // Right floating chat bubble (bottom right)
          const Positioned(
            bottom: 60,
            right: 28,
            child: Opacity(
              opacity: 0.25,
              child: Icon(
                Icons.chat_bubble_rounded,
                size: 36,
                color: AppTheme.heritageNavy,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
