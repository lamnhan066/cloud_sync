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

  @override
  String toString() => 'MockData(content: $content)';
}

class MockSyncAdapter extends SyncAdapter<SyncMetadata, MockData> {
  final Map<String, MockData> _data = {};
  final Map<String, SyncMetadata> _metadata = {};
  bool throwErrorOnFetchMetadata = false;
  bool throwErrorOnFetchDetail = false;
  bool throwErrorOnSave = false;

  // Add delay for testing timeouts and concurrent behavior
  Duration fetchDelay = Duration.zero;
  Duration saveDelay = Duration.zero;

  // Tracking calls for verification
  int fetchMetadataCallCount = 0;
  int fetchDetailCallCount = 0;
  int saveCallCount = 0;

  void reset() {
    _data.clear();
    _metadata.clear();
    throwErrorOnFetchMetadata = false;
    throwErrorOnFetchDetail = false;
    throwErrorOnSave = false;
    fetchDelay = Duration.zero;
    saveDelay = Duration.zero;
    fetchMetadataCallCount = 0;
    fetchDetailCallCount = 0;
    saveCallCount = 0;
  }

  @override
  Future<List<SyncMetadata>> fetchMetadataList() async {
    fetchMetadataCallCount++;
    if (fetchDelay > Duration.zero) {
      await Future.delayed(fetchDelay);
    }
    if (throwErrorOnFetchMetadata) {
      throw Exception('Fetch Metadata Error');
    }
    return _metadata.values.toList();
  }

  @override
  Future<MockData> fetchDetail(SyncMetadata metadata) async {
    fetchDetailCallCount++;
    if (fetchDelay > Duration.zero) {
      await Future.delayed(fetchDelay);
    }
    if (throwErrorOnFetchDetail) {
      throw Exception('Fetch Detail Error');
    }
    final data = _data[metadata.id];
    if (data == null) {
      throw Exception('Data not found for ID: ${metadata.id}');
    }
    return data;
  }

  @override
  Future<void> save(SyncMetadata metadata, MockData detail) async {
    saveCallCount++;
    if (saveDelay > Duration.zero) {
      await Future.delayed(saveDelay);
    }
    if (throwErrorOnSave) {
      throw Exception('Save Error');
    }
    _metadata[metadata.id] = metadata;
    _data[metadata.id] = detail;
  }
}

// Custom equality matcher for SyncState types
class IsSyncStateType extends Matcher {
  final Type expectedType;
  IsSyncStateType(this.expectedType);

  @override
  bool matches(item, Map matchState) => item.runtimeType == expectedType;

  @override
  Description describe(Description description) =>
      description.add('is a $expectedType');
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

    tearDown(() {
      localAdapter.reset();
      cloudAdapter.reset();
      progressStates.clear();
    });

    void progressCallback(SyncState<SyncMetadata> state) {
      progressStates.add(state);
    }

    test('Sync completes successfully with no changes', () async {
      await cloudSync.sync(progressCallback: progressCallback);

      // Verify expected state sequence
      expect(progressStates, [
        isA<FetchingLocalMetadata>(),
        isA<FetchingCloudMetadata>(),
        isA<ScanningLocal>(),
        isA<ScanningCloud>(),
        isA<SyncCompleted>(),
      ]);

      expect(localAdapter.fetchMetadataCallCount, 1);
      expect(cloudAdapter.fetchMetadataCallCount, 1);
      expect(localAdapter.saveCallCount, 0);
      expect(cloudAdapter.saveCallCount, 0);
    });

    test('Sync uploads new local file', () async {
      final localMetadata = SyncMetadata(id: '1', modifiedAt: DateTime.now());
      final localData = MockData('Local Data');
      await localAdapter.save(localMetadata, localData);

      await cloudSync.sync(progressCallback: progressCallback);

      expect(cloudAdapter._data['1'], equals(localData));
      expect(cloudAdapter._metadata['1'], equals(localMetadata));

      expect(
          progressStates,
          containsAllInOrder([
            isA<FetchingLocalMetadata>(),
            isA<FetchingCloudMetadata>(),
            isA<ScanningLocal>(),
            isA<ScanningCloud>(),
            isA<SavingToCloud>(),
            isA<SavedToCloud>(),
            isA<SyncCompleted>(),
          ]));

      // Get the specific SavingToCloud state for further verification
      final savingState =
          progressStates.firstWhere((s) => s is SavingToCloud) as SavingToCloud;
      expect(savingState.metadata.id, equals('1'));
    });

