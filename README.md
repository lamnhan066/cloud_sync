# CloudSync

> A robust, type-safe synchronization solution for Dart applications

[![Pub Version](https://img.shields.io/pub/v/cloud_sync.svg)](https://pub.dev/packages/cloud_sync)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![style: very good analysis](https://img.shields.io/badge/style-very_good_analysis-B22C89.svg)](https://pub.dev/packages/very_good_analysis)

## 🔍 Overview

CloudSync is a flexible, bidirectional sync engine for Dart that helps keep your local and cloud data perfectly in sync. It supports adapter-based or functional APIs, progress tracking, concurrent operations, and robust cancellation.

---

## 🚀 Features

- 🔄 **Bidirectional Sync** — Sync in both directions (local ↔ cloud)
- ⏱ **Conflict Resolution** — Timestamp-based "latest wins" strategy
- 📊 **Detailed State Tracking** — 12 sync states for full visibility
- 🛠 **Adapter or Functional API** — Choose what suits your architecture
- ⚡ **Concurrent Processing** — Parallel operations for better performance
- ⏳ **Auto-Sync Support** — Periodic background syncing
- ✋ **Cancelable Syncs** — Graceful cancellation at any stage
- 🧹 **Lifecycle Management** — `dispose()` cleanup support
- 🛡 **Error Handling** — Built-in reporting and recovery

---

## 📦 Installation

In your `pubspec.yaml`:

```yaml
dependencies:
  cloud_sync: ^<latest_version>
```

Then run:

```bash
flutter pub get
```

---

## 🧭 Quick Start

### Using Adapters

```dart
final cloudSync = CloudSync<FileMetadata, FileData>.fromAdapters(
  localAdapter,
  cloudAdapter,
);

await cloudSync.sync(
  progressCallback: (state) {
    if (state is SyncCompleted) {
      print('✅ Sync completed!');
    } else if (state is SyncError) {
      print('❌ Sync failed: ${state.error}');
    }
  },
);
```

### Enable Auto-Sync

```dart
cloudSync.autoSync(
  interval: Duration(minutes: 5),
  progressCallback: handleSyncProgress,
);
```

### Clean Up

```dart
await cloudSync.dispose();
```

---

## ⚙️ Core Architecture

### SyncMetadata Model

```dart
abstract class SyncMetadata {
  final String id;
  final DateTime modifiedAt;
  final bool isDeleted;
}
```

### Sync Flow

1. **Metadata Fetching** — Get metadata from both sources
2. **Diff Detection** — Timestamp-based comparison
3. **Conflict Resolution** — Apply "latest wins" logic
4. **Sync Execution** — Upload/download data accordingly
5. **State Updates** — Progress tracked via `SyncState`

---

## 🧱 Implementation Options

### 1. Adapter Pattern (Recommended)

```dart
class LocalHiveAdapter implements SyncAdapter<NoteMetadata, Note> {
  @override
  Future<List<NoteMetadata>> fetchMetadataList() => metadataBox.values.toList();

  @override
  Future<Note> fetchDetail(NoteMetadata meta) async => notesBox.get(meta.id)!;

  @override
  Future<void> save(NoteMetadata meta, Note note) async {
    await notesBox.put(meta.id, note);
    await metadataBox.put(meta.id, meta);
  }
}
```

### 2. Functional Injection

```dart
final cloudSync = CloudSync<PhotoMetadata, Photo>(
  fetchLocalMetadataList: localDb.getPhotoMetadata,
  fetchCloudMetadataList: cloudApi.getPhotoMetadata,
  fetchLocalDetail: (m) => localDb.getPhoto(m.id),
  fetchCloudDetail: (m) => cloudApi.downloadPhoto(m.id),
  saveToLocal: localDb.savePhoto,
  saveToCloud: cloudApi.uploadPhoto,
);
```

---

## 📶 Sync States

| State              | Description                  |
|-------------------|------------------------------|
| InProgress         | Sync already running         |
| FetchingLocalMetadata | Fetching local metadata     |
| FetchingCloudMetadata | Fetching cloud metadata     |
| ScanningLocal      | Scanning local for changes   |
| ScanningCloud      | Scanning cloud for changes   |
| SavingToLocal      | Downloading to local         |
| SavedToLocal       | Local save complete          |
| SavingToCloud      | Uploading to cloud           |
| SavedToCloud       | Cloud save complete          |
| SyncCompleted      | All sync steps finished      |
| SyncError          | An error occurred            |
| SyncCancelled      | Sync was cancelled           |

---

## 🧠 Advanced Usage

### Progress Tracking

```dart
void handleSyncState(SyncState state) {
  switch (state) {
    case SavingToCloud(metadata: final meta):
      showUploading(meta.filename);
    case SyncError(error: final err):
      logError(err.toString());
    case SyncCompleted():
      showSuccess('Sync complete!');
    // handle other states...
  }
}
```

### Concurrent Sync

```dart
await cloudSync.sync(
  useConcurrentSync: true,
  progressCallback: handleSyncState,
);
```

### Auto-Sync Control

```dart
cloudSync.autoSync(
  interval: Duration(minutes: 15),
  progressCallback: handleSyncState,
);

await cloudSync.stopAutoSync(); // Stop it
```

### Cancel Ongoing Sync

```dart
await cloudSync.cancelSync(); // Triggers SyncCancelled
```

---

## 🧪 Best Practices

- **Always call `dispose()`** when done
- **Handle all `SyncState`s** in your UI for clear feedback
- **Enable `useConcurrentSync`** for large datasets
- **Wrap sync in a `try/catch`** for reliability

```dart
try {
  await cloudSync.sync();
} on SyncDisposedError {
  // Already disposed
} catch (e) {
  handleUnexpectedError(e);
}
```

---

## 🧾 Example: Metadata Class

```dart
class DocumentMetadata extends SyncMetadata {
  final String title;
  final int version;

  DocumentMetadata({
    required super.id,
    required super.modifiedAt,
    required this.title,
    this.version = 1,
    super.isDeleted = false,
  });

  @override
  DocumentMetadata copyWith({
    String? id,
    DateTime? modifiedAt,
    String? title,
    int? version,
    bool? isDeleted,
  }) {
    return DocumentMetadata(
      id: id ?? this.id,
      modifiedAt: modifiedAt ?? this.modifiedAt,
      title: title ?? this.title,
      version: version ?? this.version,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}
```

---

## 📄 License

MIT License — See [LICENSE](LICENSE) for full details.

---

## 🤝 Contributing

Issues and PRs are welcome! Open a discussion or submit a fix anytime.
