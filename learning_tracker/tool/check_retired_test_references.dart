import 'dart:convert';
import 'dart:io';

const _retiredInventoryDir = 'tool/retired_symbols';
const _retiredInventoryFileCount = 16;
const _testRoots = ['test', 'integration_test', 'functions/test'];

final class RetiredTestReference {
  const RetiredTestReference({
    required this.path,
    required this.line,
    required this.symbol,
  });

  final String path;
  final int line;
  final String symbol;

  @override
  String toString() => '$path:$line: $symbol';
}

/// Loads the exact retired identifiers from the story retirement inventory.
/// Pending cutover-only symbols are intentionally excluded.
Set<String> loadRetiredTestSymbols(Directory root) {
  final symbols = <String>{};
  for (var group = 1; group <= _retiredInventoryFileCount; group++) {
    final file = File('${root.path}/$_retiredInventoryDir/R$group.json');
    if (!file.existsSync()) {
      throw FileSystemException('Missing retired-symbol inventory', file.path);
    }
    final decoded = jsonDecode(file.readAsStringSync());
    if (decoded is! Map<String, dynamic> || decoded['entries'] is! List) {
      throw FormatException('Malformed retired-symbol inventory: ${file.path}');
    }
    for (final entry in decoded['entries'] as List) {
      if (entry is! Map<String, dynamic>) {
        throw FormatException('Malformed inventory entry: ${file.path}');
      }
      if (entry['state'] != 'retired') continue;
      final symbol = entry['symbol'];
      if (symbol is! String || symbol.isEmpty) {
        throw FormatException('Malformed retired symbol: ${file.path}');
      }
      symbols.add(symbol);
    }
  }
  return symbols;
}

/// Scans the three test roots. A missing or empty root has no references.
/// Text files are scanned regardless of extension; binary files are skipped.
List<RetiredTestReference> scanRetiredTestReferences({
  required Directory root,
  required Iterable<String> symbols,
}) {
  final orderedSymbols = symbols.toSet().toList()
    ..sort((a, b) => b.length.compareTo(a.length));
  final patterns = {
    for (final symbol in orderedSymbols) symbol: _symbolPattern(symbol),
  };
  final references = <RetiredTestReference>[];

  for (final relativeRoot in _testRoots) {
    final scanRoot = Directory('${root.path}/$relativeRoot');
    if (!scanRoot.existsSync()) continue;

    for (final entity in scanRoot.listSync(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is! File) continue;
      final bytes = entity.readAsBytesSync();
      final contents = _decodeText(bytes);
      if (contents == null) continue;

      final lines = contents.split('\n');
      for (var lineIndex = 0; lineIndex < lines.length; lineIndex++) {
        for (final symbol in orderedSymbols) {
          for (final _ in patterns[symbol]!.allMatches(lines[lineIndex])) {
            references.add(
              RetiredTestReference(
                path: _relativePath(root, entity.path),
                line: lineIndex + 1,
                symbol: symbol,
              ),
            );
          }
        }
      }
    }
  }

  references.sort((a, b) {
    final pathOrder = a.path.compareTo(b.path);
    if (pathOrder != 0) return pathOrder;
    final lineOrder = a.line.compareTo(b.line);
    if (lineOrder != 0) return lineOrder;
    return a.symbol.compareTo(b.symbol);
  });
  return references;
}

String _relativePath(Directory root, String path) {
  final rootPath = root.absolute.path;
  final absolutePath = File(path).absolute.path;
  if (absolutePath.startsWith('$rootPath${Platform.pathSeparator}')) {
    return absolutePath
        .substring(rootPath.length + 1)
        .replaceAll(Platform.pathSeparator, '/');
  }
  return path.replaceAll(Platform.pathSeparator, '/');
}

String? _decodeText(List<int> bytes) {
  if (bytes.contains(0)) return null;
  try {
    return utf8.decode(bytes);
  } on FormatException {
    return null;
  }
}

RegExp _symbolPattern(String symbol) {
  final startsWithIdentifier = RegExp(r'^[A-Za-z0-9_$]').hasMatch(symbol);
  final endsWithIdentifier = RegExp(r'[A-Za-z0-9_$]$').hasMatch(symbol);
  final left = startsWithIdentifier ? r'(?<![A-Za-z0-9_$])' : '';
  final right = endsWithIdentifier ? r'(?![A-Za-z0-9_$])' : '';
  return RegExp('$left${RegExp.escape(symbol)}$right');
}

void main(List<String> args) {
  if (args.isNotEmpty) {
    stderr.writeln('Usage: dart run tool/check_retired_test_references.dart');
    exitCode = 2;
    return;
  }

  final root = Directory.current;
  try {
    final symbols = loadRetiredTestSymbols(root);
    final references = scanRetiredTestReferences(root: root, symbols: symbols);
    if (references.isEmpty) {
      stdout.writeln(
        'Retired test-reference check passed: no retired symbols in ${_testRoots.join(', ')}.',
      );
      return;
    }
    for (final reference in references) {
      stdout.writeln(reference);
    }
    stdout.writeln(
      'Retired test-reference check failed: ${references.length} reference(s) across ${references.map((e) => e.path).toSet().length} file(s).',
    );
    exitCode = 1;
  } on Object catch (error) {
    stderr.writeln('Retired test-reference check could not run: $error');
    exitCode = 2;
  }
}
