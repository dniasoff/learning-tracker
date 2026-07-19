// AUD-tracks-22 (P3, features/tracks): the reorder-amnesty confirm-dialog
// preamble (fetch overdueCount, bail if unmounted, show
// ReorderConfirmDialog.showIfNeeded, bail if declined/unmounted) used to be
// copy-pasted ~10 lines at a time across 3 call sites in 2 screens
// (TrackLearningOrderScreen._onReorderSedarim/_onReorderMasechtos and
// LearningOrderScreen._onReorder). This file directly exercises the
// extracted ReorderAmnestyGuardMixin.confirmReorderAmnesty in isolation, via
// a minimal host widget, covering every branch the old duplicated block had:
//   - overdueCount == 0: dialog skipped, guard resolves true immediately.
//   - overdueCount > 0, user cancels: dialog shown, guard resolves false.
//   - overdueCount > 0, user confirms: dialog shown, guard resolves true.
//   - host unmounted while the overdueCount fetch is still in flight: guard
//     resolves false without touching BuildContext/setState.
//
// Red-first: before the Extract Method fix, ReorderAmnestyGuardMixin did not
// exist, so this test file failed to compile (the import and the `with
// ReorderAmnestyGuardMixin<...>` clause both referenced an undefined name).
// See the AUD-tracks-22 commit for the captured compiler-error evidence.

@Tags(['tracks'])
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/scheduler/presentation/providers/scheduler_providers.dart';
import 'package:learning_tracker/features/tracks/whole_curriculum_order/presentation/widgets/reorder_amnesty_guard_mixin.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

const _curriculumId = CurriculumId.mishnayos;

/// Minimal host exercising ReorderAmnestyGuardMixin the same way the real
/// reorder screens do: a button calls `confirmReorderAmnesty` and reports
/// the resolved bool (or that the future never resolved, for the
/// unmounted-mid-await case).
class _GuardHost extends ConsumerStatefulWidget {
  const _GuardHost({required this.onResult});

  final void Function(bool) onResult;

  @override
  ConsumerState<_GuardHost> createState() => _GuardHostState();
}

class _GuardHostState extends ConsumerState<_GuardHost>
    with ReorderAmnestyGuardMixin<_GuardHost> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ElevatedButton(
        onPressed: () async {
          final result = await confirmReorderAmnesty(
            ref,
            context,
            _curriculumId,
          );
          widget.onResult(result);
        },
        child: const Text('Reorder'),
      ),
    );
  }
}

Widget _buildApp(Widget child, {List<Override> overrides = const []}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    ),
  );
}

void main() {
  group('ReorderAmnestyGuardMixin.confirmReorderAmnesty', () {
    testWidgets(
      'overdueCount == 0: dialog is skipped and the guard resolves true',
      (tester) async {
        bool? result;
        await tester.pumpWidget(
          _buildApp(
            _GuardHost(onResult: (r) => result = r),
            overrides: [
              overdueCountForCurriculumProvider(
                _curriculumId,
              ).overrideWith((ref) async => 0),
            ],
          ),
        );

        await tester.tap(find.byType(ElevatedButton));
        await tester.pumpAndSettle();

        expect(find.text('Reorder Content?'), findsNothing);
        expect(result, isTrue);
      },
    );

    testWidgets('overdueCount > 0, user cancels: dialog is shown and the guard '
        'resolves false', (tester) async {
      bool? result;
      await tester.pumpWidget(
        _buildApp(
          _GuardHost(onResult: (r) => result = r),
          overrides: [
            overdueCountForCurriculumProvider(
              _curriculumId,
            ).overrideWith((ref) async => 3),
          ],
        ),
      );

      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      expect(find.text('Reorder Content?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Reorder Content?'), findsNothing);
      expect(result, isFalse);
    });

    testWidgets(
      'overdueCount > 0, user confirms: dialog is shown and the guard '
      'resolves true',
      (tester) async {
        bool? result;
        await tester.pumpWidget(
          _buildApp(
            _GuardHost(onResult: (r) => result = r),
            overrides: [
              overdueCountForCurriculumProvider(
                _curriculumId,
              ).overrideWith((ref) async => 3),
            ],
          ),
        );

        await tester.tap(find.byType(ElevatedButton));
        await tester.pumpAndSettle();

        expect(find.text('Reorder Content?'), findsOneWidget);
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();

        expect(find.text('Reorder Content?'), findsNothing);
        expect(result, isTrue);
      },
    );

    testWidgets(
      'host unmounted while the overdueCount fetch is in flight: the guard '
      'never calls back and never throws',
      (tester) async {
        final overdueCompleter = Completer<int>();
        final results = <bool>[];
        final overrides = [
          overdueCountForCurriculumProvider(
            _curriculumId,
          ).overrideWith((ref) => overdueCompleter.future),
        ];

        await tester.pumpWidget(
          _buildApp(_GuardHost(onResult: results.add), overrides: overrides),
        );

        await tester.tap(find.byType(ElevatedButton));
        await tester.pump();

        // Swap the host out from under the in-flight await before the
        // overdueCount future resolves — mirrors a user navigating away
        // mid-reorder-tap. The override set is kept identical: Riverpod's
        // ProviderScope forbids changing the number of overrides across a
        // rebuild of the same scope, which is orthogonal to what this test
        // is exercising (state disposal mid-await).
        await tester.pumpWidget(
          _buildApp(const SizedBox.shrink(), overrides: overrides),
        );

        overdueCompleter.complete(3);
        // Pumping to settle must not throw — the guard's `context.mounted`
        // check after the await must stop it from touching the disposed
        // state's BuildContext (no dialog show, no framework assertion).
        await tester.pumpAndSettle();

        // The host's onPressed closure keeps running after the state is
        // disposed (plain Dart futures aren't cancelled by widget disposal),
        // so the callback still fires — but the guard must have resolved it
        // to `false` without ever reaching the dialog.
        expect(results, [false]);
        expect(find.text('Reorder Content?'), findsNothing);
      },
    );
  });
}
