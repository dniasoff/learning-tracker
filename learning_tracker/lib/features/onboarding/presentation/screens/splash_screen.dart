import 'dart:async';
import 'dart:math' as math;

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
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: AppTheme.brandCream,
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white,
                    AppTheme.brandBlueSoft.withValues(alpha: 0.22),
                    AppTheme.brandCream,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: -72,
            left: -32,
            child: _SoftOrb(
              diameter: 220,
              color: AppTheme.brandBlueSoft.withValues(alpha: 0.45),
            ),
          ),
          Positioned(
            bottom: -84,
            right: -20,
            child: _SoftOrb(
              diameter: 190,
              color: AppTheme.brandCoralSoft.withValues(alpha: 0.55),
            ),
          ),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.menu_book_rounded,
                      size: 38,
                      color: AppTheme.brandBlue.withValues(alpha: 0.35),
                    ),
                    const SizedBox(height: 48),
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        final scale = 0.96 + (_pulseController.value * 0.06);
                        return Transform.scale(scale: scale, child: child);
                      },
                      child: Container(
                        width: 144,
                        height: 144,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(34),
                          border: Border.all(
                            color: AppTheme.brandOutline.withValues(alpha: 0.5),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.brandBlue.withValues(alpha: 0.08),
                              blurRadius: 28,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Image.asset(
                            'assets/images/app_logo.png',
                            width: 88,
                            height: 88,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 52),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.brandCreamSoft,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.brandCoralSoft),
                      ),
                      child: Text(
                        'READY FOR ADVENTURE?',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppTheme.brandCoralDeep,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.9,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: 210,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value: 0.35 + (_pulseController.value * 0.5),
                          minHeight: 11,
                          color: AppTheme.brandBlueBright,
                          backgroundColor: AppTheme.brandBlueSoft,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'LOADING WISDOM...',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppTheme.brandBlue.withValues(alpha: 0.55),
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 52,
            right: 22,
            child: InkWell(
              onTap: _navigateNext,
              borderRadius: BorderRadius.circular(20),
              child: Ink(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: AppTheme.brandCoral,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ),
          const Positioned(
            left: 26,
            bottom: 124,
            child: Icon(
              Icons.star_rounded,
              color: AppTheme.brandGold,
              size: 22,
            ),
          ),
          Positioned(
            right: 28,
            bottom: 94,
            child: Transform.rotate(
              angle: math.pi / 10,
              child: Icon(
                Icons.chat_bubble_rounded,
                color: AppTheme.brandCoral.withValues(alpha: 0.25),
                size: 30,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SoftOrb extends StatelessWidget {
  const _SoftOrb({required this.diameter, required this.color});

  final double diameter;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: diameter,
        height: diameter,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withValues(alpha: 0.0)],
          ),
        ),
      ),
    );
  }
}
