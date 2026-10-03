/// Reads text back out of an uncompressed PDF written by the `pdf` package
/// (Story 5.4, DNI-519 tests).
///
/// It understands exactly what `pdf` writes for `buildLifetimeReportPdf(
/// compress: false)`: Type0/Identity-H fonts with a `/ToUnicode` CMap and
/// a `/W` width array, page content streams of `q … cm … Q` transforms and
/// `BT /Fn size Tf x y Td [<hex>]TJ ET` text objects. Each drawn run is
/// mapped back to Unicode through its font's CMap and placed with the
/// transform in force, so tests can read lines in visual order (left to
/// right, top to bottom) exactly as a viewer would paint them.
library;

import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

/// One drawn text run.
final class PdfTextRun {
  PdfTextRun({
    required this.text,
    required this.x,
    required this.y,
    required this.width,
    required this.size,
    required this.font,
  });

  /// The run's characters, in drawing order (visual, left to right).
  final String text;

  /// Left edge, in page units.
  final double x;

  /// Baseline, in page units (origin at the bottom).
  final double y;

  /// Advance width of the run.
  final double width;

  /// Font size.
  final double size;

  /// The font's `/BaseFont` name.
  final String font;

  @override
  String toString() =>
      'Run("$text" @${x.toStringAsFixed(1)},'
      '${y.toStringAsFixed(1)} $font)';
}

/// One visual line: runs on one baseline, left to right.
final class PdfTextLine {
  PdfTextLine(this.runs);

  /// The runs, sorted by x.
  final List<PdfTextRun> runs;

  /// The baseline.
  double get y => runs.first.y;

  /// The line's text in visual order; runs separated by a gap wider than
  /// a fifth of the font size are joined with a space.
  String get text {
    final out = StringBuffer();
    PdfTextRun? previous;
    for (final run in runs) {
      if (previous != null &&
          run.x - (previous.x + previous.width) > previous.size * 0.2) {
        out.write(' ');
      }
      out.write(run.text);
      previous = run;
    }
    return out.toString();
  }

  @override
  String toString() => 'Line($text)';
}

/// One embedded font.
final class PdfFontInfo {
  PdfFontInfo({
    required this.baseFont,
    required this.subtype,
    required this.embeddedLength,
  });

  /// `/BaseFont`.
  final String baseFont;

  /// `/Subtype` (`/Type0`, `/Type1`, `/TrueType`).
  final String subtype;

  /// The uncompressed length of the embedded `/FontFile2`, or null when
  /// the font is not embedded.
  final int? embeddedLength;
}

/// The text and fonts of a PDF.
final class PdfTextDocument {
  PdfTextDocument._(this.pages, this.fonts);

  /// Parses [bytes] (an uncompressed `pdf` package file).
  factory PdfTextDocument.parse(Uint8List bytes) {
    final source = latin1.decode(bytes);
    final objects = <int, String>{
      for (final m in RegExp(
        r'(\d+) 0 obj(.*?)endobj',
        dotAll: true,
      ).allMatches(source))
        int.parse(m.group(1)!): m.group(2)!,
    };
    String stream(int id) {
      final body = objects[id]!;
      final start = body.indexOf('stream') + 'stream'.length;
      final end = body.lastIndexOf('endstream');
      return body.substring(start, end).trim();
    }

    int? ref(String body, String key) {
      final m = RegExp('/$key (\\d+) 0 R').firstMatch(body);
      return m == null ? null : int.parse(m.group(1)!);
    }

    // Fonts by object id.
    final fonts = <int, _Font>{};
    final infos = <PdfFontInfo>[];
    for (final MapEntry(:key, :value) in objects.entries) {
      final head = value.split('stream').first;
      if (!head.contains('/Type/Font') || head.contains('/FontDescriptor/')) {
        continue;
      }
      if (RegExp(r'^\s*<</Type/Font/BaseFont').hasMatch(head)) continue;
      final subtype = RegExp(r'/Subtype(/\w+)').firstMatch(head)!.group(1)!;
      final base = RegExp(r'/BaseFont/([\w+-]+)').firstMatch(head)!.group(1)!;
      final fileId = ref(head, 'FontFile2');
      final length = fileId == null
          ? null
          : int.parse(
              RegExp(r'/Length1 (\d+)').firstMatch(objects[fileId]!)!.group(1)!,
            );
      infos.add(
        PdfFontInfo(baseFont: base, subtype: subtype, embeddedLength: length),
      );
      final cmapId = ref(head, 'ToUnicode');
      final cmap = <int, int>{};
      if (cmapId != null) {
        for (final m in RegExp(
          '<([0-9A-Fa-f]{4})> <([0-9A-Fa-f]{4,8})>',
        ).allMatches(stream(cmapId))) {
          cmap[int.parse(m.group(1)!, radix: 16)] = int.parse(
            m.group(2)!,
            radix: 16,
          );
        }
      }
      final widths = <double>[];
      final wRef = RegExp(r'/W\[0 (\d+) 0 R\]').firstMatch(head);
      if (wRef != null) {
        final array = objects[int.parse(wRef.group(1)!)]!;
        widths.addAll(
          RegExp(
            r'-?\d+(\.\d+)?',
          ).allMatches(array).map((m) => double.parse(m.group(0)!)),
        );
      }
      fonts[key] = _Font(base, cmap, widths);
    }

    // Pages in /Kids order.
    final pagesRoot = objects.values.firstWhere(
      (o) => o.contains('/Type/Pages'),
    );
    final kids = RegExp(r'(\d+) 0 R')
        .allMatches(
          RegExp(r'/Kids\[([^\]]*)\]').firstMatch(pagesRoot)!.group(1)!,
        )
        .map((m) => int.parse(m.group(1)!))
        .toList();
    final pages = <List<PdfTextLine>>[];
    for (final pageId in kids) {
      final page = objects[pageId]!;
      final fontNames = <String, int>{
        for (final m in RegExp(r'/(F\d+) (\d+) 0 R').allMatches(page))
          m.group(1)!: int.parse(m.group(2)!),
      };
      final runs = _runs(stream(ref(page, 'Contents')!), (name) {
        return fonts[fontNames[name]]!;
      });
      pages.add(_lines(runs));
    }
    return PdfTextDocument._(pages, infos);
  }

