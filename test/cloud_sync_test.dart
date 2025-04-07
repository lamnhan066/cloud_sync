import 'dart:async';

import 'package:cloud_sync/cloud_sync.dart';
import 'package:test/test.dart';

class MockData {
  final String content;

  MockData(this.content);

  Map<String, dynamic> toMap() {
    return {'content': content};
  }

  factory MockData.fromMap(Map<String, dynamic> map) {
    return MockData(map['content']);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MockData &&
          runtimeType == other.runtimeType &&
          content == other.content;

  @override
  int get hashCode => content.hashCode;
}

class MockSyncAdapter extends SyncAdapter<SyncMetadata, MockData> {
  final Map<String, MockData> _data = {};
  final Map<String, SyncMetadata> _metadata = {};
  bool throwErrorOnFetchMetadata = false;
  bool throwErrorOnFetchDetail = false;
  bool throwErrorOnSave = false;

  @override
  Future<List<SyncMetadata>> fetchMetadataList() async {
    if (throwErrorOnFetchMetadata) {
      throw Exception('Fetch Metadata Error');
    }
    return _metadata.values.toList();
  }

  @override
  Future<MockData> fetchDetail(SyncMetadata metadata) async {
    if (throwErrorOnFetchDetail) {
      throw Exception('Fetch Detail Error');
    }
    return _data[metadata.id]!;
  }

  @override
  Future<void> save(SyncMetadata metadata, MockData detail) async {
    if (throwErrorOnSave) {
      throw Exception('Save Error');
    }
    _metadata[metadata.id] = metadata;
    _data[metadata.id] = detail;
  }
}

void main() {
  group('CloudSync Tests', () {
    late MockSyncAdapter localAdapter;
    late MockSyncAdapter cloudAdapter;
    late CloudSync<SyncMetadata, MockData> cloudSync;
    List<SyncState<SyncMetadata>> progressStates = [];

    setUp(() {
      localAdapter = MockSyncAdapter();
      cloudAdapter = MockSyncAdapter();
      cloudSync = CloudSync.fromAdapters(localAdapter, cloudAdapter);
      progressStates.clear();
    });

    void progressCallback(SyncState<SyncMetadata> state) {
      progressStates.add(state);
    }

    test('Sync completes successfully with no changes', () async {
      await cloudSync.sync(progressCallback: progressCallback);
      expect(progressStates.last, isA<SyncCompleted>());
    });

    test('Sync uploads new local file', () async {
      final localMetadata = SyncMetadata(id: '1', modifiedAt: DateTime.now());
      final localData = MockData('Local Data');
      await localAdapter.save(localMetadata, localData);

      await cloudSync.sync(progressCallback: progressCallback);

      expect(cloudAdapter._data['1'], equals(localData));
      expect(progressStates.any((state) => state is SavedToCloud), isTrue);
    });

    test('Sync downloads new cloud file', () async {
      final cloudMetadata = SyncMetadata(id: '2', modifiedAt: DateTime.now());
      final cloudData = MockData('Cloud Data');
      await cloudAdapter.save(cloudMetadata, cloudData);

      await cloudSync.sync(progressCallback: progressCallback);

      expect(localAdapter._data['2'], equals(cloudData));
      expect(progressStates.any((state) => state is SavedToLocal), isTrue);
    });

    test('Sync uploads updated local file', () async {
      final id = '3';
      final initialTime = DateTime.now().subtract(Duration(days: 1));
      final updatedTime = DateTime.now();

      await cloudAdapter.save(
        SyncMetadata(id: id, modifiedAt: initialTime),
        MockData('Old Cloud Data'),
      );
      await localAdapter.save(
        SyncMetadata(id: id, modifiedAt: updatedTime),
        MockData('New Local Data'),
      );

      await cloudSync.sync(progressCallback: progressCallback);

      expect(cloudAdapter._data[id]?.content, equals('New Local Data'));
      expect(progressStates.any((state) => state is SavedToCloud), isTrue);
    });

    test('Sync downloads updated cloud file', () async {
      final id = '4';
      final initialTime = DateTime.now().subtract(Duration(days: 1));
      final updatedTime = DateTime.now();

      await localAdapter.save(
        SyncMetadata(id: id, modifiedAt: initialTime),
        MockData('Old Local Data'),
      );
      await cloudAdapter.save(
        SyncMetadata(id: id, modifiedAt: updatedTime),
        MockData('New Cloud Data'),
      );

      await cloudSync.sync(progressCallback: progressCallback);

      expect(localAdapter._data[id]?.content, equals('New Cloud Data'));
      expect(progressStates.any((state) => state is SavedToLocal), isTrue);
    });

    test('Sync handles error on fetch local metadata', () async {
      localAdapter.throwErrorOnFetchMetadata = true;
      await cloudSync.sync(progressCallback: progressCallback);
      expect(progressStates.any((state) => state is SyncError), isTrue);
    });

    test('Sync handles error on fetch cloud metadata', () async {
      cloudAdapter.throwErrorOnFetchMetadata = true;
      await cloudSync.sync(progressCallback: progressCallback);
      expect(progressStates.any((state) => state is SyncError), isTrue);
    });

    test('Sync handles error on fetch local detail', () async {
      localAdapter.throwErrorOnFetchDetail = true;
      await localAdapter.save(
        SyncMetadata(id: '5', modifiedAt: DateTime.now()),
        MockData('Data'),
      );
      await cloudSync.sync(progressCallback: progressCallback);
      expect(progressStates.any((state) => state is SyncError), isTrue);
    });

    test('Sync handles error on fetch cloud detail', () async {
      cloudAdapter.throwErrorOnFetchDetail = true;
      await cloudAdapter.save(
        SyncMetadata(id: '6', modifiedAt: DateTime.now()),
        MockData('Data'),
      );
      await cloudSync.sync(progressCallback: progressCallback);
      expect(progressStates.any((state) => state is SyncError), isTrue);
    });

    test('Sync handles error on save to local', () async {
      localAdapter.throwErrorOnSave = true;
      await cloudAdapter.save(
        SyncMetadata(id: '7', modifiedAt: DateTime.now()),
        MockData('Data'),
      );
      await cloudSync.sync(progressCallback: progressCallback);
      expect(progressStates.any((state) => state is SyncError), isTrue);
    });

    test('Sync handles error on save to cloud', () async {
      cloudAdapter.throwErrorOnSave = true;
      await localAdapter.save(
        SyncMetadata(id: '8', modifiedAt: DateTime.now()),
        MockData('Data'),
      );
      await cloudSync.sync(progressCallback: progressCallback);
      expect(progressStates.any((state) => state is SyncError), isTrue);
    });

    test('Auto sync calls sync periodically', () async {
      int syncCount = 0;
      cloudSync.autoSync(
        interval: Duration(milliseconds: 100),
        progressCallback: (_) {
          syncCount++;
        },
      );
      await Future.delayed(Duration(milliseconds: 350));
      cloudSync.stopAutoSync();
      expect(syncCount, greaterThanOrEqualTo(3));
    });

    test('Auto sync skips when sync is in progress', () async {
      int syncCount = 0;
      localAdapter.throwErrorOnFetchMetadata = true;
      cloudSync.autoSync(
        interval: Duration(milliseconds: 100),
        progressCallback: (state) {
          if (state is InProgress) {
            syncCount++;
          }
        },
      );
      await Future.delayed(Duration(milliseconds: 350));
      cloudSync.stopAutoSync();
      expect(
        syncCount,
        lessThanOrEqualTo(2),
      );
    });
  });
}
