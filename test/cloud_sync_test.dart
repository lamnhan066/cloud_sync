import 'package:cloud_sync/src/cloud_sync.dart';
import 'package:cloud_sync/src/models/sync_file.dart';
import 'package:cloud_sync/src/models/sync_metadata.dart';
import 'package:cloud_sync/src/models/sync_state.dart';
import 'package:test/test.dart';

void main() {
  late CloudSync cloudSync;
  late List<SyncMetadata> localMetadataList;
  late List<SyncMetadata> cloudMetadataList;
  late Map<String, SyncFile> localFiles;
  late Map<String, SyncFile> cloudFiles;

  setUp(() {
    localMetadataList = [
      SyncMetadata(
        id: '1',
        name: 'localFile1',
        modifiedAt: DateTime(2023, 1, 1),
        createdAt: DateTime(2023, 1, 1),
      ),
      SyncMetadata(
        id: '2',
        name: 'localFile2',
        modifiedAt: DateTime(2023, 1, 2),
        createdAt: DateTime(2023, 1, 1),
      ),
    ];
    cloudMetadataList = [
      SyncMetadata(
        id: '2',
        name: 'cloudFile2',
        modifiedAt: DateTime(2023, 1, 1),
        createdAt: DateTime(2023, 1, 1),
      ),
      SyncMetadata(
        id: '3',
        name: 'cloudFile3',
        modifiedAt: DateTime(2023, 1, 3),
        createdAt: DateTime(2023, 1, 2),
      ),
    ];
    localFiles = {
      '1': SyncFile(bytes: [108, 111, 99, 97, 108, 70, 105, 108, 101, 49]),
      '2': SyncFile(bytes: [108, 111, 99, 97, 108, 70, 105, 108, 101, 50]),
    };
    cloudFiles = {
      '2': SyncFile(bytes: [99, 108, 111, 117, 100, 70, 105, 108, 101, 50]),
      '3': SyncFile(bytes: [99, 108, 111, 117, 100, 70, 105, 108, 101, 51]),
    };

    cloudSync = CloudSync(
      fetchLocalMetadataList: () async => localMetadataList,
      fetchCloudMetadataList: () async => cloudMetadataList,
      fetchLocalFileByMetadata: (metadata) async => localFiles[metadata.id]!,
      fetchCloudFileByMetadata: (metadata) async => cloudFiles[metadata.id]!,
      writeFileToCloudStorage: (metadata, file) async {
        cloudMetadataList.removeWhere((m) => m.id == metadata.id);
        cloudMetadataList.add(metadata);
        cloudFiles[metadata.id] = file;
      },
      writeFileToLocalStorage: (metadata, file) async {
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

      expect(progressStates, contains(isA<SavingFileToCloud>()));
      expect(progressStates, contains(isA<SynchronizationCompleted>()));
      expect(cloudFiles.containsKey('1'), isTrue);
      expect(cloudFiles['1']!.bytes, equals(localFiles['1']!.bytes));
    });

    test(
        'sync should synchronize missing or outdated files to the local storage',
        () async {
      final progressStates = <SyncState>[];
      await cloudSync.sync(progressCallback: progressStates.add);

      expect(progressStates, contains(isA<SavingFileToLocal>()));
      expect(progressStates, contains(isA<SynchronizationCompleted>()));
      expect(localFiles.containsKey('3'), isTrue);
      expect(localFiles['3']!.bytes, equals(cloudFiles['3']!.bytes));
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
        fetchLocalFileByMetadata: (metadata) async => localFiles[metadata.id]!,
        fetchCloudFileByMetadata: (metadata) async => cloudFiles[metadata.id]!,
        writeFileToLocalStorage: (metadata, file) async {},
        writeFileToCloudStorage: (metadata, file) async {},
      );

      final progressStates = <SyncState>[];
      await expectLater(
        () => cloudSync.sync(progressCallback: progressStates.add),
        throwsException,
      );

      expect(progressStates, contains(isA<SynchronizationError>()));
    });

    test('sync should skip files that are already up to date', () async {
      localMetadataList = [
        SyncMetadata(
          id: '1',
          name: 'sameFile',
          modifiedAt: DateTime(2023, 1, 1),
          createdAt: DateTime(2023, 1, 1),
        ),
      ];
      cloudMetadataList = [
        SyncMetadata(
          id: '1',
          name: 'sameFile',
          modifiedAt: DateTime(2023, 1, 1),
          createdAt: DateTime(2023, 1, 1),
        ),
      ];
      localFiles = {
        '1': SyncFile(bytes: [115, 97, 109, 101, 70, 105, 108, 101]),
      };
      cloudFiles = {
        '1': SyncFile(bytes: [115, 97, 109, 101, 70, 105, 108, 101]),
      };

      final progressStates = <SyncState>[];
      await cloudSync.sync(progressCallback: progressStates.add);

      expect(progressStates, isNot(contains(isA<SavingFileToLocal>())));
      expect(progressStates, isNot(contains(isA<SavingFileToCloud>())));
      expect(progressStates, contains(isA<SynchronizationCompleted>()));
    });

    test('sync should handle two consecutive sync operations', () async {
      final firstSyncProgressStates = <SyncState>[];
      final secondSyncProgressStates = <SyncState>[];

      await cloudSync.sync(progressCallback: firstSyncProgressStates.add);
      await cloudSync.sync(progressCallback: secondSyncProgressStates.add);

      expect(
          firstSyncProgressStates, contains(isA<SynchronizationCompleted>()));
      expect(
          secondSyncProgressStates, contains(isA<SynchronizationCompleted>()));
      expect(
          secondSyncProgressStates, isNot(contains(isA<SavingFileToLocal>())));
      expect(
          secondSyncProgressStates, isNot(contains(isA<SavingFileToCloud>())));
    });

    test('sync should handle multiple files with different states', () async {
      localMetadataList.add(SyncMetadata(
        id: '4',
        name: 'localFile4',
        modifiedAt: DateTime(2023, 1, 4),
        createdAt: DateTime(2023, 1, 4),
      ));
      localFiles['4'] =
          SyncFile(bytes: [108, 111, 99, 97, 108, 70, 105, 108, 101, 52]);

      final progressStates = <SyncState>[];
      await cloudSync.sync(progressCallback: progressStates.add);

      expect(progressStates, contains(isA<SavingFileToCloud>()));
      expect(progressStates, contains(isA<SavingFileToLocal>()));
      expect(progressStates, contains(isA<SynchronizationCompleted>()));
      expect(cloudFiles.containsKey('4'), isTrue);
      expect(cloudFiles['4']!.bytes, equals(localFiles['4']!.bytes));
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
        fetchLocalFileByMetadata: (metadata) async => localFiles[metadata.id]!,
        fetchCloudFileByMetadata: (metadata) async => cloudFiles[metadata.id]!,
        writeFileToLocalStorage: (metadata, file) async {},
        writeFileToCloudStorage: (metadata, file) async {},
      );

      cloudSync.autoSync(
        interval: const Duration(milliseconds: 100),
        progressCallback: progressStates.add,
      );

      // Wait for multiple sync cycles to complete.
      await Future.delayed(const Duration(milliseconds: 350));
      cloudSync.stopAutoSync();

      expect(syncCallCounts.length, greaterThanOrEqualTo(3));
      expect(progressStates, contains(isA<SynchronizationCompleted>()));
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
        fetchLocalFileByMetadata: (metadata) async => localFiles[metadata.id]!,
        fetchCloudFileByMetadata: (metadata) async => cloudFiles[metadata.id]!,
        writeFileToLocalStorage: (metadata, file) async {},
        writeFileToCloudStorage: (metadata, file) async {},
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
