/// Exports the lifetime report as a PDF and hands it to the system share
/// sheet (Story 5.4, DNI-519; AD-48, UX-DR-145).
///
/// [LifetimeReportExportService.export] runs one export:
///
/// 1. It refuses to run outside an unlocked parent session
///    ([LifetimeReportExportDenied], AC-12), and checks again before the
///    file is shared. Each export is bound to the learner whose report it
///    is: if the active learner changes while it runs (a profile switch
///    that keeps a parent session), it stops before writing, or deletes
///    the file before sharing ([LifetimeReportExportSuperseded]), so one
///    learner's report is never shared from another learner's screen.
/// 2. It renders the document on a background isolate
///    ([renderLifetimeReportPdfInBackground], AC-7): the UI isolate only
///    loads the font assets.
/// 3. It writes the bytes to a temporary file under the export's own
///    directory ([TemporaryReportPdfFileStore]): written under a `.part`
///    name and renamed only once complete, so a partial file never carries
///    the report's name; a failed write deletes it (AC-9).
/// 4. It shares the file through `share_plus` as `application/pdf`,
///    anchored to the Export PDF button on iPad (AC-8). A failed share
///    deletes the file too.
///
/// Everything is local: no network call, so an offline device with its
/// events cached exports normally (AC-11). Every step is an injected seam,
/// so tests run the export without a platform channel.
library;

import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:flutter/services.dart' show AssetBundle;
import 'package:learning_tracker/domain/learner_state/civil_date.dart';
import 'package:learning_tracker/features/progress/domain/services/lifetime_report_pdf_builder.dart';
import 'package:learning_tracker/features/progress/domain/services/lifetime_report_pdf_document.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// The MIME type of the shared report.
const lifetimeReportPdfMimeType = 'application/pdf';

/// The export was asked for outside an unlocked parent session (AC-12).
final class LifetimeReportExportDenied implements Exception {
  /// Creates the exception.
  const LifetimeReportExportDenied();

  @override
  String toString() => 'LifetimeReportExportDenied';
}

/// The active learner changed while the export ran, or was not resolved
/// when it started: the report belongs to another learner than the one on
/// screen, so nothing is shared and no file is kept.
final class LifetimeReportExportSuperseded implements Exception {
  /// Creates the exception.
  const LifetimeReportExportSuperseded();

  @override
  String toString() => 'LifetimeReportExportSuperseded';
}

/// Generating, writing or sharing the PDF failed (AC-9). Nothing partial
/// was left behind or shared.
final class LifetimeReportExportFailed implements Exception {
  /// Creates the exception for [cause].
  const LifetimeReportExportFailed(this.cause);

  /// What failed.
  final Object cause;

  @override
  String toString() => 'LifetimeReportExportFailed($cause)';
}

/// How the share sheet closed.
enum LifetimeReportShareOutcome {
  /// The parent picked a share target.
  shared,

  /// The parent dismissed the sheet: back to the report, no error.
  dismissed,

  /// The platform could not say (Android before a target is chosen).
  unavailable,
}

/// Renders [document] in [fonts] to PDF bytes.
typedef LifetimeReportPdfRenderer =
    Future<Uint8List> Function(
      LifetimeReportPdfDocument document,
      LifetimeReportPdfFonts fonts,
    );

/// The name of the isolate the PDF is rendered on.
const lifetimeReportPdfIsolateName = 'lifetime-report-pdf';

/// The production renderer: [build] (the PDF builder) on a background
/// isolate, so the UI isolate keeps drawing frames while the PDF is laid
/// out (AC-7). [build] must be a top-level or static function.
Future<Uint8List> renderLifetimeReportPdfInBackground(
  LifetimeReportPdfDocument document,
  LifetimeReportPdfFonts fonts, {
  LifetimeReportPdfRenderer build = _buildPdf,
}) => Isolate.run(
  () => build(document, fonts),
  debugName: lifetimeReportPdfIsolateName,
);

Future<Uint8List> _buildPdf(
  LifetimeReportPdfDocument document,
  LifetimeReportPdfFonts fonts,
) => buildLifetimeReportPdf(document, fonts);

/// Supplies the embedded font files.
abstract interface class LifetimeReportPdfFontSource {
  /// The four faces.
  Future<LifetimeReportPdfFonts> load();
}

