// Regression test for AUD-app-01: app_shell.dart's context banners
// (ChildViewBanner, TutorModeIndicatorBar, ProfileSwitcherBar) hardcoded a
// literal `height:` on their outer Container, which:
//   1. could clip/overflow scaled label text (no MediaQuery.textScaler
//      awareness), and
//   2. capped the Exit/tap affordance's hit-testable area well under the
//      48dp Material minimum touch-target size (kMinInteractiveDimension) —
//      ProfileSwitcherBar was 44dp, TutorModeIndicatorBar/ChildViewBanner's
//      Exit control was ~18-20dp.
//
// Fix: the Containers no longer hardcode `height:`; the Exit/tap affordance
// is floored at kMinInteractiveDimension via ConstrainedBox, independent of
// the compact visual chip inside it, and the appBarBuilder's PreferredSize
// calc tracks the same textScaler-aware floor (see _contextBarHeight in
// app_shell.dart) so the reserved space always matches the real rendered
// height.
//
// Each banner is pumped at TextScaler.linear(1.3) + Locale('he') (matching
// the AC) and asserted to:
//   (a) not throw a RenderFlex overflow,
//   (b) not visually truncate its label (RenderParagraph.didExceedMaxLines),
//   (c) expose an Exit/tap affordance >= kMinInteractiveDimension in both
//       dimensions.

@Tags(['needs_flutter', 'app_shell', 'aud_app_01'])
library;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/app/router/app_shell.dart';
import 'package:learning_tracker/features/account/domain/models/auth_state.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_state_provider.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/features/profiles/domain/models/learner_profile_entity.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/parent_pin_session_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/tutoring/domain/models/session_role.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/active_tutored_profile_provider.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

// ── Stubs ─────────────────────────────────────────────────────────────────────

class _StubAuthStateNotifier extends AuthStateNotifier {
  _StubAuthStateNotifier(this._initial);
  final AuthState _initial;

  @override
  AuthState build() => _initial;
}

class _StubParentPinNotifier extends ParentPinAuthenticatedProfileId {
  _StubParentPinNotifier(this._value);
  final String? _value;

  @override
  String? build() => _value;
}

class _StubActiveProfileId extends ActiveProfileId {
  _StubActiveProfileId(this._id);
  final String _id;

  @override
  String build() => _id;
}

class _StubActiveTutoredProfileSelection extends ActiveTutoredProfileSelection {
  _StubActiveTutoredProfileSelection(this._value);
  final TutoredProfileSelection? _value;

  @override
  TutoredProfileSelection? build() => _value;
}

// ── Fixtures ─────────────────────────────────────────────────────────────────

final _kNow = DateTime(2024);

const _kAuthState = AuthState.signedIn(
  user: AuthUser(
    uid: 'account-1',
    email: 'parent@example.test',
    displayName: 'Parent',
  ),
  tier: Tier.local,
);

LearnerProfileEntity _profile({
  required String name,
  required ProfileMode mode,
}) => LearnerProfileEntity(
  profileId: 'ulid-1',
  displayName: name,
  mode: mode,
  createdAt: _kNow,
  updatedAt: _kNow,
);

// ── Harness ──────────────────────────────────────────────────────────────────

/// Wraps [child] in the standard app scaffolding (ProviderScope + l10n +
/// MaterialApp) with a forced [TextScaler] and [Locale] on top of the ambient
/// MediaQuery — matching the AC's "TextScaler.linear(1.3)+ and Locale('he')".
Widget _wrapAtScale({
  required Widget child,
  List<Override> overrides = const [],
  double textScale = 1.3,
  Locale locale = const Locale('he'),
}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) {
          final media = MediaQuery.of(context);
          return MediaQuery(
            data: media.copyWith(textScaler: TextScaler.linear(textScale)),
            // mainAxisSize.min mirrors production: in app_shell.dart these
            // banners sit inside a `Column(mainAxisSize: MainAxisSize.min)`
            // wrapped by a PreferredSize (see appBarBuilder), so the banner
            // shrink-wraps its content height rather than filling the whole
            // Scaffold body — matching that here is what makes a fixed
            // `height:` literal (the bug) actually clip content in this test.
            child: Scaffold(
              body: Column(mainAxisSize: MainAxisSize.min, children: [child]),
            ),
          );
        },
      ),
    ),
  );
}

/// True when any Text descendant of [root] has visually truncated its label
/// (i.e. Flutter's ellipsis clipping actually engaged), detected via the
/// underlying RenderParagraph's `didExceedMaxLines` — NOT a string-content
/// check, since `Text.data` is never mutated by TextOverflow.ellipsis.
bool _anyTextTruncated(WidgetTester tester, Finder root) {
  final richTexts = find.descendant(of: root, matching: find.byType(RichText));
  for (final element in richTexts.evaluate()) {
    final renderObject = element.renderObject;
    if (renderObject is RenderParagraph && renderObject.didExceedMaxLines) {
      return true;
    }
  }
  return false;
}

