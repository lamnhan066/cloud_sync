// Example of using CloudSync with custom adapters
// ignore_for_file: avoid_print

import 'package:cloud_sync/cloud_sync.dart';

class MyData {
  MyData(this.content);

  factory MyData.fromMap(Map<String, dynamic> map) {
    return MyData(map['content'] as String);
  }
  final String content;

  Map<String, dynamic> toMap() {
    return {'content': content};
  }

  @override
  String toString() => 'MyData(content: $content)';
}

class MyLocalAdapter extends SyncAdapter<SyncMetadata, MyData> {
  final Map<String, MyData> _localData = {};
  final Map<String, SyncMetadata> _localMetadata = {};

  @override
  Future<List<SyncMetadata>> fetchMetadataList() async {
    return _localMetadata.values.toList();
  }

  @override
  Future<MyData> fetchDetail(SyncMetadata metadata) async {
    return _localData[metadata.id]!;
  }

  @override
  Future<void> save(SyncMetadata metadata, MyData detail) async {
    _localMetadata[metadata.id] = metadata;
    _localData[metadata.id] = detail;
  }
}

class MyCloudAdapter extends SyncAdapter<SyncMetadata, MyData> {
  final Map<String, MyData> _cloudData = {};
  final Map<String, SyncMetadata> _cloudMetadata = {};

  @override
  Future<List<SyncMetadata>> fetchMetadataList() async {
    return _cloudMetadata.values.toList();
  }

  @override
  Future<MyData> fetchDetail(SyncMetadata metadata) async {
    return _cloudData[metadata.id]!;
  }

  @override
  Future<void> save(SyncMetadata metadata, MyData detail) async {
    _cloudMetadata[metadata.id] = metadata;
    _cloudData[metadata.id] = detail;
  }
}

void main() async {
  final localAdapter = MyLocalAdapter();
  final cloudAdapter = MyCloudAdapter();

  // Initialize CloudSync with local and cloud adapters
  // and set up the sync process.
  final cloudSync = CloudSync.fromAdapters(localAdapter, cloudAdapter);

  // Add some data to local and cloud.
  final localMetadata = SyncMetadata(id: '1', modifiedAt: DateTime.now());
  final localData = MyData('Local Data');
  await localAdapter.save(localMetadata, localData);

  final cloudMetadata = SyncMetadata(id: '2', modifiedAt: DateTime.now());
  final cloudData = MyData('Cloud Data');
  await cloudAdapter.save(cloudMetadata, cloudData);

  // Perform sync
  await cloudSync.sync(
    progressCallback: (state) {
      print('Sync state: ${state.runtimeType}');
    },
  );

  // Fetch metadata and details from both adapters
  final localMetadataList = await localAdapter.fetchMetadataList();
  final cloudMetadataList = await cloudAdapter.fetchMetadataList();

  for (final metadata in localMetadataList) {
    final detail = await localAdapter.fetchDetail(metadata);
    print('Local Metadata: $metadata, Detail: $detail');
  }

  for (final metadata in cloudMetadataList) {
    final detail = await cloudAdapter.fetchDetail(metadata);
    print('Cloud Metadata: $metadata, Detail: $detail');
  }
}