/// Reads the faces from the app's asset bundle (`assets/fonts/`).
final class AssetLifetimeReportPdfFontSource
    implements LifetimeReportPdfFontSource {
  /// Creates the source over [bundle].
  const AssetLifetimeReportPdfFontSource(this.bundle);

  /// The asset bundle.
  final AssetBundle bundle;

  @override
  Future<LifetimeReportPdfFonts> load() async {
    Future<Uint8List> read(String path) async =>
        Uint8List.sublistView(await bundle.load(path));
    const paths = LifetimeReportPdfFonts.assetPaths;
    final (latin, latinBold, hebrew, hebrewBold) = await (
      read(paths.latinRegular),
      read(paths.latinBold),
      read(paths.hebrewRegular),
      read(paths.hebrewBold),
    ).wait;
    return LifetimeReportPdfFonts(
      latinRegular: latin,
      latinBold: latinBold,
      hebrewRegular: hebrew,
      hebrewBold: hebrewBold,
    );
  }
}

/// Where the PDF file is written before it is shared.
abstract interface class LifetimeReportPdfFileStore {
  /// Writes [bytes] to a new file named [fileName] and returns its path.
  /// On failure no file (complete or partial) is left behind.
  Future<String> write(String fileName, Uint8List bytes);

  /// Deletes the file at [path], if it exists.
  Future<void> delete(String path);
}

/// Writes exports under `<temporary directory>/lifetime_report_exports/`.
///
/// A shared file stays until the next export (the share target may still
/// be reading it after the sheet closes); each export first clears the
/// directory, so at most one report file is ever kept.
final class TemporaryReportPdfFileStore implements LifetimeReportPdfFileStore {
  /// Creates the store; [directory] resolves the base directory (the
  /// platform temporary directory by default).
  TemporaryReportPdfFileStore({Future<Directory> Function()? directory})
    : _directory = directory ?? getTemporaryDirectory;

  final Future<Directory> Function() _directory;

  /// The export directory's name under the base directory.
  static const folder = 'lifetime_report_exports';

  @override
  Future<String> write(String fileName, Uint8List bytes) async {
    final base = await _directory();
    final dir = Directory('${base.path}${Platform.pathSeparator}$folder');
    if (dir.existsSync()) {
      await dir.delete(recursive: true);
    }
    await dir.create(recursive: true);
    final target = File('${dir.path}${Platform.pathSeparator}$fileName');
    final part = File('${target.path}.part');
    try {
      await part.writeAsBytes(bytes, flush: true);
      await part.rename(target.path);
      return target.path;
    } on Object {
      await _deleteQuietly(part);
      await _deleteQuietly(target);
      rethrow;
    }
  }

  @override
  Future<void> delete(String path) => _deleteQuietly(File(path));

  static Future<void> _deleteQuietly(File file) async {
    try {
      if (file.existsSync()) await file.delete();
    } on FileSystemException {
      // Already gone, or the directory went with the temp dir.
    }
  }
}

/// Opens the system share sheet for one PDF file.
abstract interface class LifetimeReportPdfSharer {
  /// Shares the file at [path] as [fileName], anchored at [origin] (the
  /// Export PDF button's global bounds; required on iPad).
  Future<LifetimeReportShareOutcome> share({
    required String path,
    required String fileName,
    Rect? origin,
    String? subject,
  });
}

/// The `share_plus` share sheet.
final class SharePlusLifetimeReportPdfSharer
    implements LifetimeReportPdfSharer {
  /// Creates the sharer.
  const SharePlusLifetimeReportPdfSharer();

  @override
  Future<LifetimeReportShareOutcome> share({
    required String path,
    required String fileName,
    Rect? origin,
    String? subject,
  }) async {
    final result = await SharePlus.instance.share(
      ShareParams(
        files: [XFile(path, mimeType: lifetimeReportPdfMimeType)],
        fileNameOverrides: [fileName],
        subject: subject,
        sharePositionOrigin: origin,
      ),
    );
    return switch (result.status) {
      ShareResultStatus.success => LifetimeReportShareOutcome.shared,
      ShareResultStatus.dismissed => LifetimeReportShareOutcome.dismissed,
      ShareResultStatus.unavailable => LifetimeReportShareOutcome.unavailable,
    };
  }
}

/// Runs report exports.
final class LifetimeReportExportService {
  /// Creates the service.
  ///
  /// [isParentSession] answers, fail closed, whether the session is an
  /// unlocked parent session right now. [currentScope] is the identity of
  /// the active learner right now (compared with `==`), or null while it
  /// is not resolved.
  LifetimeReportExportService({
    required Future<bool> Function() isParentSession,
    required Object? Function() currentScope,
    required LifetimeReportPdfFontSource fonts,
    required LifetimeReportPdfFileStore files,
    required LifetimeReportPdfSharer sharer,
    LifetimeReportPdfRenderer render = renderLifetimeReportPdfInBackground,
  }) : _isParentSession = isParentSession,
       _currentScope = currentScope,
       _fonts = fonts,
       _files = files,
       _sharer = sharer,
       _render = render;

