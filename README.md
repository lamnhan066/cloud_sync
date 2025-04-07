# CloudSync

> A robust, type-safe synchronization solution for Dart applications

[![Pub Version](https://img.shields.io/pub/v/cloud_sync.svg)](https://pub.dev/packages/cloud_sync)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

## Features

- 🔄 **Bidirectional Sync** - Keep local and cloud storage perfectly synchronized
- ⏱ **Smart Conflict Resolution** - Timestamp-based change detection with "latest wins" strategy
- 📊 **Comprehensive State Tracking** - 12 distinct sync states for complete visibility
- 🛠 **Flexible Architecture** - Choose between adapter pattern or direct function injection
- ⚡ **Concurrent Processing** - Optional parallel sync operations for performance
- ⏳ **Auto-Sync** - Configurable periodic synchronization
- ✋ **Cancellation Support** - Gracefully stop ongoing sync operations
- 🧹 **Resource Management** - Proper cleanup with `dispose()` pattern
- 🛡 **Error Resilient** - Built-in error handling and recovery

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  cloud_sync: ^<latest_version>
```

Then run:

```bash
flutter pub get
```

## Quick Start

### Basic Usage with Adapters

```dart
import 'package:cloud_sync/cloud_sync.dart';

// 1. Define your metadata model
class FileMetadata extends SyncMetadata {
  final String filename;
  
  FileMetadata({
    required super.id,
    required super.modifiedAt,
    required this.filename,
    super.isDeleted = false,
  });
}

// 2. Create adapters
final localAdapter = LocalHiveAdapter(notesBox, metadataBox);
final cloudAdapter = FirebaseCloudAdapter(firestore);

// 3. Initialize CloudSync
final cloudSync = CloudSync<FileMetadata, FileData>.fromAdapters(
  localAdapter,
  cloudAdapter,
);

// 4. Perform sync
await cloudSync.sync(
  progressCallback: (state) {
    if (state is SyncCompleted) {
      print('Sync completed successfully!');
    } else if (state is SyncError) {
      print('Error during sync: ${state.error}');
    }
  },
);

// 5. Set up auto-sync (optional)
cloudSync.autoSync(
  interval: Duration(minutes: 5),
  progressCallback: handleSyncProgress,
);

// 6. Clean up when done
cloudSync.dispose();
```

## Core Architecture

### Metadata-Based Synchronization

CloudSync uses metadata to efficiently determine synchronization needs:

```dart
abstract class SyncMetadata {
  final String id;           // Unique identifier
  final DateTime modifiedAt; // Last modification timestamp
  final bool isDeleted;      // Tombstone marker for deletions
}
```

### The Sync Process

1. **Metadata Collection** - Fetch metadata lists from both sources
2. **Difference Detection** - Compare timestamps to identify changes
3. **Data Transfer** - Synchronize changes in both directions
4. **State Reporting** - Provide real-time progress updates

## Implementation Guides

### 1. Using the Adapter Pattern (Recommended)

```dart
class LocalHiveAdapter implements SyncAdapter<NoteMetadata, Note> {
  const LocalHiveAdapter(this.notesBox, this.metadataBox);

  final Box<Note> notesBox;
  final Box<NoteMetadata> metadataBox;

  @override
  Future<List<NoteMetadata>> fetchMetadataList() async {
    return metadataBox.values.toList();
  }

  @override
  Future<Note> fetchDetail(NoteMetadata meta) async {
    final note = notesBox.get(meta.id);
    if (note == null) throw Exception('Note ${meta.id} not found');
    return note;
  }

  @override
  Future<void> save(NoteMetadata meta, Note note) async {
    await notesBox.put(meta.id, note);
    await metadataBox.put(meta.id, meta);
  }
}

class FirebaseCloudAdapter implements SyncAdapter<DocMetadata, Document> {
  const FirebaseCloudAdapter(this.firestore);

  final FirebaseFirestore firestore;

  @override
  Future<List<DocMetadata>> fetchMetadataList() async {
    final snapshot = await firestore.collection('metadata').get();
    return snapshot.docs.map((doc) => DocMetadata.fromMap(doc.data())).toList();
  }

  @override
  Future<Document> fetchDetail(DocMetadata meta) async {
    final doc = await firestore.collection('documents').doc(meta.id).get();
    return Document.fromMap(doc.data()!);
  }

  @override
  Future<void> save(DocMetadata meta, Document doc) async {
    final batch = firestore.batch();
    batch.set(firestore.collection('metadata').doc(meta.id), meta.toMap());
    batch.set(firestore.collection('documents').doc(meta.id), doc.toMap());
    await batch.commit();
  }
}
```

### 2. Using Direct Function Injection

```dart
final cloudSync = CloudSync<PhotoMetadata, Photo>(
  fetchLocalMetadataList: () => localDb.getPhotoMetadata(),
  fetchCloudMetadataList: () => cloudApi.getPhotoMetadata(),
  fetchLocalDetail: (meta) => localDb.getPhoto(meta.id),
  fetchCloudDetail: (meta) => cloudApi.downloadPhoto(meta.id),
  saveToLocal: (meta, photo) => localDb.savePhoto(meta.id, photo),
  saveToCloud: (meta, photo) => cloudApi.uploadPhoto(meta.id, photo),
);
```

## Advanced Features

### Comprehensive State Tracking

Handle all 12 sync states:

```dart
void handleSyncState(SyncState<DocMetadata> state) {
  switch (state) {
    case FetchingLocalMetadata():
      showLoading('Preparing sync...');
    case SavingToCloud(metadata: final meta):
      showProgress('Uploading ${meta.filename}...');
    case SyncError(error: final err, stackTrace: final stack):
      showError('Sync failed: ${err.toString()}');
      logError(stack);
    case SyncCompleted():
      showSuccess('All documents synchronized!');
    // Handle all states...
  }
}
```

### Concurrent Synchronization

```dart
await cloudSync.sync(
  useConcurrentSync: true,  // Enable parallel processing
  progressCallback: handleSyncState,
);
```

### Auto-Sync Management

```dart
// Start auto-sync every 15 minutes
cloudSync.autoSync(
  interval: Duration(minutes: 15),
  progressCallback: handleSyncState,
);

// Later, when needed:
cloudSync.stopAutoSync();
```

### Cancellation Support

```dart
final syncFuture = cloudSync.sync();

// User cancels operation
void onCancelPressed() {
  cloudSync.cancelSync();
}

try {
  await syncFuture;
} on SyncCancelledException {
  showMessage('Sync stopped by user');
}
```

## Complete API Reference

### CloudSync Methods

| Method | Description | Throws |
|--------|-------------|--------|
| `sync()` | Perform full synchronization | `SyncCancelledException`, `SyncDisposedError` |
| `autoSync()` | Start periodic auto-sync | `SyncDisposedError` |
| `stopAutoSync()` | Stop auto-sync timer | - |
| `cancelSync()` | Cancel ongoing sync | - |
| `dispose()` | Release resources | - |

### Sync States

| State | Description | Contains |
|-------|-------------|----------|
| `InProgress` | Sync already running | - |
| `FetchingLocalMetadata` | Getting local metadata | - |
| `FetchingCloudMetadata` | Getting cloud metadata | - |
| `ScanningLocal` | Comparing local changes | - |
| `ScanningCloud` | Comparing cloud changes | - |
| `SavingToLocal` | Saving to local storage | Metadata |
| `SavedToLocal` | Local save complete | Metadata |
| `SavingToCloud` | Uploading to cloud | Metadata |
| `SavedToCloud` | Cloud upload complete | Metadata |
| `SyncCompleted` | All operations done | - |
| `SyncError` | Error occurred | Error + StackTrace |
| `SyncCancelled` | Operation stopped | - |

## Best Practices

1. **Always implement `dispose()`**:

   ```dart
   @override
   void dispose() {
     cloudSync.dispose();
     super.dispose();
   }
   ```

2. **Handle all sync states** for best UX:

   ```dart
   void handleState(SyncState state) {
     if (state is SavingToLocal || state is SavingToCloud) {
       showProgressFor(state.metadata);
     }
     // Other states...
   }
   ```

3. **Use concurrent sync** for better performance:

   ```dart
   await cloudSync.sync(useConcurrentSync: true);
   ```

4. **Implement proper error handling**:

   ```dart
   try {
     await cloudSync.sync();
   } on SyncDisposedError {
     // Handle disposed instance
   } on SyncCancelledException {
     // Handle user cancellation
   } catch (e) {
     // Other errors
   }
   ```

## Example Implementations

### Complete Metadata Class

```dart
class DocumentMetadata extends SyncMetadata {
  final String title;
  final String author;
  final int version;

  DocumentMetadata({
    required super.id,
    required super.modifiedAt,
    required this.title,
    required this.author,
    this.version = 1,
    super.isDeleted = false,
  });

  @override
  DocumentMetadata copyWith({
    String? id,
    DateTime? modifiedAt,
    bool? isDeleted,
    String? title,
    String? author,
    int? version,
  }) {
    return DocumentMetadata(
      id: id ?? this.id,
      modifiedAt: modifiedAt ?? this.modifiedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      title: title ?? this.title,
      author: author ?? this.author,
      version: version ?? this.version,
    );
  }

  // Add serialization methods as needed...
}
```

## Troubleshooting

## Error: "CloudSync object has been disposed"

- Ensure you're not using the instance after calling `dispose()`
- Check your widget lifecycle to properly manage the CloudSync instance

### Sync stops unexpectedly

- Implement all state handlers, especially `SyncError`
- Check for cancellation points in your code

### Performance issues

- Consider using concurrent sync
- Optimize your adapter implementations

## License

MIT License - See [LICENSE](LICENSE) for details.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
