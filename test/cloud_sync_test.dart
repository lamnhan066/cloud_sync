import 'package:cloud_sync/src/cloud_sync.dart';
import 'package:cloud_sync/src/models/sync_metadata.dart';
import 'package:cloud_sync/src/models/sync_state.dart';
import 'package:test/test.dart';

void main() {
  late CloudSync cloudSync;
  late List<SyncMetadata> localMetadataList;
  late List<SyncMetadata> cloudMetadataList;
  late Map<String, Object> localFiles;
  late Map<String, Object> cloudFiles;

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
    localFiles = {
      '1': [108, 111, 99, 97, 108, 70, 105, 108, 101, 49],
      '2': [108, 111, 99, 97, 108, 70, 105, 108, 101, 50],
    };
    cloudFiles = {
      '2': [99, 108, 111, 117, 100, 70, 105, 108, 101, 50],
      '3': [99, 108, 111, 117, 100, 70, 105, 108, 101, 51],
    };

    cloudSync = CloudSync(
      fetchLocalMetadataList: () async => localMetadataList,
      fetchCloudMetadataList: () async => cloudMetadataList,
      fetchLocalDetail: (metadata) async => localFiles[metadata.id]!,
      fetchCloudDetail: (metadata) async => cloudFiles[metadata.id]!,
      writeDetailToCloud: (metadata, file) async {
        cloudMetadataList.removeWhere((m) => m.id == metadata.id);
        cloudMetadataList.add(metadata);
        cloudFiles[metadata.id] = file;
      },
      writeDetailToLocal: (metadata, file) async {
        localMetadataList.removeWhere((m) => m.id == metadata.id);
        localMetadataList.add(metadata);
        localFiles[metadata.id] = file;
      },
    );
  });

  group('sync', () {
    test('sync should synchronize missing or outdated files to the cloud',
        () async {
      final progressStates = <SyncState>[];
      await cloudSync.sync(progressCallback: progressStates.add);

      expect(progressStates, contains(isA<WritingDetailToCloud>()));
      expect(progressStates, contains(isA<SyncCompleted>()));
      expect(cloudFiles.containsKey('1'), isTrue);
      expect(cloudFiles['1'], equals(localFiles['1']));
    });

    test(
        'sync should synchronize missing or outdated files to the local storage',
        () async {
      final progressStates = <SyncState>[];
      await cloudSync.sync(progressCallback: progressStates.add);

      expect(progressStates, contains(isA<WritingDetailToLocal>()));
      expect(progressStates, contains(isA<SyncCompleted>()));
      expect(localFiles.containsKey('3'), isTrue);
      expect(localFiles['3'], equals(cloudFiles['3']));
    });

    test('sync should not run if already in progress', () async {
      cloudSync.sync();

      final progressStates = <SyncState>[];
      await cloudSync.sync(progressCallback: progressStates.add);

      expect(progressStates, contains(isA<AlreadyInProgress>()));
    });

    test('sync should handle errors during synchronization', () async {
      cloudSync = CloudSync(
        fetchLocalMetadataList: () async => throw Exception('Test error'),
        fetchCloudMetadataList: () async => cloudMetadataList,
        fetchLocalDetail: (metadata) async => localFiles[metadata.id]!,
        fetchCloudDetail: (metadata) async => cloudFiles[metadata.id]!,
        writeDetailToLocal: (metadata, file) async {},
        writeDetailToCloud: (metadata, file) async {},
      );

      final progressStates = <SyncState>[];
      await expectLater(
        () => cloudSync.sync(progressCallback: progressStates.add),
        throwsException,
      );

      expect(progressStates, contains(isA<SyncError>()));
    });

    test('sync should skip files that are already up to date', () async {
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
      localFiles = {
        '1': [115, 97, 109, 101, 70, 105, 108, 101],
      };
      cloudFiles = {
        '1': [115, 97, 109, 101, 70, 105, 108, 101],
      };

      final progressStates = <SyncState>[];
      await cloudSync.sync(progressCallback: progressStates.add);

      expect(progressStates, isNot(contains(isA<WritingDetailToLocal>())));
      expect(progressStates, isNot(contains(isA<WritingDetailToCloud>())));
      expect(progressStates, contains(isA<SyncCompleted>()));
    });

    test('sync should handle two consecutive sync operations', () async {
      final firstSyncProgressStates = <SyncState>[];
      final secondSyncProgressStates = <SyncState>[];

      await cloudSync.sync(progressCallback: firstSyncProgressStates.add);
      await cloudSync.sync(progressCallback: secondSyncProgressStates.add);

      expect(firstSyncProgressStates, contains(isA<SyncCompleted>()));
      expect(secondSyncProgressStates, contains(isA<SyncCompleted>()));
      expect(secondSyncProgressStates,
          isNot(contains(isA<WritingDetailToLocal>())));
      expect(secondSyncProgressStates,
          isNot(contains(isA<WritingDetailToCloud>())));
    });

    test('sync should handle multiple files with different states', () async {
      localMetadataList.add(SyncMetadata(
        id: '4',
        modifiedAt: DateTime(2023, 1, 4),
      ));
      localFiles['4'] = [108, 111, 99, 97, 108, 70, 105, 108, 101, 52];

      final progressStates = <SyncState>[];
      await cloudSync.sync(progressCallback: progressStates.add);

      expect(progressStates, contains(isA<WritingDetailToCloud>()));
      expect(progressStates, contains(isA<WritingDetailToLocal>()));
      expect(progressStates, contains(isA<SyncCompleted>()));
      expect(cloudFiles.containsKey('4'), isTrue);
      expect(cloudFiles['4'], equals(localFiles['4']));
    });
  });

  group('autoSync', () {
    test('autoSync should periodically trigger sync operations', () async {
      final progressStates = <SyncState>[];
      final syncCallCounts = <int>[];

      cloudSync = CloudSync(
        fetchLocalMetadataList: () async {
          syncCallCounts.add(1);
          return localMetadataList;
        },
        fetchCloudMetadataList: () async => cloudMetadataList,
        fetchLocalDetail: (metadata) async => localFiles[metadata.id]!,
        fetchCloudDetail: (metadata) async => cloudFiles[metadata.id]!,
        writeDetailToLocal: (metadata, file) async {},
        writeDetailToCloud: (metadata, file) async {},
      );

      cloudSync.autoSync(
        interval: const Duration(milliseconds: 100),
        progressCallback: progressStates.add,
      );

      // Wait for multiple sync cycles to complete.
      await Future.delayed(const Duration(milliseconds: 350));
      cloudSync.stopAutoSync();

      expect(syncCallCounts.length, greaterThanOrEqualTo(3));
      expect(progressStates, contains(isA<SyncCompleted>()));
    });

    test('stopAutoSync should cancel the periodic sync timer', () async {
      final progressStates = <SyncState>[];
      final syncCallCounts = <int>[];

      cloudSync = CloudSync(
        fetchLocalMetadataList: () async {
          syncCallCounts.add(1);
          return localMetadataList;
        },
        fetchCloudMetadataList: () async => cloudMetadataList,
        fetchLocalDetail: (metadata) async => localFiles[metadata.id]!,
        fetchCloudDetail: (metadata) async => cloudFiles[metadata.id]!,
        writeDetailToLocal: (metadata, file) async {},
        writeDetailToCloud: (metadata, file) async {},
      );

      cloudSync.autoSync(
        interval: const Duration(milliseconds: 100),
        progressCallback: progressStates.add,
      );

      // Stop auto-sync after a short delay.
      await Future.delayed(const Duration(milliseconds: 150));
      cloudSync.stopAutoSync();

      // Wait to ensure no further syncs are triggered.
      await Future.delayed(const Duration(milliseconds: 200));

      expect(syncCallCounts.length, lessThanOrEqualTo(2));
    });
  });
}
