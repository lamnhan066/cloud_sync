# CloudSync

**CloudSync** is a Dart package that provides a flexible and type-safe mechanism to synchronize data between **local** and **cloud** storage. Designed with composability and progress observability in mind, this utility uses metadata comparison to detect changes and synchronize them efficiently.

## Features

- Two-way sync between local and cloud
- Smart diffing using metadata timestamps
- Progress tracking with callback-based state reporting 
- Modular architecture with adapter-based or function injection for I/O
- Automatic periodic syncing
- Error handling with detailed sync state events
- Concurrent synchronization option

## Getting Started

### 1. Install

Add `cloud_sync` to your `pubspec.yaml`:

```yaml
dependencies:
  cloud_sync: ^<latest_version>
```

Then run:

```bash
flutter pub get
```

### 2. Import

```dart
import 'package:cloud_sync/cloud_sync.dart';
```

## Usage Examples

### Function-Based Approach

```dart
final cloudSync = CloudSync<MyMetadata, MyData>(
  fetchLocalMetadataList: () async => localMetadataList,
  fetchCloudMetadataList: () async => cloudMetadataList,
  fetchLocalDetail: (metadata) async => localStorage[metadata.id]!,
  fetchCloudDetail: (metadata) async => cloudStorage[metadata.id]!,
  saveToLocal: (metadata, data) async => localStorage[metadata.id] = data,
  saveToCloud: (metadata, data) async => cloudStorage[metadata.id] = data,
);

// Manual sync
await cloudSync.sync(progressCallback: (state) {
  print('Sync state: ${state.runtimeType}');
});

// Start auto-sync every 10 minutes
cloudSync.autoSync(
  interval: Duration(minutes: 10),
  progressCallback: (state) {
    print('Auto-sync state: ${state.runtimeType}');
  },
);

// Stop auto-sync
cloudSync.stopAutoSync();
```

### Adapter-Based Approach

```dart
// Create your adapters
class LocalAdapter extends SyncAdapter<MyMetadata, MyData> {
  @override
  Future<List<MyMetadata>> fetchMetadataList() async => /* implementation */;
  
  @override
  Future<MyData> fetchDetail(MyMetadata metadata) async => /* implementation */;
  
  @override
  Future<void> save(MyMetadata metadata, MyData detail) async => /* implementation */;
}

class CloudAdapter extends SyncAdapter<MyMetadata, MyData> {
  // Similar implementation
}

// Create CloudSync using adapters
final cloudSync = CloudSync.fromAdapters(
  LocalAdapter(),
  CloudAdapter(),
);
```

## API Overview

### `CloudSync<M, D>` Constructor

```dart
CloudSync({
  required FetchMetadataList<M> fetchLocalMetadataList,
  required FetchMetadataList<M> fetchCloudMetadataList,
  required FetchDetail<M, D> fetchLocalDetail,
  required FetchDetail<M, D> fetchCloudDetail,
  required SaveDetail<M, D> saveToLocal,
  required SaveDetail<M, D> saveToCloud,
});
```

### Factory Constructor

```dart
CloudSync.fromAdapters(
  SyncAdapter<M, D> localAdapter,
  SyncAdapter<M, D> cloudAdapter,
);
```

### Methods

| Method | Description |
|--------|-------------|
| `sync()` | Executes a full sync with optional progress callback and concurrent sync option. |
| `autoSync()` | Starts a timer to auto-sync periodically. |
| `stopAutoSync()` | Stops the auto-sync process. |

## Type Definitions

| Type | Signature | Purpose |
|------|-----------|---------|
| `FetchMetadataList<M>` | `Future<List<M>> Function()` | Fetches list of metadata |
| `FetchDetail<M, D>` | `Future<D> Function(M)` | Retrieves data using metadata |
| `SaveDetail<M, D>` | `Future<void> Function(M, D)` | Writes data to storage |
| `SyncProgressCallback<M>` | `void Function(SyncState<M>)` | Reports progress updates |

## Models

### `SyncMetadata`

```dart
class SyncMetadata {
  final String id;
  final DateTime modifiedAt;
  final bool isDeleted;

  SyncMetadata({
    required this.id,
    required this.modifiedAt,
    this.isDeleted = false,
  });
  
  // Additional utility methods:
  // copyWith(), toMap(), fromMap(), toJson(), fromJson()
}
```

Extend this class to include more fields (e.g., `name`, `size`, etc.) as needed.

### `SyncAdapter`

```dart
abstract class SyncAdapter<M extends SyncMetadata, D> {
  Future<List<M>> fetchMetadataList();
  Future<D> fetchDetail(M metadata);
  Future<void> save(M metadata, D detail);
}
```

## Sync Lifecycle States

`SyncState<M>` is the base class for all sync progress reporting. Use it to show progress in UI or for logging.

| State | Description |
|-------|-------------|
| `InProgress` | A sync is already ongoing and cannot start a new one. |
| `FetchingLocalMetadata` | Fetching metadata from the local source. |
| `FetchingCloudMetadata` | Fetching metadata from the cloud source. |
| `ScanningCloud` | Comparing local data against cloud data to find differences. |
| `ScanningLocal` | Comparing cloud data against local data to find differences. |
| `SavingToCloud` | Writing a specific data/metadata pair to the cloud. |
| `SavedToCloud` | Successfully wrote data to the cloud. |
| `SavingToLocal` | Writing a specific data/metadata pair to local storage. |
| `SavedToLocal` | Successfully wrote data to local storage. |
| `SyncCompleted` | Sync finished without errors. |
| `SyncError` | Sync failed with an error. |

Each state can be used for monitoring or UI updates.

## Auto-Sync

Automatically sync data at regular intervals.

### Start

```dart
cloudSync.autoSync(
  interval: Duration(minutes: 15),
  progressCallback: (state) {
    print('Auto-sync: ${state.runtimeType}');
  },
);
```

### Stop

```dart
cloudSync.stopAutoSync();
```

> If a sync is already running when the timer fires, the cycle will be skipped and `InProgress` will be reported.

## Example Custom Types

You can define your own metadata and data models like this:

```dart
class MyMetadata extends SyncMetadata {
  final String name;
  MyMetadata({required super.id, required super.modifiedAt, required this.name});
}

class MyData {
  final String content;
  MyData(this.content);
}
```

## Sync Implementation Details

CloudSync performs synchronization in the following order:

1. Fetch metadata from local and cloud sources
2. Compare metadata to identify differences
3. Upload missing or newer local files to the cloud
4. Download missing or newer cloud files to local storage
5. Report completion or errors

Each step is reported through the `progressCallback` to provide visibility into the sync process.

The `useConcurrentSync` parameter allows for parallel processing of local and cloud data synchronization when set to `true`.

## License

MIT License. Use it, extend it, and contribute!

## Inspiration

Built for apps that need to keep data synchronized across devices or sessions, such as:

- Note apps
- Document managers
- Media libraries
- Offline-capable business tools

## Contributions Welcome

Found a bug or have a suggestion? PRs and issues are open and appreciated!