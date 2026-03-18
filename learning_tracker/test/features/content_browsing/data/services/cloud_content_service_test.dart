@Tags(['story_15_13'])
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/content_browsing/data/services/cloud_content_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class MockFirebaseStorage extends Mock implements FirebaseStorage {}

class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

class MockReference extends Mock implements Reference {}

class MockCollectionReference extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

class MockDocumentReference extends Mock
    implements DocumentReference<Map<String, dynamic>> {}

class MockDocumentSnapshot extends Mock
    implements DocumentSnapshot<Map<String, dynamic>> {}

void main() {
  late MockFirebaseStorage mockStorage;
  late MockFirebaseFirestore mockFirestore;
  late CloudContentService service;

  setUp(() {
    mockStorage = MockFirebaseStorage();
    mockFirestore = MockFirebaseFirestore();
    service = CloudContentService(
      storage: mockStorage,
      firestore: mockFirestore,
    );
  });

  group('CloudContentService', () {
    group('downloadContent', () {
      test('emits completed state on successful download', () async {
        final mockRef = MockReference();
        when(() => mockStorage.ref(any())).thenReturn(mockRef);
        when(() => mockRef.getData()).thenAnswer(
          (_) async => Uint8List.fromList(utf8.encode('{"test": true}')),
        );

        final states = <ContentDownloadState>[];
        await for (final progress in service.downloadContent(
          curriculum: CurriculumId.bavli,
          languageCode: 'he',
        )) {
          states.add(progress.state);
        }

        expect(states, contains(ContentDownloadState.completed));
      });

      test('emits failed state when no data', () async {
        final mockRef = MockReference();
        when(() => mockStorage.ref(any())).thenReturn(mockRef);
        when(() => mockRef.getData()).thenAnswer((_) async => null);

        final states = <ContentDownloadState>[];
        await for (final progress in service.downloadContent(
          curriculum: CurriculumId.bavli,
          languageCode: 'he',
        )) {
          states.add(progress.state);
        }

        expect(states.last, ContentDownloadState.failed);
      });

      test('emits failed state on exception', () async {
        final mockRef = MockReference();
        when(() => mockStorage.ref(any())).thenReturn(mockRef);
        when(() => mockRef.getData()).thenThrow(Exception('network error'));

        final states = <ContentDownloadState>[];
        await for (final progress in service.downloadContent(
          curriculum: CurriculumId.bavli,
          languageCode: 'he',
        )) {
          states.add(progress.state);
        }

        expect(states.last, ContentDownloadState.failed);
      });
    });

    group('parseContent', () {
      test('parses valid JSON blob into items and config', () async {
        final mockRef = MockReference();
        when(() => mockStorage.ref(any())).thenReturn(mockRef);

        final blob = {
          'hierarchyConfig': {
            'curriculumId': 'bavli',
            'levelLabels': ['Masechta', 'Daf', 'Amud'],
            'totalItems': 1,
          },
          'items': [
            {
              'curriculumId': 'bavli',
              'level1': 'Berakhot',
              'level2': '2a',
              'level3': null,
              'level4': null,
              'displayNameHe': 'ברכות ב.',
              'displayNameEn': 'Berakhot 2a',
              'sefariaRef': 'Berakhot 2a',
              'sortOrder': 0,
              'isLeaf': true,
            },
          ],
        };

        when(() => mockRef.getData()).thenAnswer(
          (_) async => Uint8List.fromList(utf8.encode(jsonEncode(blob))),
        );

        final result = await service.parseContent(
          curriculum: CurriculumId.bavli,
          languageCode: 'he',
        );

        expect(result.items, hasLength(1));
        expect(result.items.first.sefariaRef, 'Berakhot 2a');
        expect(result.config.curriculumId, 'bavli');
        expect(result.config.levelLabels, ['Masechta', 'Daf', 'Amud']);
      });

      test('throws on null data', () async {
        final mockRef = MockReference();
        when(() => mockStorage.ref(any())).thenReturn(mockRef);
        when(() => mockRef.getData()).thenAnswer((_) async => null);

        expect(
          () => service.parseContent(
            curriculum: CurriculumId.bavli,
            languageCode: 'he',
          ),
          throwsA(isA<ContentDownloadException>()),
        );
      });
    });

    group('getContentVersion', () {
      test('returns null when document does not exist', () async {
        final mockCollection = MockCollectionReference();
        final mockDoc = MockDocumentReference();
        final mockSnapshot = MockDocumentSnapshot();

        when(() => mockFirestore.collection('content_versions'))
            .thenReturn(mockCollection);
        when(() => mockCollection.doc(any())).thenReturn(mockDoc);
        when(() => mockDoc.get()).thenAnswer((_) async => mockSnapshot);
        when(() => mockSnapshot.exists).thenReturn(false);
        when(() => mockSnapshot.data()).thenReturn(null);

        final result = await service.getContentVersion(CurriculumId.bavli);
        expect(result, isNull);
      });
    });

    group('checkForUpdates', () {
      test('returns curricula with different versions', () async {
        final mockCollection = MockCollectionReference();
        final mockDoc = MockDocumentReference();
        final mockSnapshot = MockDocumentSnapshot();

        when(() => mockFirestore.collection('content_versions'))
            .thenReturn(mockCollection);
        when(() => mockCollection.doc(any())).thenReturn(mockDoc);
        when(() => mockDoc.get()).thenAnswer((_) async => mockSnapshot);
        when(() => mockSnapshot.exists).thenReturn(true);
        when(() => mockSnapshot.data()).thenReturn({
          'version': '2.0',
          'updated_at': Timestamp.now(),
          'size_bytes': 1000,
          'languages': <String>['he', 'en'],
        });

        final updates = await service.checkForUpdates(
          [CurriculumId.bavli],
          {'bavli': '1.0'},
        );

        expect(updates, [CurriculumId.bavli]);
      });

      test('returns empty when versions match', () async {
        final mockCollection = MockCollectionReference();
        final mockDoc = MockDocumentReference();
        final mockSnapshot = MockDocumentSnapshot();

        when(() => mockFirestore.collection('content_versions'))
            .thenReturn(mockCollection);
        when(() => mockCollection.doc(any())).thenReturn(mockDoc);
        when(() => mockDoc.get()).thenAnswer((_) async => mockSnapshot);
        when(() => mockSnapshot.exists).thenReturn(true);
        when(() => mockSnapshot.data()).thenReturn({
          'version': '1.0',
          'updated_at': Timestamp.now(),
          'size_bytes': 1000,
          'languages': <String>['he'],
        });

        final updates = await service.checkForUpdates(
          [CurriculumId.bavli],
          {'bavli': '1.0'},
        );

        expect(updates, isEmpty);
      });
    });
  });

  group('ContentDownloadProgress', () {
    test('progress is 0 when not downloading', () {
      const p = ContentDownloadProgress(
        state: ContentDownloadState.notStarted,
      );
      expect(p.progress, 0.0);
    });

    test('progress is 1 when completed', () {
      const p = ContentDownloadProgress(
        state: ContentDownloadState.completed,
      );
      expect(p.progress, 1.0);
    });

    test('progress reflects bytes transferred during download', () {
      const p = ContentDownloadProgress(
        state: ContentDownloadState.downloading,
        bytesTransferred: 50,
        totalBytes: 100,
      );
      expect(p.progress, 0.5);
    });
  });

  group('ContentVersionInfo', () {
    test('fromFirestore handles null fields gracefully', () {
      final info = ContentVersionInfo.fromFirestore({});
      expect(info.version, '0');
      expect(info.sizeBytes, 0);
      expect(info.languages, isEmpty);
    });

    test('fromFirestore parses complete data', () {
      final info = ContentVersionInfo.fromFirestore({
        'version': '2.1',
        'updated_at': Timestamp.fromDate(DateTime(2026, 1, 1)),
        'size_bytes': 5000,
        'languages': ['he', 'en', 'fr'],
      });
      expect(info.version, '2.1');
      expect(info.sizeBytes, 5000);
      expect(info.languages, ['he', 'en', 'fr']);
    });
  });
}