    test('Sync downloads new cloud file', () async {
      final cloudMetadata = SyncMetadata(id: '2', modifiedAt: DateTime.now());
      final cloudData = MockData('Cloud Data');
      await cloudAdapter.save(cloudMetadata, cloudData);

      await cloudSync.sync(progressCallback: progressCallback);

      expect(localAdapter._data['2'], equals(cloudData));
      expect(localAdapter._metadata['2'], equals(cloudMetadata));

      expect(
          progressStates,
          containsAllInOrder([
            isA<FetchingLocalMetadata>(),
            isA<FetchingCloudMetadata>(),
            isA<ScanningLocal>(),
            isA<SavingToLocal>(),
            isA<SavedToLocal>(),
            isA<ScanningCloud>(),
            isA<SyncCompleted>(),
          ]));

      // Verify metadata in SavingToLocal state
      final savingState =
          progressStates.firstWhere((s) => s is SavingToLocal) as SavingToLocal;
      expect(savingState.metadata.id, equals('2'));
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

      // Verify the cloud metadata was updated with the newer timestamp
      expect(cloudAdapter._metadata[id]?.modifiedAt, equals(updatedTime));
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

      // Verify the local metadata was updated with the newer timestamp
      expect(localAdapter._metadata[id]?.modifiedAt, equals(updatedTime));
    });

    test('Sync handles soft-deleted items', () async {
      // Setup: Add item to both local and cloud
      final id = 'deleted-item';
      final initialTime = DateTime.now().subtract(Duration(days: 1));
      final deletionTime = DateTime.now();

      // Add regular item to both storages
      await localAdapter.save(
        SyncMetadata(id: id, modifiedAt: initialTime),
        MockData('Regular Data'),
      );
      await cloudAdapter.save(
        SyncMetadata(id: id, modifiedAt: initialTime),
        MockData('Regular Data'),
      );

      // Mark as deleted in local with newer timestamp
      await localAdapter.save(
        SyncMetadata(id: id, modifiedAt: deletionTime, isDeleted: true),
        MockData('Deleted Data'),
      );

      // Sync and verify deletion propagates to cloud
      await cloudSync.sync(progressCallback: progressCallback);

      expect(cloudAdapter._metadata[id]?.isDeleted, isTrue);
      expect(cloudAdapter._metadata[id]?.modifiedAt, equals(deletionTime));
    });

    test('Sync handles error on fetch local metadata', () async {
      localAdapter.throwErrorOnFetchMetadata = true;
      await cloudSync.sync(progressCallback: progressCallback);

      expect(progressStates, contains(isA<SyncError>()));
      final errorState =
          progressStates.lastWhere((state) => state is SyncError) as SyncError;
      expect(errorState.error.toString(), contains('Fetch Metadata Error'));
      expect(errorState.stackTrace, isNotNull);
    });

    test('Sync handles error on fetch cloud metadata', () async {
      cloudAdapter.throwErrorOnFetchMetadata = true;
      await cloudSync.sync(progressCallback: progressCallback);

      expect(progressStates, contains(isA<SyncError>()));
    });

    test('Sync handles error on fetch local detail', () async {
      localAdapter.throwErrorOnFetchDetail = true;
      await localAdapter.save(
        SyncMetadata(id: '5', modifiedAt: DateTime.now()),
        MockData('Data'),
      );
      await cloudSync.sync(progressCallback: progressCallback);

      expect(progressStates, contains(isA<SyncError>()));
    });

    test('Sync handles error on fetch cloud detail', () async {
      cloudAdapter.throwErrorOnFetchDetail = true;
      await cloudAdapter.save(
        SyncMetadata(id: '6', modifiedAt: DateTime.now()),
        MockData('Data'),
      );
      await cloudSync.sync(progressCallback: progressCallback);

      expect(progressStates, contains(isA<SyncError>()));
    });

    test('Sync handles error on save to local', () async {
      localAdapter.throwErrorOnSave = true;
      await cloudAdapter.save(
        SyncMetadata(id: '7', modifiedAt: DateTime.now()),
        MockData('Data'),
      );
      await cloudSync.sync(progressCallback: progressCallback);

      expect(progressStates.any((state) => state is SyncError), isTrue);
      expect(progressStates.any((state) => state is SavingToLocal), isTrue);

      // Check for continuous sync even after error
      expect(progressStates.last, isA<SyncCompleted>());
    });

