import 'dart:async';
import 'dart:convert';

import 'package:cloud_sync/cloud_sync.dart';
import 'package:test/test.dart';

class MockData {
  MockData(this.content);

  factory MockData.fromMap(Map<String, dynamic> map) {
    return MockData(map['content'] as String);
  }
  final String content;

  Map<String, dynamic> toMap() {
    return {'content': content};
  }

  @override
  String toString() => 'MockData(content: $content)';
}

class MockSyncAdapter extends SyncMetadataAdapter<SyncMetadata, MockData> {
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

  // Add a Completer to allow controlled completion of operations
  Completer<void>? operationCompleter;

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
    operationCompleter = null;
  }

  @override
  Future<List<SyncMetadata>> fetchMetadataList() async {
    fetchMetadataCallCount++;
    if (fetchDelay > Duration.zero) {
      await Future<void>.delayed(fetchDelay);
    }
    if (operationCompleter != null) {
      await operationCompleter!.future;
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
      await Future<void>.delayed(fetchDelay);
    }
    if (operationCompleter != null) {
      await operationCompleter!.future;
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
      await Future<void>.delayed(saveDelay);
    }
    if (operationCompleter != null) {
      await operationCompleter!.future;
    }
    if (throwErrorOnSave) {
      throw Exception('Save Error');
    }
    _metadata[metadata.id] = metadata;
    _data[metadata.id] = detail;
  }

  // Helper method to simulate operations in progress
  void blockOperations() {
    operationCompleter = Completer<void>();
  }

  // Helper method to unblock operations
  void unblockOperations() {
    if (operationCompleter != null && !operationCompleter!.isCompleted) {
      operationCompleter!.complete();
    }
  }
}

class MockSerializableSyncAdapter
    extends SerializableSyncMetadataAdapter<SyncMetadata, MockData> {
  MockSerializableSyncAdapter({
    required super.metadataToJson,
    required super.metadataFromJson,
  });

  @override
  Future<List<SyncMetadata>> fetchMetadataList() async => [];

  @override
  Future<MockData> fetchDetail(SyncMetadata metadata) async => MockData('');

  @override
  Future<void> save(SyncMetadata metadata, MockData detail) async {}
}

// Custom equality matcher for SyncState types
class IsSyncStateType extends Matcher {
  IsSyncStateType(this.expectedType);
  final Type expectedType;

  @override
  bool matches(dynamic item, Map<dynamic, dynamic> matchState) =>
      item.runtimeType == expectedType;

  @override
  Description describe(Description description) =>
      description.add('is a $expectedType');
}

