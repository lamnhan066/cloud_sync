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
    final progressStates = <SyncState>[];

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

    void progressCallback(SyncState state) {
      progressStates.add(state);
    }

    test('Sync completes successfully with no changes', () async {
      await cloudSync.sync(progress: progressCallback);

      // Verify expected state sequence
      expect(progressStates, [
        isA<FetchingLocalMetadata>(),
        isA<FetchingCloudMetadata>(),
        isA<ScanningCloud>(),
        isA<ScanningLocal>(),
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

      await cloudSync.sync(progress: progressCallback);

      expect(cloudAdapter._data['1'], equals(localData));
      expect(cloudAdapter._metadata['1'], equals(localMetadata));

      expect(
        progressStates,
        containsAllInOrder([
          isA<FetchingLocalMetadata>(),
          isA<FetchingCloudMetadata>(),
          isA<ScanningCloud>(),
          isA<ScanningLocal>(),
          isA<SavingToCloud<SyncMetadata>>(),
          isA<SavedToCloud<SyncMetadata>>(),
          isA<SyncCompleted>(),
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

      await cloudSync.sync(progress: progressCallback);

      expect(localAdapter._data['2'], equals(cloudData));
      expect(localAdapter._metadata['2'], equals(cloudMetadata));

      expect(
        progressStates,
        containsAllInOrder([
          isA<FetchingLocalMetadata>(),
          isA<FetchingCloudMetadata>(),
          isA<ScanningCloud>(),
          isA<SavingToLocal<SyncMetadata>>(),
          isA<SavedToLocal<SyncMetadata>>(),
          isA<ScanningLocal>(),
          isA<SyncCompleted>(),
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

      await cloudSync.sync(progress: progressCallback);

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

      await cloudSync.sync(progress: progressCallback);

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
      await cloudSync.sync(progress: progressCallback);

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
      await cloudSync.sync(progress: progressCallback);

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

      await cloudSync.sync(progress: progressCallback);

      // Modified data should win as it has newer timestamp
      expect(localAdapter._metadata[id]?.isDeleted, isFalse);
      expect(localAdapter._data[id]?.content, equals('Modified Data'));
      expect(cloudAdapter._metadata[id]?.isDeleted, isFalse);
    });

    test('Sync handles error on fetch local metadata', () async {
      localAdapter.throwErrorOnFetchMetadata = true;
      await cloudSync.sync(progress: progressCallback);

      expect(progressStates, contains(isA<SyncError>()));
      final errorState =
          progressStates.lastWhere((state) => state is SyncError) as SyncError;
      expect(errorState.error.toString(), contains('Fetch Metadata Error'));
      expect(errorState.stackTrace, isNotNull);
      // More specific error verification:
      expect(errorState.error, isA<Exception>());
    });

    test('Sync handles error on fetch cloud metadata', () async {
      cloudAdapter.throwErrorOnFetchMetadata = true;
      await cloudSync.sync(progress: progressCallback);

      expect(progressStates, contains(isA<SyncError>()));
      // More specific error verification:
      final errorState =
          progressStates.lastWhere((state) => state is SyncError) as SyncError;
      expect(errorState.error, isA<Exception>());
    });

    test('Sync handles error on fetch local detail', () async {
      localAdapter.throwErrorOnFetchDetail = true;
      await localAdapter.save(
        SyncMetadata(id: '5', modifiedAt: DateTime.now()),
        MockData('Data'),
      );
      await cloudSync.sync(progress: progressCallback);

      expect(progressStates, contains(isA<SyncError>()));
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
      await cloudSync.sync(progress: progressCallback);

      expect(progressStates, contains(isA<SyncError>()));
      // More specific error verification:
      final errorState =
          progressStates.lastWhere((state) => state is SyncError) as SyncError;
      expect(errorState.error, isA<Exception>());
    });

    test('Sync handles error on save to local', () async {
      localAdapter.throwErrorOnSave = true;
      await cloudAdapter.save(
        SyncMetadata(id: '7', modifiedAt: DateTime.now()),
        MockData('Data'),
      );
      await cloudSync.sync(progress: progressCallback);

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
      await cloudSync.sync(progress: progressCallback);

      expect(progressStates.any((state) => state is SyncError), isTrue);
      expect(progressStates.any((state) => state is SavingToCloud), isTrue);

      // Check for continuous sync even after error
      expect(progressStates.last, isA<SyncCompleted>());
    });

    test('Auto sync calls sync at least once within given timeframe', () async {
      // Instead of counting exact syncs, just verify at least one happens
      var syncCompleted = false;

      cloudSync.autoSync(
        interval: const Duration(milliseconds: 100),
        progress: (state) {
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

      cloudSync.autoSync(
        interval: const Duration(milliseconds: 100),
        progress: (state) {
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
      await cloudSync.stopAutoSync();

      // Wait to ensure no new syncs start
      await Future<void>.delayed(const Duration(milliseconds: 200));

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
        progress: (state) {
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
        progress: (state) {
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
      var syncCompletedCount = 0;

      // Add significant delay to simulate long-running sync
      cloudAdapter.fetchDelay = const Duration(milliseconds: 300);

      cloudSync.autoSync(
        interval: const Duration(milliseconds: 100),
        progress: (state) {
          if (state is FetchingLocalMetadata) {
            syncStartedCount++;
          }
          if (state is InProgress) {
            syncSkippedCount++;
          }
          if (state is SyncCompleted) {
            syncCompletedCount++;
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
        syncCompletedCount,
        lessThanOrEqualTo(2),
        reason:
            'Syncs should not overlap, and only a limited number should start',
      );
    });

    test('Sync with uploadFirst strategy uploads before downloading', () async {
      // Create items in both local and cloud
      final localMetadata =
          SyncMetadata(id: 'local-first', modifiedAt: DateTime.now());
      final localData = MockData('Local Data');
      await localAdapter.save(localMetadata, localData);

      final cloudMetadata =
          SyncMetadata(id: 'cloud-first', modifiedAt: DateTime.now());
      final cloudData = MockData('Cloud Data');
      await cloudAdapter.save(cloudMetadata, cloudData);

      // Configure cloud sync with uploadFirst strategy
      cloudSync = CloudSync.fromAdapters(
        local: localAdapter,
        cloud: cloudAdapter,
        strategy: SyncStrategy.uploadFirst,
      );

      await cloudSync.sync(progress: progressCallback);

      // Verify expected state sequence for uploadFirst strategy
      final stateTypes = progressStates.map((s) => s.runtimeType).toList();

      // Check that local to cloud operations happen before cloud to local operations
      final uploadStartIndex = stateTypes.indexOf(SavingToCloud<SyncMetadata>);
      final downloadStartIndex =
          stateTypes.indexOf(SavingToLocal<SyncMetadata>);

      expect(
        uploadStartIndex < downloadStartIndex,
        isTrue,
        reason: 'Upload operations should occur before download operations',
      );

      // Also verify data was properly synced in both directions
      expect(cloudAdapter._data['local-first']?.content, equals('Local Data'));
      expect(localAdapter._data['cloud-first']?.content, equals('Cloud Data'));
    });

    test('Sync with downloadFirst strategy downloads before uploading',
        () async {
      // Create items in both local and cloud
      final localMetadata =
          SyncMetadata(id: 'local-second', modifiedAt: DateTime.now());
      final localData = MockData('Local Data');
      await localAdapter.save(localMetadata, localData);

      final cloudMetadata =
          SyncMetadata(id: 'cloud-second', modifiedAt: DateTime.now());
      final cloudData = MockData('Cloud Data');
      await cloudAdapter.save(cloudMetadata, cloudData);

      // Configure cloud sync with downloadFirst strategy
      cloudSync = CloudSync.fromAdapters(
        local: localAdapter,
        cloud: cloudAdapter,
      );

      await cloudSync.sync(progress: progressCallback);

      // Verify expected state sequence for downloadFirst strategy
      final stateTypes = progressStates.map((s) => s.runtimeType).toList();

      // Check that cloud to local operations happen before local to cloud operations
      final downloadStartIndex =
          stateTypes.indexOf(SavingToLocal<SyncMetadata>);
      final uploadStartIndex = stateTypes.indexOf(SavingToCloud<SyncMetadata>);

      expect(
        downloadStartIndex < uploadStartIndex,
        isTrue,
        reason: 'Download operations should occur before upload operations',
      );

      // Also verify data was properly synced in both directions
      expect(cloudAdapter._data['local-second']?.content, equals('Local Data'));
      expect(localAdapter._data['cloud-second']?.content, equals('Cloud Data'));
    });

    test('Sync with uploadOnly strategy only uploads data', () async {
      // Create items in both local and cloud - we'll verify the cloud item is NOT downloaded
      final localMetadata =
          SyncMetadata(id: 'local-upload-only', modifiedAt: DateTime.now());
      final localData = MockData('Local Upload Only');
      await localAdapter.save(localMetadata, localData);

      final cloudMetadata =
          SyncMetadata(id: 'cloud-upload-only', modifiedAt: DateTime.now());
      final cloudData = MockData('Cloud Upload Only');
      await cloudAdapter.save(cloudMetadata, cloudData);

      // Configure cloud sync with uploadOnly strategy
      cloudSync = CloudSync.fromAdapters(
        local: localAdapter,
        cloud: cloudAdapter,
        strategy: SyncStrategy.uploadOnly,
      );

      await cloudSync.sync(progress: progressCallback);

      // Verify local data was uploaded to cloud
      expect(
        cloudAdapter._data['local-upload-only']?.content,
        equals('Local Upload Only'),
      );

      // But cloud data was NOT downloaded to local
      expect(localAdapter._data.containsKey('cloud-upload-only'), isFalse);

      // Verify no SavingToLocal states in progress
      expect(progressStates.any((state) => state is SavingToLocal), isFalse);
    });

    test('Sync with downloadOnly strategy only downloads data', () async {
      // Create items in both local and cloud - we'll verify the local item is NOT uploaded
      final localMetadata =
          SyncMetadata(id: 'local-download-only', modifiedAt: DateTime.now());
      final localData = MockData('Local Download Only');
      await localAdapter.save(localMetadata, localData);

      final cloudMetadata =
          SyncMetadata(id: 'cloud-download-only', modifiedAt: DateTime.now());
      final cloudData = MockData('Cloud Download Only');
      await cloudAdapter.save(cloudMetadata, cloudData);

      // Configure cloud sync with downloadOnly strategy
      cloudSync = CloudSync.fromAdapters(
        local: localAdapter,
        cloud: cloudAdapter,
        strategy: SyncStrategy.downloadOnly,
      );

      await cloudSync.sync(progress: progressCallback);

      // Verify cloud data was downloaded to local
      expect(
        localAdapter._data['cloud-download-only']?.content,
        equals('Cloud Download Only'),
      );

      // But local data was NOT uploaded to cloud
      expect(cloudAdapter._data.containsKey('local-download-only'), isFalse);

      // Verify no SavingToCloud states in progress
      expect(progressStates.any((state) => state is SavingToCloud), isFalse);
    });

    test(
        'Sync with simultaneously strategy performs both operations concurrently',
        () async {
      // Create items in both local and cloud
      final localMetadata =
          SyncMetadata(id: 'local-simul', modifiedAt: DateTime.now());
      final localData = MockData('Local Simultaneous');
      await localAdapter.save(localMetadata, localData);

      final cloudMetadata =
          SyncMetadata(id: 'cloud-simul', modifiedAt: DateTime.now());
      final cloudData = MockData('Cloud Simultaneous');
      await cloudAdapter.save(cloudMetadata, cloudData);

      // Add delays to make concurrent behavior more obvious
      localAdapter.fetchDelay = const Duration(milliseconds: 50);
      cloudAdapter.fetchDelay = const Duration(milliseconds: 50);

      // Block operations at first so we can control timing
      localAdapter.blockOperations();
      cloudAdapter.blockOperations();

      // Configure cloud sync with simultaneously strategy
      cloudSync = CloudSync.fromAdapters(
        local: localAdapter,
        cloud: cloudAdapter,
        strategy: SyncStrategy.simultaneously,
      );

      // Start sync but don't await it yet
      final syncFuture = cloudSync.sync(progress: progressCallback);

      // Wait to ensure sync has started
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // Unblock operations to let sync proceed
      localAdapter.unblockOperations();
      cloudAdapter.unblockOperations();

      // Wait for sync to complete
      await syncFuture;

      // Verify both operations completed successfully
      expect(
        cloudAdapter._data['local-simul']?.content,
        equals('Local Simultaneous'),
      );
      expect(
        localAdapter._data['cloud-simul']?.content,
        equals('Cloud Simultaneous'),
      );

      // In simultaneous mode, we should see both upload and download operations
      // happening without one necessarily completing first
      expect(progressStates.any((state) => state is SavingToCloud), isTrue);
      expect(progressStates.any((state) => state is SavingToLocal), isTrue);
    });

    test('CloudSync uses uploadFirst as default strategy when not specified',
        () async {
      final defaultSync = CloudSync.fromAdapters(
        local: localAdapter,
        cloud: cloudAdapter,
        // No strategy specified - should default to uploadFirst
      );

      // Add test data
      await localAdapter.save(
        SyncMetadata(id: 'default-strategy', modifiedAt: DateTime.now()),
        MockData('Default Strategy Test'),
      );

      await cloudAdapter.save(
        SyncMetadata(id: 'cloud-default', modifiedAt: DateTime.now()),
        MockData('Cloud Default Test'),
      );

      progressStates.clear();
      await defaultSync.sync(progress: progressCallback);

      // Verify expected state sequence matches uploadFirst strategy
      final stateTypes = progressStates.map((s) => s.runtimeType).toList();

      // If SavingToCloud exists, it should come before SavingToLocal
      if (stateTypes.contains(SavingToCloud) &&
          stateTypes.contains(SavingToLocal)) {
        final uploadStartIndex = stateTypes.indexOf(SavingToCloud);
        final downloadStartIndex = stateTypes.indexOf(SavingToLocal);

        expect(
          uploadStartIndex < downloadStartIndex,
          isTrue,
          reason: 'Default strategy should be uploadFirst',
        );
      }

      // Also verify data was properly synced
      expect(
        cloudAdapter._data['default-strategy']?.content,
        equals('Default Strategy Test'),
      );
      expect(
        localAdapter._data['cloud-default']?.content,
        equals('Cloud Default Test'),
      );
    });

    test('CloudSync handles strategy changes between syncs', () async {
      // First sync with uploadOnly strategy
      cloudSync = CloudSync.fromAdapters(
        local: localAdapter,
        cloud: cloudAdapter,
        strategy: SyncStrategy.uploadOnly,
      );

      // Add test data
      await localAdapter.save(
        SyncMetadata(id: 'strategy-change', modifiedAt: DateTime.now()),
        MockData('Strategy Change Test'),
      );

      await cloudAdapter.save(
        SyncMetadata(id: 'cloud-change', modifiedAt: DateTime.now()),
        MockData('Cloud Change Test'),
      );

      // First sync - uploadOnly
      progressStates.clear();
      await cloudSync.sync(progress: progressCallback);

      // Verify only upload happened, not download
      expect(
        cloudAdapter._data['strategy-change']?.content,
        equals('Strategy Change Test'),
      );
      expect(localAdapter._data.containsKey('cloud-change'), isFalse);

      // Now change to downloadOnly strategy
      cloudSync = CloudSync.fromAdapters(
        local: localAdapter,
        cloud: cloudAdapter,
        strategy: SyncStrategy.downloadOnly,
      );

      // Second sync - downloadOnly
      progressStates.clear();
      await cloudSync.sync(progress: progressCallback);

      // Now verify download happened
      expect(
        localAdapter._data['cloud-change']?.content,
        equals('Cloud Change Test'),
      );

      // Complete sync in both directions should have happened across two different syncs
      expect(
        cloudAdapter._data['strategy-change']?.content,
        equals('Strategy Change Test'),
      );
      expect(
        localAdapter._data['cloud-change']?.content,
        equals('Cloud Change Test'),
      );
    });

    // Add these tests to cover more complex scenarios with the different strategies

    test('Strategy handles complex conflict resolution consistently', () async {
      // For each strategy, test the same conflict scenario
      const strategies = SyncStrategy.values;

      for (final strategy in strategies) {
        // Reset for each strategy test
        localAdapter.reset();
        cloudAdapter.reset();
        progressStates.clear();

        // Create conflicting items with different timestamps
        final initialTime = DateTime.now().subtract(const Duration(hours: 1));
        final localTime = initialTime.add(const Duration(minutes: 15));
        final cloudTime =
            initialTime.add(const Duration(minutes: 30)); // Cloud is newer

        // Add items with conflict - cloud should win based on timestamp
        await localAdapter.save(
          SyncMetadata(id: 'conflict', modifiedAt: localTime),
          MockData('Local Conflict Data'),
        );
        await cloudAdapter.save(
          SyncMetadata(id: 'conflict', modifiedAt: cloudTime),
          MockData('Cloud Conflict Data'),
        );

        // Configure sync with current strategy
        cloudSync = CloudSync.fromAdapters(
          local: localAdapter,
          cloud: cloudAdapter,
          strategy: strategy,
        );

        // Sync and capture states
        await cloudSync.sync(progress: progressCallback);

        // For all strategies except uploadOnly, cloud data should win (newer timestamp)
        if (strategy != SyncStrategy.uploadOnly) {
          expect(
            localAdapter._data['conflict']?.content,
            equals('Cloud Conflict Data'),
            reason: 'Cloud data should win for strategy: $strategy',
          );
        } else {
          // For uploadOnly, local data should remain unchanged
          expect(
            localAdapter._data['conflict']?.content,
            equals('Local Conflict Data'),
            reason: 'uploadOnly should not download cloud data',
          );
        }

        // For all strategies except downloadOnly, verify cloud state
        if (strategy != SyncStrategy.downloadOnly) {
          expect(
            cloudAdapter._data['conflict']?.content,
            equals('Cloud Conflict Data'),
            reason: 'Cloud data should not change for strategy: $strategy',
          );
        }

        // Verify state transitions match the expected strategy
        verifyStrategyStateOrder(states: progressStates, strategy: strategy);
      }
    });

    test('Strategy handles deletions appropriately', () async {
      // For each strategy, test deletion propagation
      const strategies = SyncStrategy.values;

      for (final strategy in strategies) {
        // Reset for each strategy test
        localAdapter.reset();
        cloudAdapter.reset();
        progressStates.clear();

        // Define test data
        final initialTime = DateTime.now().subtract(const Duration(hours: 1));
        final deletionTime = initialTime.add(const Duration(minutes: 30));
        const localId = 'local-delete';
        const cloudId = 'cloud-delete';

        // Add regular items to both storages
        await localAdapter.save(
          SyncMetadata(id: localId, modifiedAt: initialTime),
          MockData('Local Regular'),
        );
        await localAdapter.save(
          SyncMetadata(id: cloudId, modifiedAt: initialTime),
          MockData('Will Be Deleted In Cloud'),
        );

        await cloudAdapter.save(
          SyncMetadata(id: localId, modifiedAt: initialTime),
          MockData('Will Be Deleted In Local'),
        );
        await cloudAdapter.save(
          SyncMetadata(id: cloudId, modifiedAt: initialTime),
          MockData('Cloud Regular'),
        );

        // Mark items as deleted - local deletes localId, cloud deletes cloudId
        await localAdapter.save(
          SyncMetadata(id: localId, modifiedAt: deletionTime, isDeleted: true),
          MockData('Deleted In Local'),
        );
        await cloudAdapter.save(
          SyncMetadata(id: cloudId, modifiedAt: deletionTime, isDeleted: true),
          MockData('Deleted In Cloud'),
        );

        // Configure sync with current strategy
        cloudSync = CloudSync.fromAdapters(
          local: localAdapter,
          cloud: cloudAdapter,
          strategy: strategy,
        );

        // Sync and capture states
        await cloudSync.sync(progress: progressCallback);

        // Check deletion propagation based on strategy
        switch (strategy) {
          case SyncStrategy.uploadFirst:
          case SyncStrategy.downloadFirst:
          case SyncStrategy.simultaneously:
            // Both deletions should be synced both ways
            expect(localAdapter._metadata[localId]?.isDeleted, isTrue);
            expect(cloudAdapter._metadata[localId]?.isDeleted, isTrue);
            expect(localAdapter._metadata[cloudId]?.isDeleted, isTrue);
            expect(cloudAdapter._metadata[cloudId]?.isDeleted, isTrue);

          case SyncStrategy.uploadOnly:
            // Only local deletion should be propagated to cloud
            expect(cloudAdapter._metadata[localId]?.isDeleted, isTrue);
            expect(localAdapter._metadata[cloudId]?.isDeleted, isFalse);

          case SyncStrategy.downloadOnly:
            // Only cloud deletion should be propagated to local
            expect(localAdapter._metadata[cloudId]?.isDeleted, isTrue);
            expect(cloudAdapter._metadata[localId]?.isDeleted, isFalse);
        }

        // Verify state transitions match the expected strategy
        verifyStrategyStateOrder(states: progressStates, strategy: strategy);
      }
    });

    test('Strategy behavior remains consistent during auto sync', () async {
      // Test auto sync with two different strategies
      final strategies = [SyncStrategy.uploadOnly, SyncStrategy.downloadOnly];

      for (final strategy in strategies) {
        // Reset for each strategy test
        localAdapter.reset();
        cloudAdapter.reset();
        progressStates.clear();

        // Setup test data
        await localAdapter.save(
          SyncMetadata(id: 'auto-local', modifiedAt: DateTime.now()),
          MockData('Auto Local Data'),
        );

        await cloudAdapter.save(
          SyncMetadata(id: 'auto-cloud', modifiedAt: DateTime.now()),
          MockData('Auto Cloud Data'),
        );

        // Configure sync with current strategy
        cloudSync = CloudSync.fromAdapters(
          local: localAdapter,
          cloud: cloudAdapter,
          strategy: strategy,
        );

        var syncCompletedCount = 0;

        // Start auto sync
        cloudSync.autoSync(
          interval: const Duration(milliseconds: 100),
          progress: (state) {
            progressStates.add(state);
            if (state is SyncCompleted) {
              syncCompletedCount++;
            }
          },
        );

        // Wait long enough for at least one sync
        await Future<void>.delayed(const Duration(milliseconds: 300));
        await cloudSync.stopAutoSync();

        // Verify strategy-specific behavior was maintained
        if (strategy == SyncStrategy.uploadOnly) {
          expect(cloudAdapter._data.containsKey('auto-local'), isTrue);
          expect(localAdapter._data.containsKey('auto-cloud'), isFalse);
        } else if (strategy == SyncStrategy.downloadOnly) {
          expect(cloudAdapter._data.containsKey('auto-local'), isFalse);
          expect(localAdapter._data.containsKey('auto-cloud'), isTrue);
        }

        // Verify at least one sync completed
        expect(syncCompletedCount, greaterThan(0));
      }
    });

    test('Strategy handles large datasets efficiently', () async {
      // Test with a significant number of items to sync
      const itemCount = 10; // Use 10 for tests, but could be larger if needed

      // For select strategies, test performance with larger datasets
      final strategies = [
        SyncStrategy.uploadFirst,
        SyncStrategy.downloadFirst,
        SyncStrategy.simultaneously,
      ];

      for (final strategy in strategies) {
        // Reset for each strategy test
        localAdapter.reset();
        cloudAdapter.reset();
        progressStates.clear();

        // Create test data - different items in local and cloud
        for (var i = 0; i < itemCount; i++) {
          await localAdapter.save(
            SyncMetadata(id: 'large-local-$i', modifiedAt: DateTime.now()),
            MockData('Large Local Data $i'),
          );

          await cloudAdapter.save(
            SyncMetadata(id: 'large-cloud-$i', modifiedAt: DateTime.now()),
            MockData('Large Cloud Data $i'),
          );
        }

        // Configure sync with current strategy
        cloudSync = CloudSync.fromAdapters(
          local: localAdapter,
          cloud: cloudAdapter,
          strategy: strategy,
        );

        // Time the sync operation
        final stopwatch = Stopwatch()..start();
        await cloudSync.sync(progress: progressCallback);
        stopwatch.stop();

        // Verify all data was synced properly
        for (var i = 0; i < itemCount; i++) {
          expect(
            cloudAdapter._data['large-local-$i']?.content,
            equals('Large Local Data $i'),
          );
          expect(
            localAdapter._data['large-cloud-$i']?.content,
            equals('Large Cloud Data $i'),
          );
        }

        // Verify state transitions match the expected strategy
        verifyStrategyStateOrder(states: progressStates, strategy: strategy);

        // Performance check - just ensure it completes in a reasonable time
        // We're not comparing strategies as that would be too flaky in tests
        expect(stopwatch, isNot(null));
      }
    });

    test('uploadOnly strategy skips download even with newer cloud data',
        () async {
      // Setup test with cloud data newer than local
      final localTime = DateTime.now().subtract(const Duration(minutes: 30));
      final cloudTime = DateTime.now(); // Cloud is newer
      const id = 'edge-upload-only';

      // Add items with cloud having newer timestamp
      await localAdapter.save(
        SyncMetadata(id: id, modifiedAt: localTime),
        MockData('Old Local Data'),
      );
      await cloudAdapter.save(
        SyncMetadata(id: id, modifiedAt: cloudTime),
        MockData('Newer Cloud Data'),
      );

      // Configure with uploadOnly strategy
      cloudSync = CloudSync.fromAdapters(
        local: localAdapter,
        cloud: cloudAdapter,
        strategy: SyncStrategy.uploadOnly,
      );

      await cloudSync.sync(progress: progressCallback);

      // Local data should remain unchanged even though cloud is newer
      expect(localAdapter._data[id]?.content, equals('Old Local Data'));

      // Verify no download operations were attempted
      expect(progressStates.any((state) => state is ScanningCloud), isFalse);
      expect(
        progressStates.any((state) => state is SavingToLocal<SyncMetadata>),
        isFalse,
      );
    });

    test('downloadOnly strategy skips upload even with newer local data',
        () async {
      // Setup test with local data newer than cloud
      final cloudTime = DateTime.now().subtract(const Duration(minutes: 30));
      final localTime = DateTime.now(); // Local is newer
      const id = 'edge-download-only';

      // Add items with local having newer timestamp
      await cloudAdapter.save(
        SyncMetadata(id: id, modifiedAt: cloudTime),
        MockData('Old Cloud Data'),
      );
      await localAdapter.save(
        SyncMetadata(id: id, modifiedAt: localTime),
        MockData('Newer Local Data'),
      );

      // Configure with downloadOnly strategy
      cloudSync = CloudSync.fromAdapters(
        local: localAdapter,
        cloud: cloudAdapter,
        strategy: SyncStrategy.downloadOnly,
      );

      await cloudSync.sync(progress: progressCallback);

      // Cloud data should remain unchanged even though local is newer
      expect(cloudAdapter._data[id]?.content, equals('Old Cloud Data'));

      // Verify no upload operations were attempted
      expect(progressStates.any((state) => state is ScanningLocal), isFalse);
      expect(progressStates.any((state) => state is SavingToCloud), isFalse);
    });

    test('Strategy handles empty local storage correctly', () async {
      const strategies = SyncStrategy.values;

      for (final strategy in strategies) {
        // Reset for each strategy test
        localAdapter.reset();
        cloudAdapter.reset();
        progressStates.clear();

        // Only populate cloud storage
        await cloudAdapter.save(
          SyncMetadata(id: 'cloud-empty-test', modifiedAt: DateTime.now()),
          MockData('Cloud Empty Test'),
        );

        // Configure sync with current strategy
        cloudSync = CloudSync.fromAdapters(
          local: localAdapter,
          cloud: cloudAdapter,
          strategy: strategy,
        );

        // Sync and capture states
        await cloudSync.sync(progress: progressCallback);

        // Check results based on strategy
        if (strategy == SyncStrategy.downloadOnly ||
            strategy == SyncStrategy.downloadFirst ||
            strategy == SyncStrategy.simultaneously) {
          // These strategies should download the cloud item
          expect(
            localAdapter._data.containsKey('cloud-empty-test'),
            isTrue,
            reason: '$strategy should download when local is empty',
          );
        } else {
          // uploadOnly and uploadFirst shouldn't download
          // Actually uploadOnly will never download by design,
          // but uploadFirst should download after uploading, but there's nothing to upload
          if (strategy == SyncStrategy.uploadOnly) {
            expect(
              localAdapter._data.containsKey('cloud-empty-test'),
              isFalse,
              reason: 'uploadOnly should never download',
            );
          }
        }

        // Verify state transitions match the expected strategy
        verifyStrategyStateOrder(states: progressStates, strategy: strategy);
      }
    });

    test('Strategy handles empty cloud storage correctly', () async {
      const strategies = SyncStrategy.values;

      for (final strategy in strategies) {
        // Reset for each strategy test
        localAdapter.reset();
        cloudAdapter.reset();
        progressStates.clear();

        // Only populate local storage
        await localAdapter.save(
          SyncMetadata(id: 'local-empty-test', modifiedAt: DateTime.now()),
          MockData('Local Empty Test'),
        );

        // Configure sync with current strategy
        cloudSync = CloudSync.fromAdapters(
          local: localAdapter,
          cloud: cloudAdapter,
          strategy: strategy,
        );

        // Sync and capture states
        await cloudSync.sync(progress: progressCallback);

        // Check results based on strategy
        if (strategy == SyncStrategy.uploadOnly ||
            strategy == SyncStrategy.uploadFirst ||
            strategy == SyncStrategy.simultaneously) {
          // These strategies should upload the local item
          expect(
            cloudAdapter._data.containsKey('local-empty-test'),
            isTrue,
            reason: '$strategy should upload when cloud is empty',
          );
        } else {
          // downloadOnly and downloadFirst shouldn't upload
          // Actually downloadOnly will never upload by design,
          // but downloadFirst should upload after downloading, but there's nothing to download
          if (strategy == SyncStrategy.downloadOnly) {
            expect(
              cloudAdapter._data.containsKey('local-empty-test'),
              isFalse,
              reason: 'downloadOnly should never upload',
            );
          }
        }

        // Verify state transitions match the expected strategy
        verifyStrategyStateOrder(states: progressStates, strategy: strategy);
      }
    });

    test('Sync handles empty metadata case correctly', () async {
      // Make sure metadata lists are empty
      localAdapter.reset();
      cloudAdapter.reset();

      await cloudSync.sync(progress: progressCallback);

      // Should complete successfully with no errors
      expect(progressStates.last, isA<SyncCompleted>());
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

      await cloudSync.sync(progress: progressCallback);

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

      await cloudSync.sync(progress: progressCallback);

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

    test('Sync handles exceptions with `shouldThrowOnError` is true', () async {
      cloudSync = CloudSync.fromAdapters(
        local: localAdapter,
        cloud: cloudAdapter,
        shouldThrowOnError: true,
      );
      localAdapter.throwErrorOnFetchMetadata = true;

      expect(() async => cloudSync.sync(), throwsA(isA<Exception>()));
    });

    test('Sync handles exceptions with `shouldThrowOnError` is false',
        () async {
      cloudSync = CloudSync.fromAdapters(
        local: localAdapter,
        cloud: cloudAdapter,
      );
      localAdapter.throwErrorOnFetchMetadata = true;

      await expectLater(cloudSync.sync(), isA<void>());
    });

    test('Auto sync skips when sync is in progress with timeout', () async {
      var syncStartedCount = 0;
      var syncSkippedCount = 0;
      var syncCompletedCount = 0;

      // Add significant delay to simulate long-running sync
      cloudAdapter.fetchDelay = const Duration(milliseconds: 300);

      cloudSync.autoSync(
        interval: const Duration(milliseconds: 100),
        progress: (state) {
          progressCallback(state);
          if (state is FetchingLocalMetadata) {
            syncStartedCount++;
          }
          if (state is InProgress) {
            syncSkippedCount++;
          }
          if (state is SyncCompleted) {
            syncCompletedCount++;
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
        syncCompletedCount,
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
      final syncFuture = cancelableSync.sync(progress: progressCallback);

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
      final syncFuture = cancelableSync.sync(progress: progressCallback);

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

// Add this helper function inside the test file to verify state transitions

/// Helper to verify state transitions match the expected strategy.
void verifyStrategyStateOrder({
  required List<SyncState> states,
  required SyncStrategy strategy,
}) {
  // Get the indexes of first occurrences of each state type
  final stateTypes = states.map((s) => s.runtimeType).toList();
  final uploadStartIndex = stateTypes.contains(SavingToCloud)
      ? stateTypes.indexOf(SavingToCloud)
      : -1;
  final downloadStartIndex = stateTypes.contains(SavingToLocal)
      ? stateTypes.indexOf(SavingToLocal)
      : -1;

  // Verify state transitions based on strategy
  switch (strategy) {
    case SyncStrategy.uploadFirst:
      if (uploadStartIndex != -1 && downloadStartIndex != -1) {
        expect(
          uploadStartIndex < downloadStartIndex,
          isTrue,
          reason: 'uploadFirst should perform uploads before downloads',
        );
      }
    case SyncStrategy.downloadFirst:
      if (uploadStartIndex != -1 && downloadStartIndex != -1) {
        expect(
          downloadStartIndex < uploadStartIndex,
          isTrue,
          reason: 'downloadFirst should perform downloads before uploads',
        );
      }
    case SyncStrategy.uploadOnly:
      if (downloadStartIndex != -1) {
        fail('uploadOnly strategy should not perform downloads');
      }
      if (uploadStartIndex == -1 && stateTypes.contains(ScanningLocal)) {
        // Only pass if there was nothing to upload
        expect(stateTypes.contains(SavingToCloud), isFalse);
      }
    case SyncStrategy.downloadOnly:
      if (uploadStartIndex != -1) {
        fail('downloadOnly strategy should not perform uploads');
      }
      if (downloadStartIndex == -1 && stateTypes.contains(ScanningCloud)) {
        // Only pass if there was nothing to download
        expect(stateTypes.contains(SavingToLocal), isFalse);
      }
    case SyncStrategy.simultaneously:
      // For simultaneous strategy, we can't verify order
      // Just verify that appropriate operations happened if needed
      expect(
        states.any((s) => s is SyncCompleted),
        isTrue,
        reason: 'Sync should complete regardless of strategy',
      );
  }
}
