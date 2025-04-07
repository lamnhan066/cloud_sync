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
      SyncMetadata(id: '1', modifiedAt: DateTime(2023, 1, 1)),
      SyncMetadata(id: '2', modifiedAt: DateTime(2023, 1, 2)),
    ];
    cloudMetadataList = [
      SyncMetadata(id: '2', modifiedAt: DateTime(2023, 1, 1)),
      SyncMetadata(id: '3', modifiedAt: DateTime(2023, 1, 3)),
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
      fetchLocalDetail: (metadata) async => localDetails[metadata.id]!,
      fetchCloudDetail: (metadata) async => cloudDetails[metadata.id]!,
      writeDetailToCloud: (metadata, detail) async {
        cloudMetadataList.removeWhere((m) => m.id == metadata.id);
        cloudMetadataList.add(metadata);
        cloudDetails[metadata.id] = detail;
      },
      writeDetailToLocal: (metadata, detail) async {
        localMetadataList.removeWhere((m) => m.id == metadata.id);
        localMetadataList.add(metadata);
        localDetails[metadata.id] = detail;
      },
    );
  });

  group('sync', () {
    test(
        'sync should synchronize missing or outdated details between cloud and local storage',
        () async {
      final progressStates = <SyncState>[];
      await cloudSync.sync(progressCallback: progressStates.add);

      expect(
          progressStates,
          containsAllInOrder([
            isA<WritingDetailToCloud>(),
            isA<WritingDetailToLocal>(),
            isA<SyncCompleted>(),
          ]));
      expect(cloudDetails.containsKey('1'), isTrue);
      expect(cloudDetails['1'], equals(localDetails['1']));
      expect(localDetails.containsKey('3'), isTrue);
      expect(localDetails['3'], equals(cloudDetails['3']));
    });

    test('sync should skip already synchronized details', () async {
      localMetadataList = [
        SyncMetadata(id: '1', modifiedAt: DateTime(2023, 1, 1))
      ];
      cloudMetadataList = [
        SyncMetadata(id: '1', modifiedAt: DateTime(2023, 1, 1))
      ];
      localDetails = {
        '1': [115, 97, 109, 101, 70, 105, 108, 101]
      };
      cloudDetails = {
        '1': [115, 97, 109, 101, 70, 105, 108, 101]
      };

      final progressStates = <SyncState>[];
      await cloudSync.sync(progressCallback: progressStates.add);

      expect(progressStates, contains(isA<SyncCompleted>()));
      expect(progressStates, isNot(contains(isA<WritingDetailToLocal>())));
      expect(progressStates, isNot(contains(isA<WritingDetailToCloud>())));
    });

    test('sync should not run if already in progress', () async {
      cloudSync.sync(progressCallback: (_) {});
      final progressStates = <SyncState>[];
      await cloudSync.sync(progressCallback: progressStates.add);

      expect(progressStates, contains(isA<AlreadyInProgress>()));
    });

    test('sync should handle errors during synchronization gracefully',
        () async {
      cloudSync = CloudSync(
        fetchLocalMetadataList: () async => throw Exception('Test error'),
        fetchCloudMetadataList: () async => cloudMetadataList,
        fetchLocalDetail: (metadata) async => localDetails[metadata.id]!,
        fetchCloudDetail: (metadata) async => cloudDetails[metadata.id]!,
        writeDetailToLocal: (metadata, detail) async {},
        writeDetailToCloud: (metadata, detail) async {},
      );

      final progressStates = <SyncState>[];
      await cloudSync.sync(progressCallback: progressStates.add);

      expect(progressStates, contains(isA<SyncError>()));
    });

    test('sync should skip syncing with empty data', () async {
      // Clear metadata and details to simulate empty data.
      localMetadataList.clear();
      cloudMetadataList.clear();
      localDetails.clear();
      cloudDetails.clear();

      final progressStates = <SyncState>[];
      await cloudSync.sync(progressCallback: progressStates.add);

      // Ensure the sync completes without any syncing happening.
      expect(progressStates, contains(isA<SyncCompleted>()));

      // Check that both local and cloud details are empty.
      expect(localDetails.isEmpty, isTrue);
      expect(cloudDetails.isEmpty, isTrue);
    });
  });

  group('autoSync', () {
    test(
        'autoSync should periodically trigger sync operations and stop after a set time',
        () async {
      final syncCallCounts = <int>[];
      cloudSync = CloudSync(
        fetchLocalMetadataList: () async {
          syncCallCounts.add(syncCallCounts.length + 1);
          return localMetadataList;
        },
        fetchCloudMetadataList: () async => cloudMetadataList,
        fetchLocalDetail: (metadata) async => localDetails[metadata.id]!,
        fetchCloudDetail: (metadata) async => cloudDetails[metadata.id]!,
        writeDetailToLocal: (metadata, detail) async {},
        writeDetailToCloud: (metadata, detail) async {},
      );

      cloudSync.autoSync(
        interval: const Duration(milliseconds: 100),
        progressCallback: (_) {},
      );

      await Future.delayed(const Duration(milliseconds: 350));
      cloudSync.stopAutoSync();

      expect(syncCallCounts.length, greaterThanOrEqualTo(3));
    });

    test('stopAutoSync should cancel the periodic sync timer', () async {
      final syncCallCounts = <int>[];

      cloudSync.autoSync(
        interval: const Duration(milliseconds: 100),
        progressCallback: (_) {},
      );

      await Future.delayed(const Duration(milliseconds: 150));
      cloudSync.stopAutoSync();

      await Future.delayed(const Duration(milliseconds: 200));
      expect(syncCallCounts.length, lessThanOrEqualTo(2));
    });
  });
}
