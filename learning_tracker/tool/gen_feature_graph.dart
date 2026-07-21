/// Feature Dependency Graph generator — AUD-docs-15.
///
/// architecture.md's Feature Dependency Graph mermaid diagram used 17 node
/// identifiers, 5 of which don't exist under `lib/features/` (renamed:
/// `auth`->`account`; folded into `tracks/`: `stages`, `parent_mode`,
/// `track_setup`, `learning_order`) while omitting 3 real, substantial
/// features entirely (`sacred_time`, `tutoring`, `tracks`), plus 2 edges
/// running backwards relative to the real import direction. This script
/// derives the node set from `ls lib/features/` and edges from a real grep
/// of cross-feature imports, so the diagram can be regenerated instead of
/// hand-maintained (and can drift-detect via `--check`).
///
/// Edge selection: the real cross-feature import graph is dense (101 edges
/// among 15 nodes as of 2026-07-13 — this app's features are genuinely
/// cross-connected, not a clean layered stack) — rendering every edge would
/// be an illegible hairball, not the "legible abstraction" the AUD-docs-15
/// recommendation calls for. This generator keeps only "significant"
/// dependencies: an edge A->B survives if at least [_minEdgeWeight] distinct
/// files in `lib/features/A/` import from `lib/features/B/` (a one-off
/// supporting import doesn't reflect an architectural dependency the way a
/// dozen files importing the same feature does), PLUS force-includes each
/// node's single heaviest outbound edge if the node would otherwise have NO
/// edges in the filtered graph (keeps low-import-volume-but-real features
/// like `sacred_time` visible rather than silently dropped by the
/// threshold). This is a mechanical, reproducible simplification — not
/// hand-picked — but IS a simplification; regenerate with `--full` to see
/// every edge, or lower `--min-weight` for a denser graph.
///
/// Usage (from `learning_tracker/`):
///   dart run tool/gen_feature_graph.dart                    # mermaid graph, weight>=6 backbone
///   dart run tool/gen_feature_graph.dart --min-weight=N      # custom threshold
///   dart run tool/gen_feature_graph.dart --full              # every edge, no threshold
///   dart run tool/gen_feature_graph.dart --check              # exit 1 if architecture.md's
///                                                              # committed graph's node set
///                                                              # doesn't match `ls lib/features/`
library;

import 'dart:io';

const _minEdgeWeightDefault = 6;

final _importPattern = RegExp(
  "import 'package:learning_tracker/features/([a-zA-Z0-9_]+)/",
);

List<String> _listFeatureNodes() {
  final dir = Directory('lib/features');
  return dir
      .listSync()
      .whereType<Directory>()
      .map((d) => d.path.split('/').last)
      .toList()
    ..sort();
}

/// Returns edge -> number of distinct files in `lib/features/<from>/` that
/// import from `lib/features/<to>/`.
Map<(String, String), int> _computeEdgeWeights(List<String> nodes) {
  final nodeSet = nodes.toSet();
  final weights = <(String, String), int>{};
  for (final feature in nodes) {
    final dir = Directory('lib/features/$feature');
    if (!dir.existsSync()) continue;
    for (final entity in dir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final content = entity.readAsStringSync();
      final targets = <String>{};
      for (final m in _importPattern.allMatches(content)) {
        final target = m.group(1)!;
        if (target != feature && nodeSet.contains(target)) targets.add(target);
      }
      for (final t in targets) {
        final key = (feature, t);
        weights[key] = (weights[key] ?? 0) + 1;
      }
    }
  }
  return weights;
}

String _buildMermaid(
  List<String> nodes,
  Map<(String, String), int> weights,
  int minWeight,
) {
  final kept = {
    for (final e in weights.entries)
      if (e.value >= minWeight) e.key: e.value,
  };

  // Force-include each node's single heaviest outbound edge if it would
  // otherwise be edge-less in the filtered graph (see file doc comment).
  for (final node in nodes) {
    final hasEdge = kept.keys.any((e) => e.$1 == node || e.$2 == node);
    if (hasEdge) continue;
    final outbound = weights.entries.where((e) => e.key.$1 == node).toList();
    if (outbound.isEmpty) continue;
    outbound.sort((a, b) => b.value.compareTo(a.value));
    kept[outbound.first.key] = outbound.first.value;
  }

  final buffer = StringBuffer()
    ..writeln('```mermaid')
    ..writeln('graph TD');
  for (final node in nodes) {
    buffer.writeln('    $node["$node"]');
  }
  buffer.writeln();
  final sortedEdges = kept.entries.toList()
    ..sort((a, b) {
      final byFrom = a.key.$1.compareTo(b.key.$1);
      if (byFrom != 0) return byFrom;
      return a.key.$2.compareTo(b.key.$2);
    });
  for (final e in sortedEdges) {
    buffer.writeln('    ${e.key.$1} --> ${e.key.$2}');
  }
  buffer.writeln('```');
  return buffer.toString();
}

final _mermaidNodePattern = RegExp(
  r'^\s{4}(\w+)\["\w+"\]\s*$',
  multiLine: true,
);

void main(List<String> args) {
  final check = args.contains('--check');
  final full = args.contains('--full');
  var minWeight = _minEdgeWeightDefault;
  for (final a in args) {
    if (a.startsWith('--min-weight=')) {
      minWeight = int.parse(a.substring('--min-weight='.length));
    }
  }
  if (full) minWeight = 1;

  final libFeatures = Directory('lib/features');
  if (!libFeatures.existsSync()) {
    stderr.writeln(
      'ERROR: lib/features not found — run from learning_tracker/',
    );
    exit(2);
  }
  final nodes = _listFeatureNodes();
  final weights = _computeEdgeWeights(nodes);
  final mermaid = _buildMermaid(nodes, weights, minWeight);

  if (check) {
    const archPath = '../docs/architecture.md';
    final archFile = File(archPath);
    if (!archFile.existsSync()) {
      stderr.writeln('ERROR: $archPath not found');
      exit(2);
    }
    final archContent = archFile.readAsStringSync();
    final committedNodes = _mermaidNodePattern
        .allMatches(archContent)
        .map((m) => m.group(1)!)
        .toSet();
    final realNodes = nodes.toSet();
    final missing = realNodes.difference(committedNodes);
    final extra = committedNodes.difference(realNodes);
    if (missing.isNotEmpty || extra.isNotEmpty) {
      stderr.writeln(
        'AUD-docs-15 feature-graph check FAILED: docs/architecture.md\'s '
        'Feature Dependency Graph node set has drifted from `ls lib/features/`.',
      );
      if (missing.isNotEmpty) {
        stderr.writeln(
          '  Missing from the doc (real features, no node): ${missing.join(", ")}',
        );
      }
      if (extra.isNotEmpty) {
        stderr.writeln(
          '  Stale in the doc (no longer a real feature): ${extra.join(", ")}',
        );
      }
      stderr.writeln(
        '\nRun `dart run tool/gen_feature_graph.dart` and update the mermaid '
        'block in docs/architecture.md\'s "Feature Dependency Graph" section.',
      );
      exit(1);
    }
    stdout.writeln(
      'gen-feature-graph check OK: docs/architecture.md\'s graph node set '
      'matches `ls lib/features/` (${nodes.length} nodes).',
    );
    return;
  }

  stdout.writeln(
    '// ${nodes.length} nodes, min-weight=$minWeight '
    '(${weights.length} total edges before filtering)',
  );
  stdout.write(mermaid);
}