    test('Sync handles error on save to cloud', () async {
      cloudAdapter.throwErrorOnSave = true;
      await localAdapter.save(
        SyncMetadata(id: '8', modifiedAt: DateTime.now()),
        MockData('Data'),
      );
      await cloudSync.sync(progressCallback: progressCallback);

      expect(progressStates.any((state) => state is SyncError), isTrue);
      expect(progressStates.any((state) => state is SavingToCloud), isTrue);

      // Check for continuous sync even after error
      expect(progressStates.last, isA<SyncCompleted>());
    });

    test('Auto sync calls sync periodically', () async {
      int syncCount = 0;
      cloudSync.autoSync(
        interval: Duration(milliseconds: 100),
        progressCallback: (state) {
          if (state is SyncCompleted) {
            syncCount++;
          }
        },
      );
      await Future.delayed(Duration(milliseconds: 350));
      cloudSync.stopAutoSync();
      expect(syncCount, greaterThanOrEqualTo(3));
    });

    test('Auto sync can be stopped', () async {
      int syncCount = 0;
      cloudSync.autoSync(
        interval: Duration(milliseconds: 100),
        progressCallback: (state) {
          if (state is SyncCompleted) {
            syncCount++;
          }
        },
      );

      // Let it run for a bit
      await Future.delayed(Duration(milliseconds: 250));
      final countBeforeStopping = syncCount;

      // Stop auto-sync
      cloudSync.stopAutoSync();

      // Wait a bit more to ensure no more syncs happen
      await Future.delayed(Duration(milliseconds: 250));

      expect(syncCount, equals(countBeforeStopping),
          reason: 'No new syncs should occur after stopping');
    });

    test('Auto sync restarts properly after stopping', () async {
      int firstRoundCount = 0;
      cloudSync.autoSync(
        interval: Duration(milliseconds: 100),
        progressCallback: (state) {
          if (state is SyncCompleted) {
            firstRoundCount++;
          }
        },
      );

      await Future.delayed(Duration(milliseconds: 250));
      cloudSync.stopAutoSync();

      // Reset and start again with new interval
      int secondRoundCount = 0;
      cloudSync.autoSync(
        interval: Duration(milliseconds: 50),
        progressCallback: (state) {
          if (state is SyncCompleted) {
            secondRoundCount++;
          }
        },
      );

      await Future.delayed(Duration(milliseconds: 250));
      cloudSync.stopAutoSync();

      // Second round should have more syncs due to shorter interval
      expect(secondRoundCount, greaterThan(firstRoundCount));
    });

    test('Auto sync skips when sync is in progress', () async {
      int syncStartedCount = 0;
      int syncCompletedCount = 0;

      // Add delay to ensure sync takes time
      cloudAdapter.fetchDelay = Duration(milliseconds: 150);

      cloudSync.autoSync(
        interval: Duration(milliseconds: 100),
        progressCallback: (state) {
          progressCallback(state);
          if (state is FetchingLocalMetadata) {
            syncStartedCount++;
          }
          if (state is SyncCompleted) {
            syncCompletedCount++;
          }
        },
      );

      await Future.delayed(Duration(milliseconds: 350));
      cloudSync.stopAutoSync();

      // Should have fewer completed syncs than started syncs
      expect(syncStartedCount, lessThanOrEqualTo(syncCompletedCount + 1));

      // If a sync is in progress when timer fires, we should see InProgress state
      expect(progressStates.whereType<InProgress>().isNotEmpty, isTrue);
    });

    test('Concurrent sync works as expected', () async {
      // Add some delay to make concurrency noticeable
      localAdapter.fetchDelay = Duration(milliseconds: 50);
      cloudAdapter.fetchDelay = Duration(milliseconds: 50);

      // Add test data
      final localMetadata = SyncMetadata(id: '9', modifiedAt: DateTime.now());
      final localData = MockData('Local Concurrent Data');
      await localAdapter.save(localMetadata, localData);

      final cloudMetadata = SyncMetadata(id: '10', modifiedAt: DateTime.now());
      final cloudData = MockData('Cloud Concurrent Data');
      await cloudAdapter.save(cloudMetadata, cloudData);

      // Measure execution time
      final stopwatch = Stopwatch()..start();
      await cloudSync.sync(
        progressCallback: progressCallback,
        useConcurrentSync: true,
      );
      final concurrentDuration = stopwatch.elapsed;

      // Check proper data exchange
      expect(cloudAdapter._data['9'], equals(localData));
      expect(localAdapter._data['10'], equals(cloudData));

      // Reset and run sequential for comparison
      localAdapter.reset();
      cloudAdapter.reset();
      progressStates.clear();

      // Add some delay to make concurrency noticeable
      localAdapter.fetchDelay = Duration(milliseconds: 50);
      cloudAdapter.fetchDelay = Duration(milliseconds: 50);

      // Re-add test data
      await localAdapter.save(localMetadata, localData);
      await cloudAdapter.save(cloudMetadata, cloudData);

      stopwatch.reset();
      await cloudSync.sync(
        progressCallback: progressCallback,
        useConcurrentSync: false,
      );
      final sequentialDuration = stopwatch.elapsed;

      // Concurrent should be noticeably faster than sequential
      expect(
        concurrentDuration.inMilliseconds < sequentialDuration.inMilliseconds,
        isTrue,
        reason: 'Concurrent sync should be faster than sequential',
      );
    });

