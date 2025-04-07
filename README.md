# CloudSync

**CloudSync** is a Dart package that provides a flexible and type-safe mechanism to synchronize data between **local** and **cloud** storage. Designed with composability and progress observability in mind, this utility uses metadata comparison to detect changes and synchronize them efficiently.

---

## Features

- Two-way sync between local and cloud
- Smart diffing using metadata timestamps
- Progress tracking with callback-based state reporting
- Modular architecture with function injection for I/O
- Automatic periodic syncing
- Error handling with detailed sync state events

---

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

---

## Usage Example

```dart
final cloudSync = CloudSync<MyMetadata, MyData>(
  fetchLocalMetadataList: () async => localMetadataList,
  fetchCloudMetadataList: () async => cloudMetadataList,
  fetchLocalDetail: (metadata) async => localStorage[metadata.id]!,
  fetchCloudDetail: (metadata) async => cloudStorage[metadata.id]!,
  writeDetailToLocal: (metadata, data) async => localStorage[metadata.id] = data,
  writeDetailToCloud: (metadata, data) async => cloudStorage[metadata.id] = data,
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

---

## API Overview

### `CloudSync<M, D>` Constructor

```dart
CloudSync({
  required FetchMetadataList<M> fetchLocalMetadataList,
  required FetchMetadataList<M> fetchCloudMetadataList,
  required FetchDetail<M, D> fetchLocalDetail,
  required FetchDetail<M, D> fetchCloudDetail,
  required WriteDetail<M, D> writeDetailToLocal,
  required WriteDetail<M, D> writeDetailToCloud,
});
```

### Methods

| Method            | Description |
|-------------------|-------------|
| `sync()`          | Executes a full sync. |
| `autoSync()`      | Starts a timer to auto-sync periodically. |
| `stopAutoSync()`  | Stops the auto-sync process. |

---

## Type Definitions

| Type | Signature | Purpose |
|------|-----------|---------|
| `FetchMetadataList<M>` | `Future<List<M>> Function()` | Fetches list of metadata |
| `FetchDetail<M, D>` | `Future<D> Function(M)` | Retrieves data using metadata |
| `WriteDetail<M, D>` | `Future<void> Function(M, D)` | Writes data to storage |
| `SyncProgressCallback<M>` | `void Function(SyncState<M>)` | Reports progress updates |

---

## Models

### `SyncMetadata`

```dart
class SyncMetadata {
  final String id;
  final DateTime modifiedAt;

  SyncMetadata({
    required this.id,
    required this.modifiedAt,
  });
}
```

Extend this class to include more fields (e.g., `name`, `size`, etc.) as needed.

---

## Sync Lifecycle States

`SyncState<M>` is the base class for all sync progress reporting. Use it to show progress in UI or for logging.

| State | Description |
|-------|-------------|
| `AlreadyInProgress` | A sync is already ongoing and cannot start a new one. |
| `FetchingLocalMetadata` | Fetching metadata from the local source. |
| `FetchingCloudMetadata` | Fetching metadata from the cloud source. |
| `CheckingCloudForMissingOrOutdatedData` | Comparing local data against cloud data to find differences. |
| `CheckingLocalForMissingOrOutdatedData` | Comparing cloud data against local data to find differences. |
| `WritingDetailToCloud` | Writing a specific data/metadata pair to the cloud. |
| `WritingDetailToLocal` | Writing a specific data/metadata pair to local storage. |
| `SyncCompleted` | Sync finished without errors. |
| `SyncError` | Sync failed with an error. |

Each state can be used for monitoring or UI updates.

---

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

> If a sync is already running when the timer fires, the cycle will be skipped and `AlreadyInProgress` will be reported.

---

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

---

## Sync Implementation Details

CloudSync performs synchronization in the following order:

1. Fetch metadata from local and cloud sources
2. Compare metadata to identify differences
3. Upload missing or newer local files to the cloud
4. Download missing or newer cloud files to local storage
5. Report completion or errors

Each step is reported through the `progressCallback` to provide visibility into the sync process.

---

## License

MIT License. Use it, extend it, and contribute!

---

## Inspiration

Built for apps that need to keep data synchronized across devices or sessions, such as:

- Note apps
- Document managers
- Media libraries
- Offline-capable business tools

---

## Contributions Welcome

Found a bug or have a suggestion? PRs and issues are open and appreciated!
