// Merge gate for Story 2.7 (DNI-498) AC-1 and the AC-9 tablet split:
// *+ Add ground* and the tablet picker pane must have a production host.
//
// Story 2.6's sub-track detail (DNI-497, `SubTrackDetailScreen`) is that
// host, and it is not on integ/sub-tracks yet (rulings: the
// track_management_body + sub_track_detail_screen hotspot merges 497 before
// 498). Until it lands this test is skipped. The moment a
// `SubTrackDetailScreen` exists in `lib/`, it fails unless production code
// outside `add_ground_entry.dart` builds both [AddGroundButton] and
// [GroundPickerSplitView], so the integ full suite cannot go green with the
// picker unreachable from the detail (bead learning-tracker-fyh.228).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _entryFile =
    'lib/features/sub_tracks/presentation/widgets/'
    'add_ground_entry.dart';

List<File> _libDartFiles() => Directory('lib')
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'))
    .where((f) => !f.path.endsWith('.g.dart') && !f.path.endsWith('.gr.dart'))
    .toList();

bool _hasDetailScreen(List<File> files) => files.any(
  (f) => RegExp(
    r'\bclass\s+SubTrackDetailScreen\b',
  ).hasMatch(f.readAsStringSync()),
);

List<String> _constructors(List<File> files, String widget) => [
  for (final f in files)
    if (f.path.replaceAll(r'\', '/') != _entryFile &&
        RegExp('\\b(const\\s+)?$widget\\(').hasMatch(f.readAsStringSync()))
      f.path,
];

void main() {
  final files = _libDartFiles();
  final detailLanded = _hasDetailScreen(files);
  final skip = detailLanded
      ? false
      : 'DNI-497 SubTrackDetailScreen is not on this branch yet; wiring is '
            'tracked by learning-tracker-fyh.228';

  test('the entry file still defines both widgets the detail must host', () {
    final source = File(_entryFile).readAsStringSync();
    expect(source, contains('class AddGroundButton '));
    expect(source, contains('class GroundPickerSplitView '));
  });

  test('the sub-track detail hosts + Add ground (AC-1)', () {
    expect(
      _constructors(files, 'AddGroundButton'),
      isNotEmpty,
      reason:
          'SubTrackDetailScreen exists but no production code builds '
          'AddGroundButton: the ground picker is unreachable (fyh.228).',
    );
  }, skip: skip);

  test('the sub-track detail hosts the tablet picker pane (AC-9)', () {
    expect(
      _constructors(files, 'GroundPickerSplitView'),
      isNotEmpty,
      reason:
          'SubTrackDetailScreen exists but no production code builds '
          'GroundPickerSplitView: the >=840dp split is unreachable (fyh.228).',
    );
  }, skip: skip);
}
