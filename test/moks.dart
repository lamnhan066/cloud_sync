import 'dart:async';

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
  Map<String, MockData> get data => _data;
  final Map<String, MockData> _data = {};
  Map<String, SyncMetadata> get metadata => _metadata;
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
