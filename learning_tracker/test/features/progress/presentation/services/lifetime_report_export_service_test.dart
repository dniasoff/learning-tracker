// Story 5.4 (DNI-519): the report export runs only in a parent session,
// renders off the UI isolate, writes a complete file or none, and shares it
// as `application/pdf` with the exact file name (AC-7–AC-9, AC-11, AC-12).
@Tags(['progress', 'lifetime', 'story_5_4'])
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/features/profiles/domain/models/learner_profile_entity.dart';
import 'package:learning_tracker/features/progress/domain/services/lifetime_report_pdf_builder.dart';
import 'package:learning_tracker/features/progress/domain/services/lifetime_report_pdf_document.dart';
import 'package:learning_tracker/features/progress/presentation/providers/lifetime_report_export_provider.dart';
import 'package:learning_tracker/features/progress/presentation/services/lifetime_report_export_service.dart';

import '../../../../benchmark/perf_budget.dart';
import '../../../../helpers/progress/report_pdf_fixtures.dart';

const _fileName = 'learning-report-Dovid-mishnayos-2026-10-03.pdf';
const _shareChannel = MethodChannel('dev.fluttercommunity.plus/share');

final class _Fonts implements LifetimeReportPdfFontSource {
  int loads = 0;

  @override
  Future<LifetimeReportPdfFonts> load() async {
    loads++;
    return reportPdfFonts();
  }
}

final class _Sharer implements LifetimeReportPdfSharer {
  _Sharer({this.outcome = LifetimeReportShareOutcome.shared, this.error});

  final LifetimeReportShareOutcome outcome;
  final Exception? error;
  final shares = <({String path, String fileName, Rect? origin})>[];

  /// Whether the shared file existed, complete, when the sheet opened.
  final sharedBytes = <Uint8List>[];

  @override
  Future<LifetimeReportShareOutcome> share({
    required String path,
    required String fileName,
    Rect? origin,
    String? subject,
  }) async {
    shares.add((path: path, fileName: fileName, origin: origin));
    sharedBytes.add(File(path).readAsBytesSync());
    if (error case final e?) throw e;
    return outcome;
  }
}

final class _FailingFiles implements LifetimeReportPdfFileStore {
  @override
  Future<void> delete(String path) async {}

  @override
  Future<String> write(String fileName, Uint8List bytes) =>
      throw const FileSystemException('No space left on device');
}

/// A file store that runs [onWritten] once the file is complete.
final class _SwitchingFiles implements LifetimeReportPdfFileStore {
  _SwitchingFiles(this.inner, {required this.onWritten});

  final LifetimeReportPdfFileStore inner;
  final void Function() onWritten;
  int written = 0;

  @override
  Future<void> delete(String path) => inner.delete(path);

  @override
  Future<String> write(String fileName, Uint8List bytes) async {
    final path = await inner.write(fileName, bytes);
    written++;
    onWritten();
    return path;
  }
}

Uint8List _fakePdf = Uint8List.fromList(utf8.encode('%PDF-1.7 fake'));

