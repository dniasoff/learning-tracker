import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/user_mode.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/core/providers/firebase_providers.dart';
import 'package:learning_tracker/features/onboarding/presentation/providers/onboarding_providers.dart';

enum _LearningMode {
  selfLearner,
  parent,
  tutor,
}

@RoutePage()
class ModeSelectionScreen extends ConsumerStatefulWidget {
  const ModeSelectionScreen({super.key});

  @override
  ConsumerState<ModeSelectionScreen> createState() =>
      _ModeSelectionScreenState();
}

class _ModeSelectionScreenState extends ConsumerState<ModeSelectionScreen>
    with TickerProviderStateMixin {
  _LearningMode? _selectedMode;
  bool _isLoading = false;

  late final AnimationController _entranceController;
  late final AnimationController _pulseController;
  late final AnimationController _progressController;

  late final Animation<double> _headerSlide;
  late final Animation<double> _headerFade;
  late final List<Animation<double>> _cardSlides;
  late final List<Animation<double>> _cardFades;
  late final Animation<double> _buttonFade;
  late final Animation<double> _progressAnim;

  @override
  void initState() {
    super.initState();

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _progressAnim = CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeOutCubic,
    );

    _headerSlide = Tween<double>(begin: -30, end: 0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOutCubic),
      ),
    );
    _headerFade = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
    );

    _cardSlides = List.generate(3, (i) {
      final start = 0.15 + i * 0.12;
      final end = (start + 0.35).clamp(0.0, 1.0);
      return Tween<double>(begin: 60, end: 0).animate(
        CurvedAnimation(
          parent: _entranceController,
          curve: Interval(start, end, curve: Curves.easeOutCubic),
        ),
      );
    });
    _cardFades = List.generate(3, (i) {
      final start = 0.15 + i * 0.12;
      final end = (start + 0.3).clamp(0.0, 1.0);
      return CurvedAnimation(
        parent: _entranceController,
        curve: Interval(start, end, curve: Curves.easeOut),
      );
    });

    _buttonFade = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.7, 1.0, curve: Curves.easeOut),
    );

    _entranceController.forward();
    _progressController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _pulseController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  UserMode _toUserMode(_LearningMode mode) {
    switch (mode) {
      case _LearningMode.selfLearner:
      case _LearningMode.tutor:
        return UserMode.adult;
      case _LearningMode.parent:
        return UserMode.child;
    }
  }

  Future<void> _confirmSelection() async {
    if (_selectedMode == null) return;

    setState(() => _isLoading = true);
    try {
      final user = ref.read(firebaseAuthProvider).currentUser;
      if (user == null) {
        if (mounted) {
          unawaited(context.router.replaceAll([const SignInRoute()]));
        }
        return;
      }

      final profileService = ref.read(userProfileServiceProvider);
      await profileService.setUserMode(
        firebaseUid: user.uid,
        displayName:
            user.displayName ?? user.email?.split('@').first ?? 'User',
        mode: _toUserMode(_selectedMode!),
      );

      if (mounted) {
        unawaited(context.router.replace(const OnboardingRoute()));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save mode. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const green = Color(0xFF4ADE80);

    return Scaffold(
      body: SafeArea(
        child: AnimatedBuilder(
          animation: Listenable.merge([
            _entranceController,
            _pulseController,
            _progressController,
          ]),
          builder: (context, _) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 16),
                  // Animated progress bar
                  AnimatedBuilder(
                    animation: _progressAnim,
                    builder: (context, _) {
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Stack(
                          children: [
                            Container(
                              height: 4,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            FractionallySizedBox(
                              widthFactor: (1 / 3) * _progressAnim.value,
                              child: Container(
                                height: 4,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(4),
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF22C55E),
                                      green,
                                      Color(0xFF86EFAC),
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: green.withValues(alpha: 0.6),
                                      blurRadius: 8,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),

                  // Step label + header with slide animation
                  Transform.translate(
                    offset: Offset(0, _headerSlide.value),
                    child: Opacity(
                      opacity: _headerFade.value,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ShaderMask(
                            shaderCallback: (bounds) => const LinearGradient(
                              colors: [Color(0xFF22C55E), Color(0xFF86EFAC)],
                            ).createShader(bounds),
                            child: const Text(
                              'STEP 1 OF 3',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 2.0,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Who are you\nlearning for?',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Choose your learning mode to customize your experience.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.white.withValues(alpha: 0.55),
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 36),

                  // Mode cards with staggered entrance
                  ..._buildModeCards(green),

                  const Spacer(),

                  // Terms text
                  FadeTransition(
                    opacity: _buttonFade,
                    child: Center(
                      child: Text(
                        'By continuing, you agree to our terms of service\nand spiritual growth commitment.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.35),
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Continue button
                  FadeTransition(
                    opacity: _buttonFade,
                    child: _buildContinueButton(green),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  List<Widget> _buildModeCards(Color green) {
    final modes = [
      (
        mode: _LearningMode.selfLearner,
        title: 'Self-Learner',
        description:
            'Personal progress tracking, Siyum reminders, and daily goals.',
        icon: Icons.person,
      ),
      (
        mode: _LearningMode.parent,
        title: 'Parent',
        description:
            'Reward management for children, progress reports, and family leaderboards.',
        icon: Icons.people_outline,
      ),
      (
        mode: _LearningMode.tutor,
        title: 'Tutor / Rebbi',
        description:
            'Student management, class-wide assignments, and individual tracking.',
        icon: Icons.school_outlined,
      ),
    ];

    return List.generate(modes.length, (i) {
      final m = modes[i];
      return Padding(
        padding: EdgeInsets.only(bottom: i < 2 ? 14 : 0),
        child: Transform.translate(
          offset: Offset(0, _cardSlides[i].value),
          child: Opacity(
            opacity: _cardFades[i].value,
            child: _FancyModeCard(
              title: m.title,
              description: m.description,
              icon: m.icon,
              isSelected: _selectedMode == m.mode,
              pulseAnimation: _pulseController,
              onTap: _isLoading
                  ? null
                  : () => setState(() => _selectedMode = m.mode),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildContinueButton(Color green) {
    final isEnabled = _selectedMode != null && !_isLoading;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: isEnabled
            ? const LinearGradient(
                colors: [Color(0xFF22C55E), Color(0xFF4ADE80)],
              )
            : null,
        color: isEnabled ? null : Colors.white.withValues(alpha: 0.08),
        boxShadow: isEnabled
            ? [
                BoxShadow(
                  color: green.withValues(alpha: 0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isEnabled ? _confirmSelection : null,
          borderRadius: BorderRadius.circular(28),
          child: Center(
            child: _isLoading
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.black,
                    ),
                  )
                : Text(
                    'Continue',
                    style: TextStyle(
                      color: isEnabled
                          ? Colors.black
                          : Colors.white.withValues(alpha: 0.3),
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _FancyModeCard extends StatefulWidget {
  const _FancyModeCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.isSelected,
    required this.pulseAnimation,
    required this.onTap,
  });
  final String title;
  final String description;
  final IconData icon;
  final bool isSelected;
  final Animation<double> pulseAnimation;
  final VoidCallback? onTap;

  @override
  State<_FancyModeCard> createState() => _FancyModeCardState();
}

class _FancyModeCardState extends State<_FancyModeCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _selectController;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _selectController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 1.02).animate(
      CurvedAnimation(parent: _selectController, curve: Curves.easeOutBack),
    );
    if (widget.isSelected) _selectController.forward();
  }

  @override
  void didUpdateWidget(_FancyModeCard old) {
    super.didUpdateWidget(old);
    if (widget.isSelected && !old.isSelected) {
      _selectController.forward();
    } else if (!widget.isSelected && old.isSelected) {
      _selectController.reverse();
    }
  }

  @override
  void dispose() {
    _selectController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF4ADE80);

    return AnimatedBuilder(
      animation: Listenable.merge([_selectController, widget.pulseAnimation]),
      builder: (context, child) {
        final pulseValue = widget.isSelected
            ? 0.3 + widget.pulseAnimation.value * 0.3
            : 0.0;

        return Transform.scale(
          scale: _scaleAnim.value,
          child: GestureDetector(
            onTap: widget.onTap,
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: widget.isSelected
                    ? green.withValues(alpha: 0.08)
                    : const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: widget.isSelected
                      ? green.withValues(alpha: 0.8)
                      : Colors.white.withValues(alpha: 0.07),
                  width: widget.isSelected ? 1.5 : 1,
                ),
                boxShadow: widget.isSelected
                    ? [
                        BoxShadow(
                          color: green.withValues(alpha: pulseValue * 0.4),
                          blurRadius: 24,
                          spreadRadius: -2,
                        ),
                        BoxShadow(
                          color: green.withValues(alpha: pulseValue * 0.15),
                          blurRadius: 40,
                          spreadRadius: 4,
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: Row(
                children: [
                  // Icon with animated background
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: widget.isSelected
                          ? LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                green.withValues(alpha: 0.3),
                                green.withValues(alpha: 0.1),
                              ],
                            )
                          : null,
                      color: widget.isSelected
                          ? null
                          : Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(14),
                      border: widget.isSelected
                          ? Border.all(
                              color: green.withValues(alpha: 0.3),
                              width: 1,
                            )
                          : null,
                    ),
                    child: Icon(
                      widget.icon,
                      color: widget.isSelected
                          ? green
                          : Colors.white.withValues(alpha: 0.6),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: TextStyle(
                            color: widget.isSelected ? green : Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.description,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.45),
                            fontSize: 13,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Animated check icon
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    transitionBuilder: (child, animation) {
                      return ScaleTransition(
                        scale: animation,
                        child: child,
                      );
                    },
                    child: widget.isSelected
                        ? Container(
                            key: const ValueKey('selected'),
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xFF22C55E),
                                  Color(0xFF4ADE80),
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: green.withValues(alpha: 0.5),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.check,
                              color: Colors.black,
                              size: 18,
                            ),
                          )
                        : Container(
                            key: const ValueKey('unselected'),
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.15),
                                width: 1.5,
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