    test('Direct constructor works the same as fromAdapters factory', () async {
      // Create using direct constructor
      final manualCloudSync = CloudSync<SyncMetadata, MockData>(
        fetchLocalMetadataList: localAdapter.fetchMetadataList,
        fetchCloudMetadataList: cloudAdapter.fetchMetadataList,
        fetchLocalDetail: localAdapter.fetchDetail,
        fetchCloudDetail: cloudAdapter.fetchDetail,
        saveToLocal: localAdapter.save,
        saveToCloud: cloudAdapter.save,
      );

      // Add test data
      final localMeta =
          SyncMetadata(id: 'direct-test', modifiedAt: DateTime.now());
      final localData = MockData('Direct constructor test');
      await localAdapter.save(localMeta, localData);

      // Run sync and check results
      await manualCloudSync.sync();
      expect(cloudAdapter._data['direct-test'], equals(localData));
    });

    test('Sync handles empty metadata case correctly', () async {
      // Make sure metadata lists are empty
      localAdapter.reset();
      cloudAdapter.reset();

      await cloudSync.sync(progressCallback: progressCallback);

      // Should complete successfully with no errors
      expect(progressStates.last, isA<SyncCompleted>());
    });

    test('Sync with same timestamp but different data makes no changes',
        () async {
      // Create metadata with exact same timestamp
      final now = DateTime.now();
      final id = 'same-timestamp';

      await localAdapter.save(
        SyncMetadata(id: id, modifiedAt: now),
        MockData('Local Data'),
      );
      await cloudAdapter.save(
        SyncMetadata(id: id, modifiedAt: now),
        MockData('Cloud Data'),
      );

      await cloudSync.sync(progressCallback: progressCallback);

      // Data should remain unchanged in both directions
      expect(localAdapter._data[id]?.content, equals('Local Data'));
      expect(cloudAdapter._data[id]?.content, equals('Cloud Data'));
    });

    test('Sync handles network timeout simulation', () async {
      // Set very long delay to simulate timeout
      cloudAdapter.fetchDelay = Duration(seconds: 2);

      await localAdapter.save(
        SyncMetadata(id: 'timeout-test', modifiedAt: DateTime.now()),
        MockData('Timeout test data'),
      );

      // Should still complete without throwing
      await cloudSync.sync(progressCallback: progressCallback);
      expect(progressStates.last, isA<SyncCompleted>());
    });

    test('Sync synchronizes multiple items correctly', () async {
      // Add multiple items to local
      for (int i = 0; i < 5; i++) {
        await localAdapter.save(
          SyncMetadata(id: 'local-$i', modifiedAt: DateTime.now()),
          MockData('Local data $i'),
        );
      }

      // Add multiple items to cloud
      for (int i = 0; i < 5; i++) {
        await cloudAdapter.save(
          SyncMetadata(id: 'cloud-$i', modifiedAt: DateTime.now()),
          MockData('Cloud data $i'),
        );
      }

      await cloudSync.sync(progressCallback: progressCallback);

      // Verify all items were synced both ways
      for (int i = 0; i < 5; i++) {
        expect(
            cloudAdapter._data['local-$i']?.content, equals('Local data $i'));
        expect(
            localAdapter._data['cloud-$i']?.content, equals('Cloud data $i'));
      }

      // Count the save operations
      final savedToLocalCount = progressStates.whereType<SavedToLocal>().length;
      final savedToCloudCount = progressStates.whereType<SavedToCloud>().length;

      expect(savedToLocalCount, equals(5));
      expect(savedToCloudCount, equals(5));
    });

    test('Sync handles exceptions without progress callback', () async {
      localAdapter.throwErrorOnFetchMetadata = true;

      // Without progress callback, errors are rethrown
      expect(() async => await cloudSync.sync(), throwsA(isA<Exception>()));
    });
  });
}