void main() {
  group('AUD-app-01 — context banner accessibility (1.3x scale, he locale)', () {
    testWidgets(
      'ProfileSwitcherBar: no overflow, no truncation, tap target >= 48dp',
      (tester) async {
        await tester.pumpWidget(
          _wrapAtScale(
            child: const ProfileSwitcherBar(),
            overrides: [
              authStateProvider.overrideWith(
                () => _StubAuthStateNotifier(_kAuthState),
              ),
              activeProfileIdProvider.overrideWith(
                () => _StubActiveProfileId('ulid-1'),
              ),
              profileListStreamProvider.overrideWith(
                (ref) => Stream.value([
                  _profile(name: 'הורה', mode: ProfileMode.adult),
                ]),
              ),
              activeProfileProvider.overrideWith(
                (ref) async => _profile(name: 'הורה', mode: ProfileMode.adult),
              ),
              activeTutoredProfileSelectionProvider.overrideWith(
                () => _StubActiveTutoredProfileSelection(null),
              ),
              parentPinAuthenticatedProfileIdProvider.overrideWith(
                () => _StubParentPinNotifier(null),
              ),
            ],
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(
          tester.takeException(),
          isNull,
          reason:
              'ProfileSwitcherBar must not overflow at 1.3x scale + he locale',
        );

        expect(
          _anyTextTruncated(tester, find.byType(ProfileSwitcherBar)),
          isFalse,
          reason: 'ProfileSwitcherBar label must not visually truncate',
        );

        final tapTarget = find.byKey(const Key('appShellProfileSwitcherBar'));
        expect(tapTarget, findsOneWidget);
        final size = tester.getSize(tapTarget);
        expect(
          size.height,
          greaterThanOrEqualTo(kMinInteractiveDimension),
          reason:
              'ProfileSwitcherBar tap target must be >= '
              '${kMinInteractiveDimension}dp tall',
        );
      },
    );

    testWidgets(
      'TutorModeIndicatorBar: no overflow, no truncation, Exit tap target >= 48dp',
      (tester) async {
        await tester.pumpWidget(
          _wrapAtScale(
            child: const TutorModeIndicatorBar(),
            overrides: [
              activeProfileProvider.overrideWith(
                (ref) async =>
                    _profile(name: 'תלמיד ארוך מאוד', mode: ProfileMode.child),
              ),
            ],
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(
          tester.takeException(),
          isNull,
          reason:
              'TutorModeIndicatorBar must not overflow at 1.3x scale + he locale',
        );

        expect(
          _anyTextTruncated(tester, find.byType(TutorModeIndicatorBar)),
          isFalse,
          reason: 'TutorModeIndicatorBar label must not visually truncate',
        );

        final exitInkWell = find.ancestor(
          of: find.byIcon(Icons.logout_rounded),
          matching: find.byType(InkWell),
        );
        expect(exitInkWell, findsOneWidget);
        final size = tester.getSize(exitInkWell);
        expect(
          size.height,
          greaterThanOrEqualTo(kMinInteractiveDimension),
          reason:
              'TutorModeIndicatorBar Exit control must be >= '
              '${kMinInteractiveDimension}dp tall',
        );
        expect(
          size.width,
          greaterThanOrEqualTo(kMinInteractiveDimension),
          reason:
              'TutorModeIndicatorBar Exit control must be >= '
              '${kMinInteractiveDimension}dp wide',
        );
      },
    );

    testWidgets(
      'ChildViewBanner: no overflow, no truncation, Exit tap target >= 48dp',
      (tester) async {
        await tester.pumpWidget(
          _wrapAtScale(
            child: ChildViewBanner(
              childName: 'יוסף',
              profiles: const [],
              onExit: () {},
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(
          tester.takeException(),
          isNull,
          reason: 'ChildViewBanner must not overflow at 1.3x scale + he locale',
        );

        expect(
          _anyTextTruncated(tester, find.byType(ChildViewBanner)),
          isFalse,
          reason: 'ChildViewBanner label must not visually truncate',
        );

        final exitInkWell = find.ancestor(
          of: find.byIcon(Icons.logout_rounded),
          matching: find.byType(InkWell),
        );
        expect(exitInkWell, findsOneWidget);
        final size = tester.getSize(exitInkWell);
        expect(
          size.height,
          greaterThanOrEqualTo(kMinInteractiveDimension),
          reason:
              'ChildViewBanner Exit control must be >= '
              '${kMinInteractiveDimension}dp tall',
        );
        expect(
          size.width,
          greaterThanOrEqualTo(kMinInteractiveDimension),
          reason:
              'ChildViewBanner Exit control must be >= '
              '${kMinInteractiveDimension}dp wide',
        );
      },
    );
  });
}
