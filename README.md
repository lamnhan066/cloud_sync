# CloudSync

**CloudSync** is a Dart library that provides a flexible and extensible mechanism for synchronizing files between local and cloud storage. It's designed with composability in mind, using high-level abstractions and callback-driven progress reporting.

---

## ✨ Features

- 🔄 Bi-directional sync (local ↔️ cloud)
- 🧠 Smart comparison via file metadata
- 📦 Progress callback system
- 💥 Error reporting and state tracking
- 🔧 Fully customizable I/O using function injection
- ⏱ Auto-sync with periodic synchronization

---

## 🚀 Getting Started

### 1. Install

Add `cloud_sync` to your Dart or Flutter project:

```yaml
dependencies:
  cloud_sync:
```

### 2. Import

```dart
import 'package:cloud_sync/cloud_sync.dart';
```

---

## 🛠 Usage Example

```dart
final cloudSync = CloudSync(
  fetchLocalMetadataList: () async => localMetadataList,
  fetchCloudMetadataList: () async => cloudMetadataList,
  fetchLocalFileByMetadata: (metadata) async => localStorage[metadata.id]!,
  fetchCloudFileByMetadata: (metadata) async => cloudStorage[metadata.id]!,
  writeFileToLocalStorage: (metadata, file) async => localStorage[metadata.id] = file,
  writeFileToCloudStorage: (metadata, file) async => cloudStorage[metadata.id] = file,
);

// Synchronize files
await cloudSync.sync(progressCallback: (state) {
  print('Progress: ${state.runtimeType}');
});

// Start auto-sync every 5 minutes
cloudSync.autoSync(interval: Duration(minutes: 5), progressCallback: (state) {
  print('Auto-sync progress: ${state.runtimeType}');
});

// Stop auto-sync when needed
cloudSync.stopAutoSync();
```

---

## 🧩 API Overview

### `CloudSync` constructor

```dart
CloudSync({
  required FetchMetadataList fetchLocalMetadataList,
  required FetchMetadataList fetchCloudMetadataList,
  required FetchFileByMetadata fetchLocalFileByMetadata,
  required FetchFileByMetadata fetchCloudFileByMetadata,
  required WriteFileToStorage writeFileToLocalStorage,
  required WriteFileToStorage writeFileToCloudStorage,
});
```

### Type Definitions

| Type | Description |
|------|-------------|
| `FetchMetadataList` | `Future<List<SyncMetadata>> Function()` |
| `FetchFileByMetadata` | `Future<SyncFile> Function(SyncMetadata)` |
| `WriteFileToStorage` | `Future<void> Function(SyncMetadata, SyncFile)` |
| `SyncProgressCallback` | `void Function(SyncState)` |

---

## 📦 Models

### `SyncMetadata`

Represents a file with fields:

```dart
class SyncMetadata {
  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime modifiedAt;
}
```

### `SyncFile`

Represents file contents:

```dart
class SyncFile {
  final List<int> bytes;
}
```

---

## 🔄 Sync Lifecycle States (`SyncState`)

- `AlreadyInProgress`
- `FetchingLocalMetadata`
- `FetchingCloudMetadata`
- `CheckingCloudForMissingOrOutdatedFiles`
- `CheckingLocalForMissingOrOutdatedFiles`
- `SavingFileToCloud`
- `SavingFileToLocal`
- `SynchronizationCompleted`
- `SynchronizationError`

---

## 🕹 Auto-Sync

`CloudSync` provides an auto-sync feature to periodically synchronize local and cloud storage. The auto-sync process triggers synchronization at a specified interval.

### Methods

#### `autoSync`

Starts the auto-sync process with a specified `interval`. The sync will be triggered periodically based on the interval. An optional `progressCallback` can be provided to report synchronization progress.

```dart
void autoSync({
  required Duration interval,
  SyncProgressCallback? progressCallback,
});
```

**Parameters:**

- `interval`: The duration between each sync trigger (how often to perform synchronization).
- `progressCallback`: An optional callback that will report the sync process progress.

**Note:** If a sync is already in progress when the timer fires, that sync attempt will be skipped and not retried immediately. The `AlreadyInProgress` state will be passed to the `progressCallback` if provided.

#### `stopAutoSync`

Stops the auto-sync process by canceling the periodic timer.

```dart
void stopAutoSync();
```

---

## 🔒 License

MIT License. Use freely, contribute happily.

---

## 💡 Inspiration

Built for syncing stateful resources (like notes, images, or configs) across devices or between user sessions.

---

## 👥 Contributions

Pull requests, bug reports, and improvements are always welcome!