  /// Each page's lines, top to bottom.
  final List<List<PdfTextLine>> pages;

  /// Every font object in the file.
  final List<PdfFontInfo> fonts;

  /// Every line of every page, in reading order.
  Iterable<PdfTextLine> get lines => pages.expand((p) => p);

  /// The whole text: lines joined with newlines.
  String get text => lines.map((l) => l.text).join('\n');

  static List<PdfTextLine> _lines(List<PdfTextRun> runs) {
    final byY = <int, List<PdfTextRun>>{};
    for (final run in runs) {
      // Runs on one baseline (to a tenth of a point).
      byY.putIfAbsent((run.y * 10).round(), () => []).add(run);
    }
    final keys = byY.keys.toList()..sort((a, b) => b.compareTo(a));
    return [
      for (final k in keys)
        PdfTextLine(byY[k]!..sort((a, b) => a.x.compareTo(b.x))),
    ];
  }

  static List<PdfTextRun> _runs(
    String content,
    _Font Function(String name) fontNamed,
  ) {
    final tokens = RegExp(
      r'\[[^\]]*\]|<[0-9A-Fa-f]*>|/[A-Za-z0-9]+|-?\d*\.?\d+|[A-Za-z*\x27"]+',
    ).allMatches(content).map((m) => m.group(0)!).toList();
    final stack = <List<double>>[];
    var ctm = <double>[1, 0, 0, 1, 0, 0];
    final operands = <String>[];
    _Font? font;
    var size = 0.0;
    var tx = 0.0;
    var ty = 0.0;
    final runs = <PdfTextRun>[];

    List<double> multiply(List<double> m, List<double> n) => [
      m[0] * n[0] + m[1] * n[2],
      m[0] * n[1] + m[1] * n[3],
      m[2] * n[0] + m[3] * n[2],
      m[2] * n[1] + m[3] * n[3],
      m[4] * n[0] + m[5] * n[2] + n[4],
      m[4] * n[1] + m[5] * n[3] + n[5],
    ];

    void show(String array) {
      final f = font!;
      final codes = <int>[];
      for (final m in RegExp('<([0-9A-Fa-f]*)>').allMatches(array)) {
        final hex = m.group(1)!;
        for (var i = 0; i + 4 <= hex.length; i += 4) {
          codes.add(int.parse(hex.substring(i, i + 4), radix: 16));
        }
      }
      if (codes.isEmpty) return;
      final text = String.fromCharCodes(codes.map((c) => f.cmap[c] ?? 0xFFFD));
      final advance = codes.fold<double>(
        0,
        (sum, c) => sum + (c < f.widths.length ? f.widths[c] : 0),
      );
      final x = ctm[0] * tx + ctm[2] * ty + ctm[4];
      final y = ctm[1] * tx + ctm[3] * ty + ctm[5];
      runs.add(
        PdfTextRun(
          text: text,
          x: x,
          y: y,
          width: advance / 1000 * size * math.sqrt(ctm[0] * ctm[0]),
          size: size,
          font: f.baseFont,
        ),
      );
    }

    final number = RegExp(r'^-?\d*\.?\d+$');
    for (final token in tokens) {
      final operand =
          token.startsWith('[') ||
          token.startsWith('<') ||
          token.startsWith('/') ||
          number.hasMatch(token);
      if (operand) {
        operands.add(token);
        continue;
      }
      switch (token) {
        case 'q':
          stack.add(ctm);
        case 'Q':
          ctm = stack.removeLast();
        case 'cm':
          final n = operands.map(double.parse).toList();
          ctm = multiply(n, ctm);
        case 'BT':
          tx = 0;
          ty = 0;
        case 'Tf':
          font = fontNamed(operands[0].substring(1));
          size = double.parse(operands[1]);
        case 'Td':
          tx += double.parse(operands[0]);
          ty += double.parse(operands[1]);
        case 'TJ' || 'Tj':
          show(operands.last);
      }
      operands.clear();
    }
    return runs;
  }
}

final class _Font {
  _Font(this.baseFont, this.cmap, this.widths);

  final String baseFont;
  final Map<int, int> cmap;
  final List<double> widths;
}