Future<Uint8List> _isolateName(
  LifetimeReportPdfDocument document,
  LifetimeReportPdfFonts fonts,
) async => Uint8List.fromList(utf8.encode(Isolate.current.debugName ?? ''));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory temp;
  late _Fonts fonts;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('report_export_');
    fonts = _Fonts();
  });

  tearDown(() => temp.deleteSync(recursive: true));

  Directory exportDir() =>
      Directory('${temp.path}/${TemporaryReportPdfFileStore.folder}');

  List<String> exported() => exportDir().existsSync()
      ? exportDir().listSync().map((f) => f.uri.pathSegments.last).toList()
      : const [];

  LifetimeReportExportService service({
    bool parent = true,
    Future<bool> Function()? isParent,
    LifetimeReportPdfRenderer? render,
    LifetimeReportPdfFileStore? files,
    LifetimeReportPdfSharer? sharer,
    Object? Function()? currentScope,
  }) => LifetimeReportExportService(
    isParentSession: isParent ?? () async => parent,
    currentScope: currentScope ?? () => 'learner-a',
    fonts: fonts,
    files: files ?? TemporaryReportPdfFileStore(directory: () async => temp),
    sharer: sharer ?? _Sharer(),
    render: render ?? (doc, f) async => _fakePdf,
  );

  final document = reportPdfDocument(
    rows: const [LifetimeReportPdfRow('Distinct · 1,204 Mishnayos')],
  );

  group('AC-8 share', () {
    test('writes the file under its exact name and shares it', () async {
      final sharer = _Sharer();
      const origin = Rect.fromLTWH(24, 700, 320, 48);
      final outcome = await service(
        sharer: sharer,
      ).export(document: document, fileName: _fileName, origin: origin);
      expect(outcome, LifetimeReportShareOutcome.shared);
      final share = sharer.shares.single;
      expect(share.fileName, _fileName);
      expect(share.path, endsWith('/$_fileName'));
      expect(share.origin, origin);
      expect(sharer.sharedBytes.single, _fakePdf);
      expect(exported(), [_fileName]);
    });

    test('a dismissed sheet is not an error', () async {
      final outcome = await service(
        sharer: _Sharer(outcome: LifetimeReportShareOutcome.dismissed),
      ).export(document: document, fileName: _fileName);
      expect(outcome, LifetimeReportShareOutcome.dismissed);
    });

    test('the next export replaces the previous file', () async {
      final s = service();
      await s.export(document: document, fileName: 'one.pdf');
      await s.export(document: document, fileName: _fileName);
      expect(exported(), [_fileName]);
    });

    group('through share_plus', () {
      final calls = <MethodCall>[];
      var reply = 'com.example.target';

      setUp(() {
        calls.clear();
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(_shareChannel, (call) async {
              calls.add(call);
              return reply;
            });
      });

      tearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(_shareChannel, null);
      });

      test(
        'MIME type application/pdf, the file path and the iPad anchor',
        () async {
          reply = 'com.example.target';
          const origin = Rect.fromLTWH(120, 900, 360, 52);
          final outcome = await service(
            sharer: const SharePlusLifetimeReportPdfSharer(),
          ).export(document: document, fileName: _fileName, origin: origin);
          expect(outcome, LifetimeReportShareOutcome.shared);
          final args = Map<String, Object?>.from(calls.single.arguments as Map);
          expect(args['mimeTypes'], [lifetimeReportPdfMimeType]);
          expect(args['paths'], ['${exportDir().path}/$_fileName']);
          expect(args['originX'], 120);
          expect(args['originY'], 900);
          expect(args['originWidth'], 360);
          expect(args['originHeight'], 52);
        },
      );

      test('an empty platform reply is a dismissal', () async {
        reply = '';
        final outcome = await service(
          sharer: const SharePlusLifetimeReportPdfSharer(),
        ).export(document: document, fileName: _fileName);
        expect(outcome, LifetimeReportShareOutcome.dismissed);
      });
    });
  });

  group('AC-9 failures leave nothing behind and share nothing', () {
    test('generation error', () async {
      final sharer = _Sharer();
      await expectLater(
        service(
          sharer: sharer,
          render: (doc, f) async => throw StateError('layout'),
        ).export(document: document, fileName: _fileName),
        throwsA(isA<LifetimeReportExportFailed>()),
      );
      expect(sharer.shares, isEmpty);
      expect(exported(), isEmpty);
    });

    test('storage full while writing', () async {
      final sharer = _Sharer();
      await expectLater(
        service(
          sharer: sharer,
          files: _FailingFiles(),
        ).export(document: document, fileName: _fileName),
        throwsA(isA<LifetimeReportExportFailed>()),
      );
      expect(sharer.shares, isEmpty);
    });

    test('an unwritable export directory', () async {
      // A file where the export directory should be: create fails.
      final blocker = File('${temp.path}/blocked')..writeAsStringSync('x');
      final sharer = _Sharer();
      await expectLater(
        service(
          sharer: sharer,
          files: TemporaryReportPdfFileStore(
            directory: () async => Directory(blocker.path),
          ),
        ).export(document: document, fileName: _fileName),
        throwsA(isA<LifetimeReportExportFailed>()),
      );
      expect(sharer.shares, isEmpty);
    });

    test('a failed share deletes the file', () async {
      final sharer = _Sharer(error: PlatformException(code: 'share'));
      await expectLater(
        service(sharer: sharer).export(document: document, fileName: _fileName),
        throwsA(isA<LifetimeReportExportFailed>()),
      );
      expect(exported(), isEmpty);
    });
  });

  group('AC-12 parent session only', () {
    test('rejects a call outside a parent session before rendering', () async {
      var rendered = false;
      final sharer = _Sharer();
      await expectLater(
        service(
          parent: false,
          sharer: sharer,
          render: (doc, f) async {
            rendered = true;
            return _fakePdf;
          },
        ).export(document: document, fileName: _fileName),
        throwsA(isA<LifetimeReportExportDenied>()),
      );
      expect(rendered, isFalse);
      expect(fonts.loads, 0);
      expect(sharer.shares, isEmpty);
      expect(exported(), isEmpty);
    });

    test('a session check that fails is a denial', () async {
      await expectLater(
        service(
          isParent: () async => throw StateError('profile'),
        ).export(document: document, fileName: _fileName),
        throwsA(isA<LifetimeReportExportDenied>()),
      );
    });

    test('a session locked during generation shares nothing', () async {
      var checks = 0;
      final sharer = _Sharer();
      await expectLater(
        service(
          isParent: () async => checks++ == 0,
          sharer: sharer,
        ).export(document: document, fileName: _fileName),
        throwsA(isA<LifetimeReportExportDenied>()),
      );
      expect(sharer.shares, isEmpty);
      expect(exported(), isEmpty);
    });
  });

  group('bound to the learner on screen', () {
    test(
      'a learner switch during rendering writes and shares nothing',
      () async {
        var active = 'learner-a';
        final gate = Completer<Uint8List>();
        final sharer = _Sharer();
        final running = service(
          currentScope: () => active,
          sharer: sharer,
          render: (doc, f) => gate.future,
        ).export(document: document, fileName: _fileName);
        await pumpEventQueue();
        active = 'learner-b';
        gate.complete(_fakePdf);
        await expectLater(
          running,
          throwsA(isA<LifetimeReportExportSuperseded>()),
        );
        expect(sharer.shares, isEmpty);
        expect(exported(), isEmpty);
      },
    );

    test('a switch after the file is written deletes it unshared', () async {
      var active = 'learner-a';
      final sharer = _Sharer();
      final files = _SwitchingFiles(
        TemporaryReportPdfFileStore(directory: () async => temp),
        onWritten: () => active = 'learner-b',
      );
      await expectLater(
        service(
          currentScope: () => active,
          files: files,
          sharer: sharer,
        ).export(document: document, fileName: _fileName),
        throwsA(isA<LifetimeReportExportSuperseded>()),
      );
      expect(files.written, 1);
      expect(sharer.shares, isEmpty);
      expect(exported(), isEmpty);
    });

    test('a document of another learner is not rendered', () async {
      var rendered = false;
      await expectLater(
        service(
          currentScope: () => 'learner-b',
          render: (doc, f) async {
            rendered = true;
            return _fakePdf;
          },
        ).export(document: document, fileName: _fileName, scope: 'learner-a'),
        throwsA(isA<LifetimeReportExportSuperseded>()),
      );
      expect(rendered, isFalse);
    });

    test('an unresolved or failing learner fails closed', () async {
      await expectLater(
        service(
          currentScope: () => null,
        ).export(document: document, fileName: _fileName),
        throwsA(isA<LifetimeReportExportSuperseded>()),
      );
      await expectLater(
        service(
          currentScope: () => throw StateError('scope'),
        ).export(document: document, fileName: _fileName, scope: 'learner-a'),
        throwsA(isA<LifetimeReportExportSuperseded>()),
      );
      expect(exported(), isEmpty);
    });

    test('the same learner throughout shares normally', () async {
      final sharer = _Sharer();
      final outcome = await service(
        currentScope: () => 'learner-a',
        sharer: sharer,
      ).export(document: document, fileName: _fileName, scope: 'learner-a');
      expect(outcome, LifetimeReportShareOutcome.shared);
      expect(sharer.shares, hasLength(1));
    });
  });

  group('lifetimeReportExportScope', () {
    final scopeA = LearnerScope(
      ownerUid: 'owner',
      profileId: '01HZY5K8Q6T9X3M2N4P7R1S0VA',
    );
    LearnerProfileEntity profile(String id) => LearnerProfileEntity(
      profileId: id,
      displayName: 'Dovid',
      mode: ProfileMode.child,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );

    test('the scope and profile id of a resolved learner', () {
      expect(
        lifetimeReportExportScope(AsyncData(scopeA), AsyncData(profile('p1'))),
        (learner: scopeA, profileId: 'p1'),
      );
      expect(
        lifetimeReportExportScope(AsyncData(scopeA), AsyncData(profile('p1'))),
        isNot(
          lifetimeReportExportScope(
            AsyncData(scopeA),
            AsyncData(profile('p2')),
          ),
        ),
      );
    });

    test('null while the learner re-resolves after a switch, even with '
        'the previous learner retained', () async {
      final next = Completer<LearnerScope?>();
      var reads = 0;
      final learner = FutureProvider<LearnerScope?>(
        (ref) => reads++ == 0 ? scopeA : next.future,
      );
      final c = ProviderContainer();
      addTearDown(c.dispose);
      c.listen(learner, (_, _) {});
      await c.read(learner.future);
      final p = AsyncData<LearnerProfileEntity?>(profile('p1'));
      expect(lifetimeReportExportScope(c.read(learner), p), isNotNull);
      c.invalidate(learner);
      final reresolving = c.read(learner);
      expect(reresolving.value, scopeA);
      expect(lifetimeReportExportScope(reresolving, p), isNull);
      next.complete(scopeA);
    });

    test('null while either side is loading, failed or absent', () {
      final p = AsyncData<LearnerProfileEntity?>(profile('p1'));
      expect(
        lifetimeReportExportScope(const AsyncLoading<LearnerScope?>(), p),
        isNull,
      );
      expect(
        lifetimeReportExportScope(
          AsyncError<LearnerScope?>(StateError('x'), StackTrace.empty),
          p,
        ),
        isNull,
      );
      expect(
        lifetimeReportExportScope(const AsyncData<LearnerScope?>(null), p),
        isNull,
      );
      expect(
        lifetimeReportExportScope(
          AsyncData(scopeA),
          const AsyncData<LearnerProfileEntity?>(null),
        ),
        isNull,
      );
      expect(
        lifetimeReportExportScope(
          AsyncData(scopeA),
          const AsyncLoading<LearnerProfileEntity?>(),
        ),
        isNull,
      );
    });
  });

  group('AC-7 off the UI isolate', () {
    test('the PDF is built on a background isolate', () async {
      final bytes = await renderLifetimeReportPdfInBackground(
        document,
        reportPdfFonts(),
        build: _isolateName,
      );
      expect(utf8.decode(bytes), lifetimeReportPdfIsolateName);
      expect(Isolate.current.debugName, isNot(lifetimeReportPdfIsolateName));
    });

    test('the background render produces the builder\'s PDF', () async {
      final bytes = await renderLifetimeReportPdfInBackground(
        document,
        reportPdfFonts(),
      );
      expect(latin1.decode(bytes.sublist(0, 5)), '%PDF-');
    });

    test('a multi-page report renders within the 3 s budget', () async {
      final large = reportPdfDocument(
        rows: [
          for (var i = 0; i < 600; i++)
            LifetimeReportPdfRow(
              '2024–25 · Ended · ${closeDirection('בית ספר', rtl: false)} '
              '· $i mishnayos',
              indent: i.isOdd ? 1 : 0,
            ),
        ],
      );
      final watch = Stopwatch()..start();
      await renderLifetimeReportPdfInBackground(large, reportPdfFonts());
      watch.stop();
      expect(watch.elapsed, lessThan(const Duration(seconds: 3)));
    }, skip: perfGateSkipReason());
  });

  test('AC-11 exports with no network access', () async {
    final sharer = _Sharer();
    final outcome = await HttpOverrides.runZoned(
      () => service(
        sharer: sharer,
        render: (doc, f) => buildLifetimeReportPdf(doc, f),
      ).export(document: document, fileName: _fileName),
      createHttpClient: (_) => throw StateError('network used'),
    );
    expect(outcome, LifetimeReportShareOutcome.shared);
    expect(latin1.decode(sharer.sharedBytes.single.sublist(0, 5)), '%PDF-');
  });

  group('file name (AC-8)', () {
    test('learning-report-{learner}-{curriculum}-{yyyy-mm-dd}.pdf', () {
      expect(
        lifetimeReportFileName(
          learner: 'Dovid',
          curriculum: 'mishnayos',
          date: '2026-10-03',
        ),
        _fileName,
      );
    });

    test('spaces become hyphens; invalid characters and points go', () {
      expect(
        lifetimeReportFileName(
          learner: '  Dovid  Leib / "Jr"?  ',
          curriculum: 'mishnayos',
          date: '2026-10-03',
        ),
        'learning-report-Dovid-Leib-Jr-mishnayos-2026-10-03.pdf',
      );
      expect(
        lifetimeReportFileName(
          learner: 'דָּוִד',
          curriculum: 'mishnayos',
          date: '2026-10-03',
        ),
        'learning-report-דוד-mishnayos-2026-10-03.pdf',
      );
    });

    test('an empty part falls back; a long one is cut', () {
      expect(
        lifetimeReportFileName(
          learner: ' :/ ',
          curriculum: '',
          date: '2026-10-03',
        ),
        'learning-report-learner-curriculum-2026-10-03.pdf',
      );
      final long = lifetimeReportFileName(
        learner: 'x' * 100,
        curriculum: 'mishnayos',
        date: '2026-10-03',
      );
      expect(long, 'learning-report-${'x' * 40}-mishnayos-2026-10-03.pdf');
    });
  });

  group('export state', () {
    ProviderContainer container(LifetimeReportExportService service) {
      final c = ProviderContainer(
        overrides: [
          lifetimeReportExportServiceProvider.overrideWithValue(service),
        ],
      );
      addTearDown(c.dispose);
      c.listen(lifetimeReportExportProvider, (_, _) {});
      return c;
    }

    test(
      'busy while an export runs; a second tap does not start another',
      () async {
        final gate = Completer<Uint8List>();
        var renders = 0;
        final c = container(
          service(
            render: (doc, f) {
              renders++;
              return gate.future;
            },
          ),
        );
        final notifier = c.read(lifetimeReportExportProvider.notifier);
        final first = notifier.export(document: document, fileName: _fileName);
        await pumpEventQueue();
        expect(c.read(lifetimeReportExportProvider), isTrue);
        expect(
          await notifier.export(document: document, fileName: _fileName),
          LifetimeReportExportResult.ignored,
        );
        gate.complete(_fakePdf);
        expect(await first, LifetimeReportExportResult.shared);
        expect(renders, 1);
        expect(c.read(lifetimeReportExportProvider), isFalse);
      },
    );

    test('a failure ends busy and reports failed', () async {
      final c = container(
        service(render: (doc, f) async => throw StateError('layout')),
      );
      expect(
        await c
            .read(lifetimeReportExportProvider.notifier)
            .export(document: document, fileName: _fileName),
        LifetimeReportExportResult.failed,
      );
      expect(c.read(lifetimeReportExportProvider), isFalse);
    });

    test('outside a parent session reports denied', () async {
      final c = container(service(parent: false));
      expect(
        await c
            .read(lifetimeReportExportProvider.notifier)
            .export(document: document, fileName: _fileName),
        LifetimeReportExportResult.denied,
      );
    });

    test('a learner switch mid-export reports superseded', () async {
      var active = 'learner-a';
      final gate = Completer<Uint8List>();
      final c = container(
        service(currentScope: () => active, render: (doc, f) => gate.future),
      );
      final running = c
          .read(lifetimeReportExportProvider.notifier)
          .export(document: document, fileName: _fileName, scope: 'learner-a');
      await pumpEventQueue();
      active = 'learner-b';
      gate.complete(_fakePdf);
      expect(await running, LifetimeReportExportResult.superseded);
      expect(c.read(lifetimeReportExportProvider), isFalse);
      expect(exported(), isEmpty);
    });

    test('a dismissed sheet reports dismissed', () async {
      final c = container(
        service(sharer: _Sharer(outcome: LifetimeReportShareOutcome.dismissed)),
      );
      expect(
        await c
            .read(lifetimeReportExportProvider.notifier)
            .export(document: document, fileName: _fileName),
        LifetimeReportExportResult.dismissed,
      );
    });
  });
}
