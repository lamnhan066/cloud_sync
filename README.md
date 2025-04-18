# CloudSync

> A type-safe, easy-to-use synchronization solution for Dart applications

[![Pub Version](https://img.shields.io/pub/v/cloud_sync.svg)](https://pub.dev/packages/cloud_sync)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![style: very good analysis](https://img.shields.io/badge/style-very_good_analysis-B22C89.svg)](https://pub.dev/packages/very_good_analysis)

---

## 🚀 Overview

CloudSync provides a simple, flexible way to sync data between your local and cloud storage in Dart applications. With built-in support for conflict resolution, progress tracking, concurrent operations, and seamless lifecycle management, CloudSync is designed to make synchronization as smooth as possible.

Whether you're working with files, photos, or any other data, CloudSync takes care of the heavy lifting so you can focus on your application logic.

---

## ✨ Key Features

- **Bidirectional Sync**: Effortlessly sync data both ways (local ↔ cloud).
- **Automatic Conflict Resolution**: Uses a timestamp-based "latest wins" approach.
- **Sync States Tracking**: Get full visibility into sync progress with 12 different sync states.
- **Customizable API**: Choose between an adapter-based approach or functional API depending on your preference.
- **Concurrent Syncing**: Sync multiple items simultaneously for improved performance.
- **Auto-Sync**: Set up automatic background syncing at custom intervals.
- **Graceful Cancellation**: Cancel syncs at any time without issues.
- **Lifecycle Management**: Automatically clean up resources with `dispose()`.
- **Error Handling**: Built-in error reporting and recovery for better reliability.

---

## 📦 Installation

To get started with CloudSync, add it to your `pubspec.yaml`:

```yaml
dependencies:
  cloud_sync: ^<latest_version>
```

Then, run the following command to install the package:

```bash
flutter pub get
```

---

## 🏁 Quick Start

CloudSync is designed to be easy to integrate into your project. Here's how to quickly set it up.

### Using Adapters

```dart
final cloudSync = CloudSync<FileMetadata, FileData>.fromAdapters(
  localAdapter,  // Your local storage adapter
  cloudAdapter,  // Your cloud storage adapter
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

If you'd like to sync periodically, just use the `autoSync` feature:

```dart
cloudSync.autoSync(
  interval: Duration(minutes: 5),
  progressCallback: handleSyncProgress,
);
```

### Clean Up

When you're done, be sure to clean up resources:

```dart
await cloudSync.dispose();
```

---

## ⚙️ Architecture Overview

CloudSync operates with metadata models and uses a sync flow that handles the detection of changes, conflict resolution, and sync execution.

### SyncMetadata Model

```dart
abstract class SyncMetadata {
  final String id;
  final DateTime modifiedAt;
  final bool isDeleted;
}
```

---

## 🔧 Two Implementation Options

CloudSync gives you the flexibility to choose how you want to integrate it into your app: via the **Adapter pattern** or **Functional Injection**.

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

If you prefer a more functional approach, you can inject functions directly:

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

## 🌀 Sync States

CloudSync tracks sync progress with 12 states, ensuring you're always aware of what's happening during synchronization:

| State               | Description                   |
|---------------------|-------------------------------|
| InProgress          | Sync operation is running     |
| FetchingLocalMetadata | Fetching local metadata      |
| FetchingCloudMetadata | Fetching cloud metadata      |
| ScanningLocal       | Checking for changes locally  |
| ScanningCloud       | Checking for changes in the cloud |
| SavingToLocal       | Saving data to local storage  |
| SavedToLocal        | Local save complete           |
| SavingToCloud       | Uploading data to the cloud   |
| SavedToCloud        | Cloud save complete           |
| SyncCompleted       | Sync operation finished       |
| SyncError           | Sync encountered an error     |
| SyncCancelled       | Sync was cancelled            |

---

## 🚀 Advanced Usage

### Progress Tracking

Monitor the progress of your sync operations with a callback for each sync state:

```dart
void handleSyncState(SyncState state) {
  switch (state) {
    case SavingToCloud(metadata: final meta):
      showUploading(meta.filename);
    case SyncError(error: final err):
      logError(err.toString());
    case SyncCompleted():
      showSuccess('Sync complete!');
    // Handle other states...
  }
}
```

### Concurrent Sync

For performance optimization, especially with large datasets, enable concurrent syncing:

```dart
await cloudSync.sync(
  useConcurrentSync: true,
  progressCallback: handleSyncState,
);
```

### Auto-Sync Control

Easily enable auto-sync to keep data updated in the background:

```dart
cloudSync.autoSync(
  interval: Duration(minutes: 15),
  progressCallback: handleSyncState,
);

await cloudSync.stopAutoSync(); // Stop auto-sync when needed
```

### Cancel an Ongoing Sync

Cancel a sync operation at any time:

```dart
await cloudSync.cancelSync(); // Triggers SyncCancelled state
```

---

## 🧑‍💻 Best Practices

- **Always call `dispose()`** to free resources when you're done syncing.
- **Track sync states** in your UI for responsive feedback to the user.
- **Enable concurrent syncing** for large datasets to speed up operations.
- **Wrap sync logic in `try/catch`** to handle potential errors.

```dart
try {
  await cloudSync.sync();
} on SyncDisposedError {
  // Handle case where sync was disposed before completion
} catch (e) {
  handleUnexpectedError(e);
}
```

---

## 📄 Example: Metadata Class

Here's an example of how to define metadata for your data models:

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

This project is licensed under the MIT License — see [LICENSE](LICENSE) for full details.

---

## 🤝 Contributing

We welcome contributions to CloudSync! Feel free to open an issue or submit a pull request if you find a bug or have an idea for an enhancement. Let's build something great together!
