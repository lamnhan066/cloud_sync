# CloudSync

> A powerful and easy-to-use synchronization solution for Dart applications, ensuring seamless cloud and local data sync.

[![Pub Version](https://img.shields.io/pub/v/cloud_sync.svg)](https://pub.dev/packages/cloud_sync)  
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)  
[![style: very good analysis](https://img.shields.io/badge/style-very_good_analysis-B22C89.svg)](https://pub.dev/packages/very_good_analysis)

---

## ✨ Features

- **Bidirectional Sync**: Effortlessly sync data both ways (cloud ↔ local).
- **Automatic Conflict Resolution**: Timestamp-based "latest wins" strategy to resolve conflicts.
- **State Tracking**: Real-time tracking of sync progress with detailed states.
- **Customizable API**: Choose between an adapter-based approach or functional API.
- **Concurrent Syncing**: Supports parallel syncing for better performance.
- **Auto-Sync**: Periodic background syncing to keep data up to date.
- **Graceful Cancellation**: Safely cancel sync operations when needed.
- **Error Handling**: Built-in error management and recovery.
- **Resource Cleanup**: Ensure proper resource management with lifecycle hooks like `dispose()`.

---

## 🚀 Getting Started

### Installation

Add the following to your `pubspec.yaml`:

```yaml
dependencies:
  cloud_sync: ^<latest_version>
```

Then run the following command to fetch the package:

```bash
flutter pub get
```

---

## 🧑‍💻 Usage

CloudSync is simple to integrate. Here’s a quick guide to get you started with both the **Adapter pattern** and **Functional Injection**.

### Using the Adapter Pattern

The Adapter pattern provides a simple way to sync using predefined interfaces. Below is an example of syncing data using adapters:

```dart
final cloudSync = CloudSync<FileMetadata, FileData>.fromAdapters(
  localAdapter,  // Your local storage adapter
  cloudAdapter,  // Your cloud storage adapter
);

await cloudSync.sync(
  progressCallback: (state) {
    if (state is SyncCompleted) {
      print('✅ Sync completed successfully!');
    } else if (state is SyncError) {
      print('❌ Sync failed: ${state.error}');
    }
  },
);
```

### Enabling Auto-Sync

You can enable automatic syncing at regular intervals with the `autoSync` method:

```dart
cloudSync.autoSync(
  interval: Duration(minutes: 10),
  progressCallback: handleSyncProgress,
);
```

### Manual Sync Control

You can also manually trigger sync operations:

```dart
await cloudSync.sync(
  progressCallback: handleSyncState,
);
```

To stop auto-sync, use the `stopAutoSync` method:

```dart
await cloudSync.stopAutoSync();
```

---

## 🔧 Configuration Options

CloudSync offers two configuration methods to suit your architecture.

### 1. Adapter-Based Sync

Adapters allow you to define how local and cloud storage interact with your data:

```dart
class LocalStorageAdapter implements SyncAdapter<NoteMetadata, Note> {
  @override
  Future<List<NoteMetadata>> fetchMetadataList() => localDb.getNotesMetadata();

  @override
  Future<Note> fetchDetail(NoteMetadata metadata) async {
    return localDb.getNoteById(metadata.id);
  }

  @override
  Future<void> save(NoteMetadata metadata, Note note) async {
    await localDb.save(note);
  }
}
```

### 2. Functional Injection

If you prefer more flexibility, CloudSync can also be configured with functional injection:

```dart
final cloudSync = CloudSync<PhotoMetadata, Photo>(
  fetchLocalMetadataList: localDb.getPhotoMetadataList,
  fetchCloudMetadataList: cloudApi.getPhotoMetadataList,
  fetchLocalDetail: (metadata) => localDb.getPhotoById(metadata.id),
  fetchCloudDetail: (metadata) => cloudApi.downloadPhoto(metadata.id),
  saveToLocal: localDb.savePhoto,
  saveToCloud: cloudApi.uploadPhoto,
);
```

---

## 🔄 Sync States

CloudSync tracks the progress of each sync operation with various states. Here are the available states:

| State                | Description                             |
|----------------------|-----------------------------------------|
| InProgress           | Sync operation is currently running.    |
| FetchingLocalMetadata | Fetching metadata from the local store. |
| FetchingCloudMetadata | Fetching metadata from the cloud.       |
| ScanningLocal        | Scanning local data for changes.        |
| ScanningCloud        | Scanning cloud data for changes.        |
| SavingToLocal        | Saving data to the local store.         |
| SavedToLocal         | Data successfully saved locally.        |
| SavingToCloud        | Uploading data to the cloud.            |
| SavedToCloud         | Data successfully saved to the cloud.   |
| SyncCompleted        | Sync operation has completed.           |
| SyncError            | An error occurred during sync.          |
| SyncCancelled        | Sync operation was cancelled.           |

---

## ⚙️ Advanced Features

### Progress Tracking

Track sync progress using the sync state callback:

```dart
void handleSyncState(SyncState state) {
  switch (state) {
    case SavingToCloud(metadata: final meta):
      print('Uploading ${meta.filename}...');
    case SyncError(error: final err):
      print('Sync error: $err');
    case SyncCompleted():
      print('Sync completed!');
    // Handle other states as needed
  }
}
```

### Concurrent Sync

Enable concurrent syncing for better performance with large datasets:

```dart
await cloudSync.sync(
  useConcurrentSync: true,
  progressCallback: handleSyncState,
);
```

### Cancel Sync

You can cancel an ongoing sync operation at any time:

```dart
await cloudSync.cancelSync();
```

---

## 💡 Best Practices

- **Always call `dispose()`** when done with CloudSync to free up resources.
- **Monitor all sync states** in your UI for smooth user experience.
- **Enable `useConcurrentSync`** for syncing large datasets efficiently.
- **Wrap sync operations in try/catch** blocks to ensure reliability:

```dart
try {
  await cloudSync.sync();
} on SyncDisposedError {
  print('Sync operation already disposed.');
} catch (e) {
  print('Unexpected error: $e');
}
```

---

## 📝 Example: Metadata Class

Define metadata classes to manage your data models. Here’s an example of a `DocumentMetadata` class:

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

CloudSync is open-source software released under the MIT License. See [LICENSE](LICENSE) for full details.

---

## 🤝 Contributing

We welcome contributions to CloudSync! Whether it’s reporting issues, suggesting new features, or submitting pull requests—feel free to get involved.
