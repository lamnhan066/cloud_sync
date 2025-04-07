import 'package:cloud_sync/cloud_sync.dart';

void main() async {
  // Mock metadata and file storage
  final localStorage = <String, Object>{};
  final cloudStorage = <String, Object>{};

  final localMetadata = <SyncMetadata>[
    SyncMetadata(
      id: '1',
      modifiedAt: DateTime(2023, 1, 5),
    ),
  ];

  final cloudMetadata = <SyncMetadata>[
    SyncMetadata(
      id: '2',
      modifiedAt: DateTime(2023, 1, 4),
    ),
  ];

  // Add file content to local and cloud storages
  localStorage['1'] = 'Local file 1 content';
  cloudStorage['2'] = 'Cloud file 2 content';

  final cloudSync = CloudSync(
    fetchLocalMetadataList: () async => localMetadata,
    fetchCloudMetadataList: () async => cloudMetadata,
    fetchLocalDetail: (metadata) async {
      return localStorage[metadata.id]!;
    },
    fetchCloudDetail: (metadata) async {
      return cloudStorage[metadata.id]!;
    },
    writeDetailToCloud: (metadata, file) async {
      cloudStorage[metadata.id] = file;
    },
    writeDetailToLocal: (metadata, file) async {
      localStorage[metadata.id] = file;
    },
  );

  // Sync with logging
  await cloudSync.sync(progressCallback: (state) {
    print('[SYNC STATE] ${state.runtimeType}');
    if (state is WritingDetailToCloud) {
      print('Uploading: ${state.metadata.id}');
    } else if (state is WritingDetailToLocal) {
      print('Downloading: ${state.metadata.id}');
    } else if (state is SyncCompleted) {
      print('✅ Sync completed!');
    } else if (state is SyncError) {
      print('❌ Error during sync: ${state.error}');
    }
  });

  // Verify the final state
  print('\nLocal files: ${localStorage.keys}');
  print('Cloud files: ${cloudStorage.keys}');
}