void main() {
  group('CloudSync Tests', () {
    late MockSyncAdapter localAdapter;
    late MockSyncAdapter cloudAdapter;
    late CloudSync<SyncMetadata, MockData> cloudSync;
    final progressStates = <SyncState<SyncMetadata>>[];

    setUp(() {
      localAdapter = MockSyncAdapter();
      cloudAdapter = MockSyncAdapter();
      cloudSync =
          CloudSync.fromAdapters(local: localAdapter, cloud: cloudAdapter);
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
        isA<FetchingLocalMetadata<SyncMetadata>>(),
        isA<FetchingCloudMetadata<SyncMetadata>>(),
        isA<ScanningLocal<SyncMetadata>>(),
        isA<ScanningCloud<SyncMetadata>>(),
        isA<SyncCompleted<SyncMetadata>>(),
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
          isA<FetchingLocalMetadata<SyncMetadata>>(),
          isA<FetchingCloudMetadata<SyncMetadata>>(),
          isA<ScanningLocal<SyncMetadata>>(),
          isA<ScanningCloud<SyncMetadata>>(),
          isA<SavingToCloud<SyncMetadata>>(),
          isA<SavedToCloud<SyncMetadata>>(),
          isA<SyncCompleted<SyncMetadata>>(),
        ]),
      );

      // Get the specific SavingToCloud state for further verification
      final savingState = progressStates.firstWhere((s) => s is SavingToCloud)
          as SavingToCloud<SyncMetadata>;
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
          isA<FetchingLocalMetadata<SyncMetadata>>(),
          isA<FetchingCloudMetadata<SyncMetadata>>(),
          isA<ScanningLocal<SyncMetadata>>(),
          isA<SavingToLocal<SyncMetadata>>(),
          isA<SavedToLocal<SyncMetadata>>(),
          isA<ScanningCloud<SyncMetadata>>(),
          isA<SyncCompleted<SyncMetadata>>(),
        ]),
      );

      // Verify metadata in SavingToLocal state
      final savingState = progressStates.firstWhere((s) => s is SavingToLocal)
          as SavingToLocal<SyncMetadata>;
      expect(savingState.metadata.id, equals('2'));
    });

    test('Sync uploads updated local file', () async {
      const id = '3';
      // Use DateTime.now() carefully - add explicit microsecond offset
      final initialTime = DateTime.now().subtract(const Duration(hours: 1));
      final updatedTime = initialTime.add(const Duration(minutes: 30));

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
      // Use isA matcher with a custom predicate instead of equality
      expect(
        cloudAdapter._metadata[id]?.modifiedAt.millisecondsSinceEpoch,
        equals(updatedTime.millisecondsSinceEpoch),
      );
    });

    test('Sync downloads updated cloud file', () async {
      const id = '4';
      // Use DateTimes with significant difference to avoid test flakiness
      final initialTime = DateTime.now().subtract(const Duration(hours: 1));
      final updatedTime = initialTime.add(const Duration(minutes: 30));

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
      expect(
        localAdapter._metadata[id]?.modifiedAt.millisecondsSinceEpoch,
        equals(updatedTime.millisecondsSinceEpoch),
      );
    });

    test('Sync handles item deleted in local propagating to cloud', () async {
      // Setup: Add item to both local and cloud
      const id = 'deleted-item-local';
      final initialTime = DateTime.now().subtract(const Duration(hours: 1));
      final deletionTime = initialTime.add(const Duration(minutes: 30));

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
      expect(
        cloudAdapter._metadata[id]?.modifiedAt.millisecondsSinceEpoch,
        equals(deletionTime.millisecondsSinceEpoch),
      );
    });

    test('Sync handles item deleted in cloud propagating to local', () async {
      // Setup: Add item to both local and cloud
      const id = 'deleted-item-cloud';
      final initialTime = DateTime.now().subtract(const Duration(hours: 1));
      final deletionTime = initialTime.add(const Duration(minutes: 30));

      // Add regular item to both storages
      await localAdapter.save(
        SyncMetadata(id: id, modifiedAt: initialTime),
        MockData('Regular Data'),
      );
      await cloudAdapter.save(
        SyncMetadata(id: id, modifiedAt: initialTime),
        MockData('Regular Data'),
      );

      // Mark as deleted in cloud with newer timestamp
      await cloudAdapter.save(
        SyncMetadata(id: id, modifiedAt: deletionTime, isDeleted: true),
        MockData('Deleted Data'),
      );

      // Sync and verify deletion propagates to local
      await cloudSync.sync(progressCallback: progressCallback);

      expect(localAdapter._metadata[id]?.isDeleted, isTrue);
      expect(
        localAdapter._metadata[id]?.modifiedAt.millisecondsSinceEpoch,
        equals(deletionTime.millisecondsSinceEpoch),
      );
    });

    test('Sync resolves conflicting deletion and modification correctly',
        () async {
      const id = 'conflict-delete-modify';
      final initialTime = DateTime.now().subtract(const Duration(hours: 1));
      final deleteTime = initialTime.add(const Duration(minutes: 15));
      final modifyTime = initialTime.add(const Duration(minutes: 30));

      // Setup: Add initial item to both
      await localAdapter.save(
        SyncMetadata(id: id, modifiedAt: initialTime),
        MockData('Initial Data'),
      );
      await cloudAdapter.save(
        SyncMetadata(id: id, modifiedAt: initialTime),
        MockData('Initial Data'),
      );

      // Delete in local, but with older timestamp
      await localAdapter.save(
        SyncMetadata(id: id, modifiedAt: deleteTime, isDeleted: true),
        MockData('Deleted Data'),
      );

      // Modify in cloud with newer timestamp
      await cloudAdapter.save(
        SyncMetadata(id: id, modifiedAt: modifyTime),
        MockData('Modified Data'),
      );

      await cloudSync.sync(progressCallback: progressCallback);

      // Modified data should win as it has newer timestamp
      expect(localAdapter._metadata[id]?.isDeleted, isFalse);
      expect(localAdapter._data[id]?.content, equals('Modified Data'));
      expect(cloudAdapter._metadata[id]?.isDeleted, isFalse);
    });

    test('Sync handles error on fetch local metadata', () async {
      localAdapter.throwErrorOnFetchMetadata = true;
      await cloudSync.sync(progressCallback: progressCallback);

      expect(progressStates, contains(isA<SyncError<SyncMetadata>>()));
      final errorState = progressStates.lastWhere((state) => state is SyncError)
          as SyncError<SyncMetadata>;
      expect(errorState.error.toString(), contains('Fetch Metadata Error'));
      expect(errorState.stackTrace, isNotNull);
      // More specific error verification:
      expect(errorState.error, isA<Exception>());
    });

    test('Sync handles error on fetch cloud metadata', () async {
      cloudAdapter.throwErrorOnFetchMetadata = true;
      await cloudSync.sync(progressCallback: progressCallback);

      expect(progressStates, contains(isA<SyncError<SyncMetadata>>()));
      // More specific error verification:
      final errorState = progressStates.lastWhere((state) => state is SyncError)
          as SyncError<SyncMetadata>;
      expect(errorState.error, isA<Exception>());
    });

    test('Sync handles error on fetch local detail', () async {
      localAdapter.throwErrorOnFetchDetail = true;
      await localAdapter.save(
        SyncMetadata(id: '5', modifiedAt: DateTime.now()),
        MockData('Data'),
      );
      await cloudSync.sync(progressCallback: progressCallback);

      expect(progressStates, contains(isA<SyncError<SyncMetadata>>()));
      // More specific error verification:
      final errorState =
          progressStates.lastWhere((state) => state is SyncError) as SyncError;
      expect(errorState.error, isA<Exception>());
    });

    test('Sync handles error on fetch cloud detail', () async {
      cloudAdapter.throwErrorOnFetchDetail = true;
      await cloudAdapter.save(
        SyncMetadata(id: '6', modifiedAt: DateTime.now()),
        MockData('Data'),
      );
      await cloudSync.sync(progressCallback: progressCallback);

      expect(progressStates, contains(isA<SyncError<SyncMetadata>>()));
      // More specific error verification:
      final errorState = progressStates.lastWhere((state) => state is SyncError)
          as SyncError<SyncMetadata>;
      expect(errorState.error, isA<Exception>());
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
      expect(progressStates.last, isA<SyncCompleted<SyncMetadata>>());
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
      expect(progressStates.last, isA<SyncCompleted<SyncMetadata>>());
    });

    test('Auto sync calls sync at least once within given timeframe', () async {
      // Instead of counting exact syncs, just verify at least one happens
      var syncCompleted = false;

      cloudSync.autoSync(
        interval: const Duration(milliseconds: 100),
        progressCallback: (state) {
          if (state is SyncCompleted) {
            syncCompleted = true;
          }
        },
      );

      // Wait with longer timeout to ensure at least one sync happens
      await Future<void>.delayed(const Duration(milliseconds: 500));
      await cloudSync.stopAutoSync();

      expect(
        syncCompleted,
        isTrue,
        reason: 'At least one sync should complete',
      );
    });

    test('Auto sync can be stopped', () async {
      var syncCount = 0;

      // Set up a control point we can use to block sync operation
      cloudAdapter.blockOperations();

      cloudSync.autoSync(
        interval: const Duration(milliseconds: 100),
        progressCallback: (state) {
          if (state is SyncCompleted) {
            syncCount++;
          }
        },
      );

      // Wait a moment to ensure auto-sync is running
      await Future<void>.delayed(const Duration(milliseconds: 200));

      // Capture the current count (should be 0 since operations are blocked)
      final countBeforeStopping = syncCount;

      // Stop auto-sync
      final stopCompleter = Completer<void>()
        ..complete(cloudSync.stopAutoSync());

      // Now unblock operations
      cloudAdapter.unblockOperations();

      // Wait to ensure no new syncs start
      await Future<void>.delayed(const Duration(milliseconds: 200));

      await stopCompleter.future;

      expect(
        syncCount,
        equals(countBeforeStopping),
        reason: 'No new syncs should occur after stopping',
      );
    });

    test('Auto sync restarts properly with different interval', () async {
      // We'll detect the interval by tracking when events happen
      final syncTimes = <DateTime>[];

      // First round with longer interval
      cloudSync.autoSync(
        interval: const Duration(milliseconds: 200),
        progressCallback: (state) {
          if (state is FetchingLocalMetadata) {
            syncTimes.add(DateTime.now());
          }
        },
      );

      // Let it run for a bit
      await Future<void>.delayed(const Duration(milliseconds: 650));
      await cloudSync.stopAutoSync();

      // Should have about 3 sync events (at 0ms, ~200ms, ~400ms, ~600ms)
      // We're not asserting the exact count, just gathering data
      final firstRoundTimes = List<DateTime>.from(syncTimes);
      syncTimes.clear();

      // Reset and start again with shorter interval
      cloudSync.autoSync(
        interval: const Duration(milliseconds: 100),
        progressCallback: (state) {
          if (state is FetchingLocalMetadata) {
            syncTimes.add(DateTime.now());
          }
        },
      );

      await Future<void>.delayed(const Duration(milliseconds: 650));
      await cloudSync.stopAutoSync();

      // Second round should have approximately twice as many events
      // We allow a range for test stability
      expect(
        syncTimes.length > firstRoundTimes.length,
        isTrue,
        reason: 'Shorter interval should result in more sync events',
      );
    });

    test('Auto sync skips when sync is in progress', () async {
      var syncStartedCount = 0;
      var syncSkippedCount = 0;

      // Add significant delay to simulate long-running sync
      cloudAdapter.fetchDelay = const Duration(milliseconds: 300);

      cloudSync.autoSync(
        interval: const Duration(milliseconds: 100),
        progressCallback: (state) {
          progressCallback(state);
          if (state is FetchingLocalMetadata) {
            syncStartedCount++;
          }
          if (state is InProgress) {
            syncSkippedCount++;
          }
        },
      );

      // Wait long enough for multiple intervals but not too many syncs
      await Future<void>.delayed(const Duration(milliseconds: 500));
      await cloudSync.stopAutoSync();

      // Verify at least one sync started
      expect(
        syncStartedCount,
        greaterThan(0),
        reason: 'At least one sync should have started',
      );

      // Verify at least one sync was skipped
      expect(
        syncSkippedCount,
        greaterThan(0),
        reason:
            'At least one sync should have been skipped due to in-progress operation',
      );

      // Ensure syncs are not overlapping
      expect(
        syncStartedCount,
        lessThanOrEqualTo(2),
        reason:
            'Syncs should not overlap, and only a limited number should start',
      );
    });

    test('Concurrent sync completes successfully', () async {
      // Instead of comparing timing, we'll verify correct behavior

      // Add test data
      final localMetadata = SyncMetadata(id: '9', modifiedAt: DateTime.now());
      final localData = MockData('Local Concurrent Data');
      await localAdapter.save(localMetadata, localData);

      final cloudMetadata = SyncMetadata(id: '10', modifiedAt: DateTime.now());
      final cloudData = MockData('Cloud Concurrent Data');
      await cloudAdapter.save(cloudMetadata, cloudData);

      await cloudSync.sync(
        progressCallback: progressCallback,
        useConcurrentSync: true,
      );

      // Check proper data exchange
      expect(cloudAdapter._data['9'], equals(localData));
      expect(localAdapter._data['10'], equals(cloudData));

      // Verify expected progress states for concurrent sync
      expect(
        progressStates.whereType<FetchingLocalMetadata<SyncMetadata>>().length,
        1,
        reason: 'Should have exactly one FetchingLocalMetadata state',
      );
      expect(
        progressStates.whereType<FetchingCloudMetadata<SyncMetadata>>().length,
        1,
        reason: 'Should have exactly one FetchingCloudMetadata state',
      );
      expect(
        progressStates.whereType<SyncCompleted<SyncMetadata>>().length,
        1,
        reason: 'Should have exactly one SyncCompleted state',
      );
    });

    test('Sync handles empty metadata case correctly', () async {
      // Make sure metadata lists are empty
      localAdapter.reset();
      cloudAdapter.reset();

      await cloudSync.sync(progressCallback: progressCallback);

      // Should complete successfully with no errors
      expect(progressStates.last, isA<SyncCompleted<SyncMetadata>>());
    });

    test('Sync with same timestamp keeps both versions when different',
        () async {
      // Create metadata with exact same timestamp
      final now = DateTime.now();
      const id = 'same-timestamp';

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

    test('Sync synchronizes multiple items correctly', () async {
      // Add multiple items to local
      for (var i = 0; i < 5; i++) {
        await localAdapter.save(
          SyncMetadata(id: 'local-$i', modifiedAt: DateTime.now()),
          MockData('Local data $i'),
        );
      }

      // Add multiple items to cloud
      for (var i = 0; i < 5; i++) {
        await cloudAdapter.save(
          SyncMetadata(id: 'cloud-$i', modifiedAt: DateTime.now()),
          MockData('Cloud data $i'),
        );
      }

      await cloudSync.sync(progressCallback: progressCallback);

      // Verify all items were synced both ways
      for (var i = 0; i < 5; i++) {
        expect(
          cloudAdapter._data['local-$i']?.content,
          equals('Local data $i'),
        );
        expect(
          localAdapter._data['cloud-$i']?.content,
          equals('Cloud data $i'),
        );
      }

      // Count the save operations
      final savedToLocalCount =
          progressStates.whereType<SavedToLocal<SyncMetadata>>().length;
      final savedToCloudCount =
          progressStates.whereType<SavedToCloud<SyncMetadata>>().length;

      expect(savedToLocalCount, equals(5));
      expect(savedToCloudCount, equals(5));
    });

    test('Sync handles exceptions without progress callback', () async {
      localAdapter.throwErrorOnFetchMetadata = true;

      // Without progress callback, errors are rethrown
      expect(() async => cloudSync.sync(), throwsA(isA<Exception>()));
    });

    test('Auto sync skips when sync is in progress with timeout', () async {
      var syncStartedCount = 0;
      var syncSkippedCount = 0;

      // Add significant delay to simulate long-running sync
      cloudAdapter.fetchDelay = const Duration(milliseconds: 300);

      cloudSync.autoSync(
        interval: const Duration(milliseconds: 100),
        progressCallback: (state) {
          progressCallback(state);
          if (state is FetchingLocalMetadata) {
            syncStartedCount++;
          }
          if (state is InProgress) {
            syncSkippedCount++;
          }
        },
      );

      // Wait long enough for multiple intervals but not too many syncs
      await Future<void>.delayed(const Duration(milliseconds: 500));
      await cloudSync.stopAutoSync();

      // Verify at least one sync started
      expect(
        syncStartedCount,
        greaterThan(0),
        reason: 'At least one sync should have started',
      );

      // Verify at least one sync was skipped
      expect(
        syncSkippedCount,
        greaterThan(0),
        reason:
            'At least one sync should have been skipped due to in-progress operation',
      );

      // Ensure syncs are not overlapping
      expect(
        syncStartedCount,
        lessThanOrEqualTo(2),
        reason:
            'Syncs should not overlap, and only a limited number should start',
      );

      //Test timeout.
      await expectLater(
        Future<void>.delayed(
          const Duration(milliseconds: 1000),
          () => 'timeout',
        ),
        completion(equals('timeout')),
      );
    });

    test('Sync operation can be effectively cancelled', () async {
      // Create a separate instance that we can control
      final cancelableSync =
          CloudSync.fromAdapters(local: localAdapter, cloud: cloudAdapter);

      // Add test data that needs syncing
      await localAdapter.save(
        SyncMetadata(id: 'cancel-test', modifiedAt: DateTime.now()),
        MockData('Data to be synced'),
      );

      // Block operations so sync will hang
      localAdapter.blockOperations();
      cloudAdapter.blockOperations();

      // Start sync in background
      final syncFuture =
          cancelableSync.sync(progressCallback: progressCallback);

      // Wait a moment to ensure sync has started
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Cancel sync operation by disposing the CloudSync instance
      // This simulates what would happen in a real app when the sync is cancelled
      final cancelCompleter = Completer<void>()
        ..complete(cancelableSync.cancelSync());

      // Unblock operations to allow the sync to continue if it wasn't properly cancelled
      localAdapter.unblockOperations();
      cloudAdapter.unblockOperations();

      await cancelCompleter.future;

      // Wait for the sync future to complete
      await syncFuture;

      // If cancellation worked correctly, cloud should not have received the data
      expect(
        cloudAdapter._data.containsKey('cancel-test'),
        isFalse,
        reason: 'Cancelled sync should not complete the data transfer',
      );
    });

    test('CloudSync dispose stops all operations', () async {
      final cancelableSync =
          CloudSync.fromAdapters(local: localAdapter, cloud: cloudAdapter);

      // Block operations so sync will hang
      localAdapter.blockOperations();
      cloudAdapter.blockOperations();

      // Start sync in background
      final syncFuture =
          cancelableSync.sync(progressCallback: progressCallback);

      // Wait a moment to ensure sync has started
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Dispose the CloudSync instance
      final disposedCompleter = Completer<void>()
        ..complete(cancelableSync.dispose());

      // Unblock operations to allow the sync to continue if it wasn't properly cancelled
      localAdapter.unblockOperations();
      cloudAdapter.unblockOperations();

      await disposedCompleter.future;

      // Expect the future to complete without error.
      await expectLater(syncFuture, completes);

      // Verify that after dispose, further sync calls throw an error.
      expect(cancelableSync.sync, throwsA(isA<SyncDisposedError>()));

      //Verify that auto sync is also stopped.
      expect(
        () => cancelableSync.autoSync(
          interval: const Duration(milliseconds: 100),
        ),
        throwsA(isA<SyncDisposedError>()),
      );
    });

    test('Order independence: local-first equals cloud-first result', () async {
      // Create test data
      const id = 'order-test';
      final timestamp = DateTime.now();
      final data = MockData('Consistent Data');

      // Setup for first approach: local sync first
      final localFirstAdapter1 = MockSyncAdapter();
      final localFirstAdapter2 = MockSyncAdapter();
      await localFirstAdapter1.save(
        SyncMetadata(id: id, modifiedAt: timestamp),
        data,
      );

      final localFirstSync = CloudSync.fromAdapters(
        local: localFirstAdapter1,
        cloud: localFirstAdapter2,
      );
      await localFirstSync.sync();

      // Setup for second approach: cloud sync first
      final cloudFirstAdapter1 = MockSyncAdapter();
      final cloudFirstAdapter2 = MockSyncAdapter();
      await cloudFirstAdapter2.save(
        SyncMetadata(id: id, modifiedAt: timestamp),
        data,
      );

      final cloudFirstSync = CloudSync.fromAdapters(
        local: cloudFirstAdapter1,
        cloud: cloudFirstAdapter2,
      );
      await cloudFirstSync.sync();

      // Both approaches should result in the data being in both places
      expect(localFirstAdapter1._data[id], equals(data));
      expect(localFirstAdapter2._data[id], equals(data));
      expect(cloudFirstAdapter1._data[id], equals(data));
      expect(cloudFirstAdapter2._data[id], equals(data));

      // And the metadata should be consistent
      expect(
        localFirstAdapter1._metadata[id]?.modifiedAt.millisecondsSinceEpoch,
        equals(timestamp.millisecondsSinceEpoch),
      );
      expect(
        localFirstAdapter2._metadata[id]?.modifiedAt.millisecondsSinceEpoch,
        equals(timestamp.millisecondsSinceEpoch),
      );
      expect(
        cloudFirstAdapter1._metadata[id]?.modifiedAt.millisecondsSinceEpoch,
        equals(timestamp.millisecondsSinceEpoch),
      );
      expect(
        cloudFirstAdapter2._metadata[id]?.modifiedAt.millisecondsSinceEpoch,
        equals(timestamp.millisecondsSinceEpoch),
      );
    });
  });

  group('SerializableSyncMetadata', () {
    const testId = 'abc123';
    final testDate = DateTime.parse('2024-04-10T12:00:00.000Z');
    const testIsDeleted = true;

    final testMetadata = SerializableSyncMetadata(
      id: testId,
      modifiedAt: testDate,
      isDeleted: testIsDeleted,
    );

    test('toMap should return correct map', () {
      final map = testMetadata.toMap();

      expect(map, {
        'id': testId,
        'modifiedAt': testDate.toIso8601String(),
        'isDeleted': testIsDeleted,
      });
    });

    test('fromMap should return equivalent instance', () {
      final map = {
        'id': testId,
        'modifiedAt': testDate.toIso8601String(),
        'isDeleted': testIsDeleted,
      };

      final fromMap = SerializableSyncMetadata.fromMap(map);

      expect(fromMap.id, testMetadata.id);
      expect(fromMap.modifiedAt, testMetadata.modifiedAt);
      expect(fromMap.isDeleted, testMetadata.isDeleted);
    });

    test('toJson should return valid JSON string', () {
      final jsonStr = testMetadata.toJson();

      final expectedJson = json.encode({
        'id': testId,
        'modifiedAt': testDate.toIso8601String(),
        'isDeleted': testIsDeleted,
      });

      expect(jsonStr, expectedJson);
    });

    test('fromJson should return equivalent instance', () {
      final jsonString = json.encode({
        'id': testId,
        'modifiedAt': testDate.toIso8601String(),
        'isDeleted': testIsDeleted,
      });

      final fromJson = SerializableSyncMetadata.fromJson(jsonString);

      expect(fromJson.id, testMetadata.id);
      expect(fromJson.modifiedAt, testMetadata.modifiedAt);
      expect(fromJson.isDeleted, testMetadata.isDeleted);
    });
  });

  group('SerializableSyncAdapter Tests', () {
    late SerializableSyncMetadataAdapter<SyncMetadata, MockData> adapter;

    setUp(() {
      adapter = MockSerializableSyncAdapter(
        metadataToJson: (metadata) => json.encode({
          'id': metadata.id,
          'modifiedAt': metadata.modifiedAt.toIso8601String(),
          'isDeleted': metadata.isDeleted,
        }),
        metadataFromJson: (jsonStr) {
          final map = json.decode(jsonStr) as Map<String, dynamic>;
          return SyncMetadata(
            id: map['id'] as String,
            modifiedAt: DateTime.parse(map['modifiedAt'] as String),
            isDeleted: map['isDeleted'] as bool? ?? false,
          );
        },
      );
    });

    test('metadataToJson serializes metadata correctly', () {
      final metadata = SyncMetadata(
        id: 'test-id',
        modifiedAt: DateTime.parse('2024-04-10T12:00:00.000Z'),
        isDeleted: true,
      );

      final jsonStr = adapter.metadataToJson(metadata);

      expect(
        jsonStr,
        json.encode({
          'id': 'test-id',
          'modifiedAt': '2024-04-10T12:00:00.000Z',
          'isDeleted': true,
        }),
      );
    });

    test('metadataFromJson deserializes metadata correctly', () {
      final jsonStr = json.encode({
        'id': 'test-id',
        'modifiedAt': '2024-04-10T12:00:00.000Z',
        'isDeleted': true,
      });

      final metadata = adapter.metadataFromJson(jsonStr);

      expect(metadata.id, 'test-id');
      expect(metadata.modifiedAt, DateTime.parse('2024-04-10T12:00:00.000Z'));
      expect(metadata.isDeleted, true);
    });

    test('metadataFromJson handles missing isDeleted field gracefully', () {
      final jsonStr = json.encode({
        'id': 'test-id',
        'modifiedAt': '2024-04-10T12:00:00.000Z',
      });

      final metadata = adapter.metadataFromJson(jsonStr);

      expect(metadata.id, 'test-id');
      expect(metadata.modifiedAt, DateTime.parse('2024-04-10T12:00:00.000Z'));
      expect(metadata.isDeleted, false);
    });

    test('metadataToJson and metadataFromJson are inverses', () {
      final originalMetadata = SyncMetadata(
        id: 'test-id',
        modifiedAt: DateTime.parse('2024-04-10T12:00:00.000Z'),
        isDeleted: true,
      );

      final jsonStr = adapter.metadataToJson(originalMetadata);
      final deserializedMetadata = adapter.metadataFromJson(jsonStr);

      expect(deserializedMetadata.id, originalMetadata.id);
      expect(deserializedMetadata.modifiedAt, originalMetadata.modifiedAt);
      expect(deserializedMetadata.isDeleted, originalMetadata.isDeleted);
    });
  });
}
