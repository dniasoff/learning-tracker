import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';

/// Peach tone for the "Send Again" pill (matches email confirmation mock).
const Color _sendAgainPeach = Color(0xFFFFE4D6);

/// Opens the default mail client; [email] is optional (mailto target).
Future<void> openEmailApp({String? email}) async {
  final uri = email != null && email.isNotEmpty
      ? Uri(scheme: 'mailto', path: email)
      : Uri(scheme: 'mailto');
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri);
  }
}

/// Dashed rounded rectangle behind the envelope illustration.
class _DashedIllustrationFrame extends StatelessWidget {
  const _DashedIllustrationFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    const size = 96.0;
    return CustomPaint(
      painter: _DashedRRectPainter(color: AppTheme.brandOutline, radius: 18),
      child: SizedBox(
        width: size,
        height: size,
        child: Center(child: child),
      ),
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  _DashedRRectPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(1, 1, size.width - 2, size.height - 2),
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    const dash = 5.0;
    const gap = 4.0;
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        final end = math.min(d + dash, metric.length);
        canvas.drawPath(metric.extractPath(d, end), paint);
        d += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}

class _MailIllustration extends StatelessWidget {
  const _MailIllustration();

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Container(
          width: 112,
          height: 112,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppTheme.brandBlueSoft.withValues(alpha: 0.95),
                blurRadius: 28,
                spreadRadius: 2,
              ),
            ],
          ),
        ),
        const _DashedIllustrationFrame(
          child: Icon(Icons.mail_rounded, size: 44, color: AppTheme.brandBlue),
        ),
        Positioned(
          top: -4,
          right: 4,
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppTheme.brandBlue,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.brandBlue.withValues(alpha: 0.35),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.star_rounded,
              color: Colors.white,
              size: 16,
            ),
          ),
        ),
      ],
    );
  }
}

/// Email confirmation UI aligned with product design (sign-in dialog +
/// upgrade-to-cloud inline block).
class EmailVerificationConfirmPanel extends StatefulWidget {
  const EmailVerificationConfirmPanel({
    super.key,
    required this.bodyText,
    required this.onSendAgain,
    required this.onCancel,
    required this.onVerified,
    this.email,
    this.title = 'Confirm Your Email',
    this.verifiedLinkLabel = "I've verified",
    this.actionsLocked = false,
  });

  final String title;
  final String bodyText;
  final String? email;
  final String verifiedLinkLabel;

  /// When true, all actions are disabled (e.g. parent screen is submitting).
  final bool actionsLocked;
  final Future<void> Function() onSendAgain;
  final VoidCallback onCancel;
  final Future<void> Function() onVerified;

  @override
  State<EmailVerificationConfirmPanel> createState() =>
      _EmailVerificationConfirmPanelState();
}

class _EmailVerificationConfirmPanelState
    extends State<EmailVerificationConfirmPanel> {
  bool _sendingAgain = false;
  bool _checkingVerified = false;

  Future<void> _wrapSendAgain() async {
    setState(() => _sendingAgain = true);
    try {
      await widget.onSendAgain();
    } finally {
      if (mounted) setState(() => _sendingAgain = false);
    }
  }

  Future<void> _wrapVerified() async {
    setState(() => _checkingVerified = true);
    try {
      await widget.onVerified();
    } finally {
      if (mounted) setState(() => _checkingVerified = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = _sendingAgain || _checkingVerified || widget.actionsLocked;

    return Material(
      color: AppTheme.brandCreamCard,
      elevation: 12,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(28),
      // Scroll-escape valve: when a host constrains the panel's height (e.g. it
      // sits inside a height-clamped dialog) and the illustration + title +
      // body + buttons are taller than that, the content scrolls instead of
      // overflowing. Where the panel is unbounded (its usual placement) the
      // scroll view lays out at the Column's natural size — behaviour preserved.
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _MailIllustration(),
            const SizedBox(height: 20),
            Text(
              widget.title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppTheme.brandInk,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              widget.bodyText,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.brandInkMuted,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: busy
                    ? null
                    : () => openEmailApp(email: widget.email),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.brandBlue,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppTheme.brandBlue.withValues(
                    alpha: 0.5,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 4,
                  shadowColor: AppTheme.brandBlue.withValues(alpha: 0.45),
                  shape: const StadiumBorder(),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.mail_outline_rounded, size: 20),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        'Open Email',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: busy ? null : _wrapSendAgain,
                    style: FilledButton.styleFrom(
                      backgroundColor: _sendAgainPeach,
                      foregroundColor: AppTheme.brandInk,
                      disabledBackgroundColor: _sendAgainPeach.withValues(
                        alpha: 0.6,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                      shape: const StadiumBorder(),
                    ),
                    child: _sendingAgain
                        ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppTheme.brandInk.withValues(alpha: 0.7),
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.refresh_rounded,
                                size: 20,
                                color: AppTheme.brandInk,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'Send Again',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.labelLarge
                                      ?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.brandInk,
                                      ),
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: busy ? null : widget.onCancel,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.brandInk,
                      side: const BorderSide(
                        color: AppTheme.brandOutline,
                        width: 1.2,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: const StadiumBorder(),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.close_rounded,
                          size: 20,
                          color: AppTheme.brandInk,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            'Cancel',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: busy ? null : _wrapVerified,
              child: _checkingVerified
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      widget.verifiedLinkLabel,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.brandBlue,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