  final Future<bool> Function() _isParentSession;
  final Object? Function() _currentScope;
  final LifetimeReportPdfFontSource _fonts;
  final LifetimeReportPdfFileStore _files;
  final LifetimeReportPdfSharer _sharer;
  final LifetimeReportPdfRenderer _render;

  /// Exports [document] as [fileName] and opens the share sheet anchored
  /// at [origin].
  ///
  /// The export is bound to [scope], the identity of the learner whose
  /// report [document] is (as [currentScope] gives it, taken when the
  /// document was composed); without one it is bound to the learner
  /// active when this is called.
  ///
  /// Throws [LifetimeReportExportDenied] outside a parent session (nothing
  /// is generated); [LifetimeReportExportSuperseded] when the bound learner
  /// is unresolved or is no longer the active one, checked after rendering
  /// and again just before sharing (nothing is shared; a written file is
  /// deleted); and [LifetimeReportExportFailed] when generation, the file
  /// write or the share fails (the file is deleted; nothing partial is
  /// shared).
  Future<LifetimeReportShareOutcome> export({
    required LifetimeReportPdfDocument document,
    required String fileName,
    Rect? origin,
    Object? scope,
  }) async {
    // Bound before the first await, so it is the learner of [document].
    final bound = scope ?? _currentScope();
    await _requireParent();
    _requireScope(bound);
    final Uint8List bytes;
    try {
      bytes = await _render(document, await _fonts.load());
    } on Object catch (e, st) {
      Error.throwWithStackTrace(LifetimeReportExportFailed(e), st);
    }
    // The learner may have changed while the PDF was rendered.
    _requireScope(bound);
    final String path;
    try {
      path = await _files.write(fileName, bytes);
    } on Object catch (e, st) {
      Error.throwWithStackTrace(LifetimeReportExportFailed(e), st);
    }
    try {
      // The session may have locked, or the learner changed, while the
      // PDF was generated or written.
      await _requireParent();
      _requireScope(bound);
      return await _sharer.share(
        path: path,
        fileName: fileName,
        origin: origin,
        subject: stripHebrewMarks(document.title),
      );
    } on LifetimeReportExportDenied {
      await _files.delete(path);
      rethrow;
    } on LifetimeReportExportSuperseded {
      await _files.delete(path);
      rethrow;
    } on Object catch (e, st) {
      await _files.delete(path);
      Error.throwWithStackTrace(LifetimeReportExportFailed(e), st);
    }
  }

  Future<void> _requireParent() async {
    final bool parent;
    try {
      parent = await _isParentSession();
    } on Object {
      throw const LifetimeReportExportDenied();
    }
    if (!parent) throw const LifetimeReportExportDenied();
  }

  /// Throws [LifetimeReportExportSuperseded] unless [bound] is resolved
  /// and is still the active learner (fail closed: a learner re-resolving
  /// is not the same one).
  void _requireScope(Object? bound) {
    final Object? current;
    try {
      current = _currentScope();
    } on Object {
      throw const LifetimeReportExportSuperseded();
    }
    if (bound == null || current != bound) {
      throw const LifetimeReportExportSuperseded();
    }
  }
}

/// The share file name `learning-report-{learner}-{curriculum}-{date}.pdf`
/// (AC-8).
///
/// [ASSUMPTION] Name parts keep their letters (Hebrew included, points
/// stripped) and case; characters no file system accepts (`\ / : * ? " <
/// > |`, controls, direction marks) are removed, runs of whitespace become
/// one hyphen, and a part is cut to 40 characters. An empty learner or
/// curriculum part falls back to `learner` / `curriculum`.
String lifetimeReportFileName({
  required String learner,
  required String curriculum,
  required CivilDate date,
}) =>
    'learning-report-${_fileNamePart(learner, 'learner')}-'
    '${_fileNamePart(curriculum, 'curriculum')}-$date.pdf';

final RegExp _invalidFileNameChars = RegExp(
  r'[\\/:*?"<>|\x00-\x1F\x7F'
  r'\u200E\u200F\u202A-\u202E]',
);

String _fileNamePart(String raw, String fallback) {
  final cleaned = stripHebrewMarks(raw)
      .replaceAll(_invalidFileNameChars, '')
      .trim()
      .replaceAll(RegExp(r'\s+'), '-')
      .replaceAll(RegExp('-{2,}'), '-')
      .replaceAll(RegExp(r'^[-.]+|[-.]+$'), '');
  if (cleaned.isEmpty) return fallback;
  final runes = cleaned.runes.toList();
  return runes.length <= 40 ? cleaned : String.fromCharCodes(runes.take(40));
}
