// Story 5.4 (DNI-519; AD-48): the export identity fails closed while the
// learner is unresolved, the Export PDF pill is busy for exactly one
// export at a time (AC-7), and each way an export ends maps to its result.
@Tags(['progress', 'lifetime', 'story_5_4'])
library;

import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/features/learner_state/data/repositories/learner_state_sources.dart';
import 'package:learning_tracker/features/profiles/domain/models/learner_profile_entity.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/parent_session_provider.dart';
import 'package:learning_tracker/features/progress/domain/services/lifetime_report_pdf_builder.dart';
import 'package:learning_tracker/features/progress/domain/services/lifetime_report_pdf_document.dart';
import 'package:learning_tracker/features/progress/presentation/providers/lifetime_report_export_provider.dart';
import 'package:learning_tracker/features/progress/presentation/services/lifetime_report_export_service.dart';

import '../../../../helpers/learner_state/c0_fixtures.dart';
import '../../../../helpers/progress/report_pdf_fixtures.dart';

LearnerProfileEntity _profile(String id) => LearnerProfileEntity(
  profileId: id,
  displayName: 'Dovid',
  mode: ProfileMode.child,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

final class _Fonts implements LifetimeReportPdfFontSource {
  @override
  Future<LifetimeReportPdfFonts> load() async => reportPdfFonts();
}

final class _Files implements LifetimeReportPdfFileStore {
  final deleted = <String>[];

  @override
  Future<void> delete(String path) async => deleted.add(path);

  @override
  Future<String> write(String fileName, Uint8List bytes) async =>
      '/tmp/$fileName';
}

final class _Sharer implements LifetimeReportPdfSharer {
  _Sharer(this.outcome, {this.error});

  final LifetimeReportShareOutcome outcome;
  final Exception? error;
  final origins = <Rect?>[];

  @override
  Future<LifetimeReportShareOutcome> share({
    required String path,
    required String fileName,
    Rect? origin,
    String? subject,
  }) async {
    origins.add(origin);
    if (error case final e?) throw e;
    return outcome;
  }
}

class _Harness {
  _Harness({
    this.parent = true,
    this.outcome = LifetimeReportShareOutcome.shared,
    this.shareError,
    this.renderError,
  });

  final bool parent;
  final LifetimeReportShareOutcome outcome;
  final Exception? shareError;
  final Exception? renderError;
  Object? scope = 'learner-a';
  Completer<Uint8List>? gate;
  late final sharer = _Sharer(outcome, error: shareError);

  ProviderContainer container() {
    final c = ProviderContainer(
      overrides: [
        lifetimeReportExportServiceProvider.overrideWith(
          (ref) => LifetimeReportExportService(
            isParentSession: () async => parent,
            currentScope: () => scope,
            fonts: _Fonts(),
            files: _Files(),
            sharer: sharer,
            render: (doc, fonts) async {
              if (renderError case final e?) throw e;
              if (gate case final g?) return g.future;
              return Uint8List.fromList('%PDF-'.codeUnits);
            },
          ),
        ),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }
}

Future<LifetimeReportExportResult> _export(
  ProviderContainer c, {
  Object? scope = 'learner-a',
  Rect? origin,
}) => c
    .read(lifetimeReportExportProvider.notifier)
    .export(
      document: reportPdfDocument(
        rows: const [LifetimeReportPdfRow('Distinct · 1 Mishna')],
      ),
      fileName: 'report.pdf',
      origin: origin,
      scope: scope,
    );

void main() {
  group('lifetimeReportExportScope', () {
    final scope = c0Scope();

    test('is the learner scope and profile id when both resolved', () {
      final result = lifetimeReportExportScope(
        AsyncData(scope),
        AsyncData(_profile('p1')),
      );
      expect(result, isNotNull);
      expect(result!.learner, scope);
      expect(result.profileId, 'p1');
    });

    test('is null while either side is loading', () {
      expect(
        lifetimeReportExportScope(
          const AsyncLoading(),
          AsyncData(_profile('p1')),
        ),
        isNull,
      );
      expect(
        lifetimeReportExportScope(AsyncData(scope), const AsyncLoading()),
        isNull,
      );
    });

    test('is null when either side failed', () {
      final error = AsyncError<Never>(StateError('x'), StackTrace.empty);
      expect(
        lifetimeReportExportScope(error, AsyncData(_profile('p1'))),
        isNull,
      );
      expect(lifetimeReportExportScope(AsyncData(scope), error), isNull);
    });

    test('is null when there is no learner scope or no profile', () {
      expect(
        lifetimeReportExportScope(
          const AsyncData(null),
          AsyncData(_profile('p1')),
        ),
        isNull,
      );
      expect(
        lifetimeReportExportScope(AsyncData(scope), const AsyncData(null)),
        isNull,
      );
    });
  });

  group('lifetimeReportExportProvider', () {
    test('starts idle', () {
      final c = _Harness().container();
      expect(c.read(lifetimeReportExportProvider), isFalse);
      expect(c.read(lifetimeReportExportProvider.notifier).busy, isFalse);
    });

    test('a completed export is shared and the pill is idle again', () async {
      final h = _Harness();
      final c = h.container();
      const origin = Rect.fromLTWH(1, 2, 3, 4);
      final result = await _export(c, origin: origin);
      expect(result, LifetimeReportExportResult.shared);
      expect(h.sharer.origins, [origin]);
      expect(c.read(lifetimeReportExportProvider), isFalse);
    });

    test('a dismissed share sheet maps to dismissed', () async {
      final c = _Harness(
        outcome: LifetimeReportShareOutcome.dismissed,
      ).container();
      expect(await _export(c), LifetimeReportExportResult.dismissed);
    });

    test('outside a parent session the export is denied', () async {
      final h = _Harness(parent: false);
      final c = h.container();
      expect(await _export(c), LifetimeReportExportResult.denied);
      expect(h.sharer.origins, isEmpty);
      expect(c.read(lifetimeReportExportProvider), isFalse);
    });

    test(
      'a learner switch makes the export superseded, nothing shared',
      () async {
        final h = _Harness()..scope = 'learner-b';
        final c = h.container();
        expect(
          await _export(c, scope: 'learner-a'),
          LifetimeReportExportResult.superseded,
        );
        expect(h.sharer.origins, isEmpty);
      },
    );

    test('a render failure maps to failed and frees the pill', () async {
      final c = _Harness(renderError: Exception('boom')).container();
      expect(await _export(c), LifetimeReportExportResult.failed);
      expect(c.read(lifetimeReportExportProvider), isFalse);
    });

    test('a share failure maps to failed', () async {
      final c = _Harness(shareError: Exception('no sheet')).container();
      expect(await _export(c), LifetimeReportExportResult.failed);
    });

    test('is busy while an export runs and ignores a second one', () async {
      final h = _Harness()..gate = Completer<Uint8List>();
      final c = h.container();
      final sub = c.listen(lifetimeReportExportProvider, (_, _) {});
      addTearDown(sub.close);
      final first = _export(c);
      await Future<void>.delayed(Duration.zero);
      expect(c.read(lifetimeReportExportProvider), isTrue);
      expect(c.read(lifetimeReportExportProvider.notifier).busy, isTrue);

      expect(await _export(c), LifetimeReportExportResult.ignored);
      expect(c.read(lifetimeReportExportProvider), isTrue);

      h.gate!.complete(Uint8List.fromList('%PDF-'.codeUnits));
      expect(await first, LifetimeReportExportResult.shared);
      expect(c.read(lifetimeReportExportProvider), isFalse);
      expect(h.sharer.origins, hasLength(1));
    });
  });

  group('lifetimeReportExportServiceProvider', () {
    test(
      'the app wiring denies a session that is not a parent session',
      () async {
        final c = ProviderContainer(
          overrides: [
            parentSessionProvider.overrideWith((ref) async => false),
            activeLearnerScopeProvider.overrideWith((ref) async => c0Scope()),
            activeProfileProvider.overrideWith((ref) async => _profile('p1')),
          ],
        );
        addTearDown(c.dispose);
        final sub = c.listen(lifetimeReportExportProvider, (_, _) {});
        addTearDown(sub.close);
        await c.read(parentSessionProvider.future);
        expect(await _export(c), LifetimeReportExportResult.denied);
      },
    );

    test(
      'the app wiring denies while the session is still resolving',
      () async {
        final pending = Completer<bool>();
        final c = ProviderContainer(
          overrides: [
            parentSessionProvider.overrideWith((ref) => pending.future),
          ],
        );
        addTearDown(c.dispose);
        final sub = c.listen(lifetimeReportExportProvider, (_, _) {});
        addTearDown(sub.close);
        expect(await _export(c), LifetimeReportExportResult.denied);
      },
    );
  });
}
