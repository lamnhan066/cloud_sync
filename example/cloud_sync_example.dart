import 'package:cloud_sync/cloud_sync.dart';

void main() async {
  // Mock metadata and file storage
  final localStorage = <String, SyncFile>{};
  final cloudStorage = <String, SyncFile>{};

  final localMetadata = <SyncMetadata>[
    SyncMetadata(
      id: '1',
      name: 'file1.txt',
      createdAt: DateTime(2023, 1, 1),
      modifiedAt: DateTime(2023, 1, 5),
    ),
  ];

  final cloudMetadata = <SyncMetadata>[
    SyncMetadata(
      id: '2',
      name: 'file2.txt',
      createdAt: DateTime(2023, 1, 1),
      modifiedAt: DateTime(2023, 1, 4),
    ),
  ];

  // Add file content to local and cloud storages
  localStorage['1'] = SyncFile(bytes: 'Local file 1 content'.codeUnits);
  cloudStorage['2'] = SyncFile(bytes: 'Cloud file 2 content'.codeUnits);

  final cloudSync = CloudSync(
    fetchLocalMetadataList: () async => localMetadata,
    fetchCloudMetadataList: () async => cloudMetadata,
    fetchLocalFileByMetadata: (metadata) async {
      return localStorage[metadata.id]!;
    },
    fetchCloudFileByMetadata: (metadata) async {
      return cloudStorage[metadata.id]!;
    },
    writeFileToCloudStorage: (metadata, file) async {
      cloudStorage[metadata.id] = file;
    },
    writeFileToLocalStorage: (metadata, file) async {
      localStorage[metadata.id] = file;
    },
  );

  // Sync with logging
  await cloudSync.sync(progressCallback: (state) {
    print('[SYNC STATE] ${state.runtimeType}');
    if (state is SavingFileToCloud) {
      print('Uploading: ${state.metadata.name}');
    } else if (state is SavingFileToLocal) {
      print('Downloading: ${state.metadata.name}');
    } else if (state is SynchronizationCompleted) {
      print('✅ Sync completed!');
    } else if (state is SynchronizationError) {
      print('❌ Error during sync: ${state.error}');
    }
  });

  // Verify the final state
  print('\nLocal files: ${localStorage.keys}');
  print('Cloud files: ${cloudStorage.keys}');
}
