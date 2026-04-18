import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';

/// Branded splash shown once on cold start. Holds the Mesorah Heritage
/// treatment for ~1.6s, then replaces itself with the app shell — the
/// auth guard on the shell decides where the user actually lands.
@RoutePage()
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _fade;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _fade = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    Timer(const Duration(milliseconds: 1600), _continue);
  }

  @override
  void dispose() {
    _fade.dispose();
    _pulse.dispose();
    super.dispose();
  }

  void _continue() {
    if (!mounted) return;
    unawaited(context.router.replace(const AppShellRoute()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.heritageNavy,
      body: SafeArea(
        child: FadeTransition(
          opacity: CurvedAnimation(parent: _fade, curve: Curves.easeOut),
          child: Column(
            children: [
              const Spacer(flex: 3),
              _Emblem(pulse: _pulse),
              const SizedBox(height: 32),
              Text(
                'Torah Learning Tracker',
                textAlign: TextAlign.center,
                style: GoogleFonts.playfairDisplay(
                  color: AppTheme.heritageInk,
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  'Bridging generations through the timeless\nwisdom of the Living Scroll',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: AppTheme.heritageInkMuted,
                    fontSize: 14,
                    height: 1.5,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              const Spacer(flex: 3),
              const _Pillars(),
              const SizedBox(height: 24),
              _Footer(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _Emblem extends StatelessWidget {
  const _Emblem({required this.pulse});
  final Animation<double> pulse;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (context, _) {
        final glow = 0.15 + pulse.value * 0.15;
        return Container(
          width: 136,
          height: 136,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: AppTheme.heritageGold.withValues(alpha: 0.55),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.heritageGold.withValues(alpha: glow),
                blurRadius: 40,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Center(
            child: Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppTheme.heritageGold.withValues(alpha: 0.35),
                  width: 1,
                ),
              ),
              child: const Icon(
                Icons.menu_book_rounded,
                color: AppTheme.heritageGold,
                size: 44,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Pillars extends StatelessWidget {
  const _Pillars();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'ANCIENT ROOTS',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: AppTheme.heritageInk.withValues(alpha: 0.72),
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 2.0,
              ),
            ),
          ),
          Container(
            width: 1,
            height: 14,
            color: AppTheme.heritageGold.withValues(alpha: 0.5),
          ),
          Expanded(
            child: Text(
              'MODERN CLASS',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: AppTheme.heritageInk.withValues(alpha: 0.72),
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 2.0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 48,
          height: 1,
          color: AppTheme.heritageGold.withValues(alpha: 0.4),
        ),
        const SizedBox(height: 12),
        Text(
          'INHERITING THE WISDOM OF AGES',
          style: GoogleFonts.inter(
            color: AppTheme.heritageInkMuted.withValues(alpha: 0.7),
            fontSize: 9,
            fontWeight: FontWeight.w500,
            letterSpacing: 2.4,
          ),
        ),
      ],
    );
  }
}
