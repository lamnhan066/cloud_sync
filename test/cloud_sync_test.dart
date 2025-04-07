import 'package:cloud_sync/src/cloud_sync.dart';
import 'package:cloud_sync/src/models/sync_metadata.dart';
import 'package:cloud_sync/src/models/sync_state.dart';
import 'package:test/test.dart';

void main() {
  late CloudSync cloudSync;
  late List<SyncMetadata> localMetadataList;
  late List<SyncMetadata> cloudMetadataList;
  late Map<String, List<int>> localDetails;
  late Map<String, List<int>> cloudDetails;

  setUp(() {
    localMetadataList = [
      SyncMetadata(
        id: '1',
        modifiedAt: DateTime(2023, 1, 1),
      ),
      SyncMetadata(
        id: '2',
        modifiedAt: DateTime(2023, 1, 2),
      ),
    ];
    cloudMetadataList = [
      SyncMetadata(
        id: '2',
        modifiedAt: DateTime(2023, 1, 1),
      ),
      SyncMetadata(
        id: '3',
        modifiedAt: DateTime(2023, 1, 3),
      ),
    ];
    localDetails = {
      '1': [108, 111, 99, 97, 108, 70, 105, 108, 101, 49],
      '2': [108, 111, 99, 97, 108, 70, 105, 108, 101, 50],
    };
    cloudDetails = {
      '2': [99, 108, 111, 117, 100, 70, 105, 108, 101, 50],
      '3': [99, 108, 111, 117, 100, 70, 105, 108, 101, 51],
    };

    cloudSync = CloudSync(
      fetchLocalMetadataList: () async => localMetadataList,
      fetchCloudMetadataList: () async => cloudMetadataList,
      fetchLocalDetail: (metadata) async => localDetails[metadata.id] ?? [],
      fetchCloudDetail: (metadata) async => cloudDetails[metadata.id] ?? [],
      saveToCloud: (metadata, detail) async {
        cloudMetadataList.removeWhere((m) => m.id == metadata.id);
        cloudMetadataList.add(metadata);
        cloudDetails[metadata.id] = detail;
      },
      saveToLocal: (metadata, detail) async {
        localMetadataList.removeWhere((m) => m.id == metadata.id);
        localMetadataList.add(metadata);
        localDetails[metadata.id] = detail;
      },
    );
  });

  group('sync', () {
    test('sync should synchronize missing or outdated details to the cloud',
        () async {
      final progressStates = <SyncState>[];
      await cloudSync.sync(progressCallback: progressStates.add);

      expect(progressStates, contains(isA<SavingToCloud>()));
      expect(progressStates, contains(isA<SyncCompleted>()));
      expect(cloudDetails.containsKey('1'), isTrue);
      expect(cloudDetails['1'], equals(localDetails['1']));
    });

    test(
        'sync should synchronize missing or outdated details to the local storage',
        () async {
      final progressStates = <SyncState>[];
      await cloudSync.sync(progressCallback: progressStates.add);

      expect(progressStates, contains(isA<SavingToLocal>()));
      expect(progressStates, contains(isA<SyncCompleted>()));
      expect(localDetails.containsKey('3'), isTrue);
      expect(localDetails['3'], equals(cloudDetails['3']));
    });

    test('sync should not run if already in progress', () async {
      cloudSync.sync(progressCallback: (_) {});
      final progressStates = <SyncState>[];
      await cloudSync.sync(progressCallback: progressStates.add);

      expect(progressStates, contains(isA<AlreadyInProgress>()));
    });

    test('sync should handle errors during synchronization', () async {
      cloudSync = CloudSync(
        fetchLocalMetadataList: () async => throw Exception('Test error'),
        fetchCloudMetadataList: () async => cloudMetadataList,
        fetchLocalDetail: (metadata) async => localDetails[metadata.id]!,
        fetchCloudDetail: (metadata) async => cloudDetails[metadata.id]!,
        saveToLocal: (metadata, detail) async {},
        saveToCloud: (metadata, detail) async {},
      );

      final progressStates = <SyncState>[];
      await cloudSync.sync(progressCallback: progressStates.add);

      expect(progressStates, contains(isA<SyncError>()));
    });

    test('sync should handle errors during synchronization', () async {
      cloudSync = CloudSync(
        fetchLocalMetadataList: () async => throw Exception('Test error'),
        fetchCloudMetadataList: () async => cloudMetadataList,
        fetchLocalDetail: (metadata) async => localDetails[metadata.id]!,
        fetchCloudDetail: (metadata) async => cloudDetails[metadata.id]!,
        saveToLocal: (metadata, detail) async {},
        saveToCloud: (metadata, detail) async {},
      );

      await expectLater(
        () => cloudSync.sync(),
        throwsException,
      );
    });

    test('sync should skip details that are already up to date', () async {
      localMetadataList = [
        SyncMetadata(
          id: '1',
          modifiedAt: DateTime(2023, 1, 1),
        ),
      ];
      cloudMetadataList = [
        SyncMetadata(
          id: '1',
          modifiedAt: DateTime(2023, 1, 1),
        ),
      ];
      localDetails = {
        '1': [115, 97, 109, 101, 70, 105, 108, 101],
      };
      cloudDetails = {
        '1': [115, 97, 109, 101, 70, 105, 108, 101],
      };

      final progressStates = <SyncState>[];
      await cloudSync.sync(progressCallback: progressStates.add);

      expect(progressStates, isNot(contains(isA<SavingToLocal>())));
      expect(progressStates, isNot(contains(isA<SavingToCloud>())));
      expect(progressStates, contains(isA<SyncCompleted>()));
    });

    test('sync should handle two consecutive sync operations', () async {
      final firstSyncProgressStates = <SyncState>[];
      final secondSyncProgressStates = <SyncState>[];

      await cloudSync.sync(progressCallback: firstSyncProgressStates.add);
      await cloudSync.sync(progressCallback: secondSyncProgressStates.add);

      expect(firstSyncProgressStates, contains(isA<SyncCompleted>()));
      expect(secondSyncProgressStates, contains(isA<SyncCompleted>()));
      expect(secondSyncProgressStates, isNot(contains(isA<SavingToLocal>())));
      expect(secondSyncProgressStates, isNot(contains(isA<SavingToCloud>())));
    });

    test('sync should handle multiple details with different states', () async {
      localMetadataList.add(SyncMetadata(
        id: '4',
        modifiedAt: DateTime(2023, 1, 4),
      ));
      localDetails['4'] = [108, 111, 99, 97, 108, 70, 105, 108, 101, 52];

      final progressStates = <SyncState>[];
      await cloudSync.sync(progressCallback: progressStates.add);

      expect(progressStates, contains(isA<SavingToCloud>()));
      expect(progressStates, contains(isA<SavingToLocal>()));
      expect(progressStates, contains(isA<SyncCompleted>()));
      expect(cloudDetails.containsKey('4'), isTrue);
      expect(cloudDetails['4'], equals(localDetails['4']));
    });

    test('sync should skip syncing with empty data', () async {
      localMetadataList.clear();
      cloudMetadataList.clear();
      localDetails.clear();
      cloudDetails.clear();

      final progressStates = <SyncState>[];
      await cloudSync.sync(progressCallback: progressStates.add);

      expect(progressStates, contains(isA<SyncCompleted>()));
      expect(localDetails.isEmpty, isTrue);
      expect(cloudDetails.isEmpty, isTrue);
    });

    test(
        'sync should only update metadata if it is modified but content is the same',
        () async {
      localMetadataList = [
        SyncMetadata(id: '1', modifiedAt: DateTime(2023, 2, 1)),
      ];
      cloudMetadataList = [
        SyncMetadata(id: '1', modifiedAt: DateTime(2023, 1, 1)),
      ];
      localDetails = {
        '1': [108, 111, 99, 97, 108, 70, 105, 108, 101],
      };
      cloudDetails = {
        '1': [108, 111, 99, 97, 108, 70, 105, 108, 101],
      };

      final progressStates = <SyncState>[];
      await cloudSync.sync(progressCallback: progressStates.add);

      expect(progressStates, contains(isA<SavingToCloud>()));
      expect(progressStates, contains(isA<SyncCompleted>()));
      expect(cloudDetails['1'], equals(localDetails['1']));
    });

    test('sync should overwrite outdated cloud data with local data', () async {
      localMetadataList = [
        SyncMetadata(id: '1', modifiedAt: DateTime(2023, 2, 1)),
      ];
      cloudMetadataList = [
        SyncMetadata(id: '1', modifiedAt: DateTime(2023, 1, 1)),
      ];
      localDetails = {
        '1': [108, 111, 99, 97, 108, 70, 105, 108, 101, 50],
      };
      cloudDetails = {
        '1': [108, 111, 99, 97, 108, 70, 105, 108, 101],
      };

      final progressStates = <SyncState>[];
      await cloudSync.sync(progressCallback: progressStates.add);

      expect(progressStates, contains(isA<SavingToCloud>()));
      expect(progressStates, contains(isA<SyncCompleted>()));
      expect(cloudDetails['1'], equals(localDetails['1']));
    });

    test('sync should overwrite local data with newer cloud data', () async {
      localMetadataList = [
        SyncMetadata(id: '1', modifiedAt: DateTime(2023, 1, 1)),
      ];
      cloudMetadataList = [
        SyncMetadata(id: '1', modifiedAt: DateTime(2023, 2, 1)),
      ];
      localDetails = {
        '1': [108, 111, 99, 97, 108, 70, 105, 108, 101],
      };
      cloudDetails = {
        '1': [108, 111, 99, 97, 108, 70, 105, 108, 101, 50],
      };

      final progressStates = <SyncState>[];
      await cloudSync.sync(progressCallback: progressStates.add);

      expect(progressStates, contains(isA<SavingToLocal>()));
      expect(progressStates, contains(isA<SyncCompleted>()));
      expect(localDetails['1'], equals(cloudDetails['1']));
    });

    test('sync should prevent concurrent sync operations', () async {
      final progressStates1 = <SyncState>[];
      final progressStates2 = <SyncState>[];

      // Start the first sync.
      cloudSync.sync(progressCallback: progressStates1.add);

      // Start a second sync before the first one finishes.
      cloudSync.sync(progressCallback: progressStates2.add);

      await Future.delayed(const Duration(milliseconds: 100));

      // Ensure the first sync completed successfully and the second one was skipped.
      expect(progressStates1, contains(isA<SyncCompleted>()));
      expect(progressStates2, contains(isA<AlreadyInProgress>()));
    });

    test('sync should handle failure in fetchLocalMetadataList', () async {
      cloudSync = CloudSync(
        fetchLocalMetadataList: () async =>
            throw Exception('Failed to fetch local metadata'),
        fetchCloudMetadataList: () async => cloudMetadataList,
        fetchLocalDetail: (metadata) async => localDetails[metadata.id]!,
        fetchCloudDetail: (metadata) async => cloudDetails[metadata.id]!,
        saveToCloud: (metadata, detail) async {},
        saveToLocal: (metadata, detail) async {},
      );

      final progressStates = <SyncState>[];
      await cloudSync.sync(progressCallback: progressStates.add);

      expect(progressStates, contains(isA<SyncError>()));
    });

    test('sync should handle large data sets', () async {
      localMetadataList = List.generate(1000, (index) {
        return SyncMetadata(id: '$index', modifiedAt: DateTime(2023, 1, index));
      });
      cloudMetadataList = List.generate(1000, (index) {
        return SyncMetadata(
            id: '$index', modifiedAt: DateTime(2023, 1, index - 1));
      });
      localDetails = {
        for (var i = 0; i < 1000; i++) '$i': [i],
      };
      cloudDetails = {
        for (var i = 0; i < 1000; i++) '$i': [i - 1],
      };

      final progressStates = <SyncState>[];
      await cloudSync.sync(progressCallback: progressStates.add);

      expect(progressStates, contains(isA<SyncCompleted>()));
      expect(progressStates, isNot(contains(isA<SyncError>())));
    });

    test('stopAutoSync should stop further auto-sync operations', () async {
      int syncCallCounts = 0;

      cloudSync.autoSync(
        interval: const Duration(milliseconds: 100),
        progressCallback: (progressState) {
          if (progressState is SyncCompleted) {
            syncCallCounts++;
          }
        },
      );

      await Future.delayed(const Duration(milliseconds: 250));
      cloudSync.stopAutoSync();

      await Future.delayed(const Duration(milliseconds: 200));

      expect(syncCallCounts, lessThanOrEqualTo(3));
    });
  });
}
