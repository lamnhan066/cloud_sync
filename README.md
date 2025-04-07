# CloudSync

> A flexible, type-safe data synchronization library for Dart applications

CloudSync provides a robust mechanism for bidirectional data synchronization between local and cloud storage systems. It's designed with flexibility, observability, and type safety in mind.

[![Pub Version](https://img.shields.io/pub/v/cloud_sync.svg)](https://pub.dev/packages/cloud_sync)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

## Overview

CloudSync intelligently handles the complexity of keeping data synchronized across different storage locations:

- 🔄 **Bidirectional Sync** - Ensures both local and cloud stay updated
- 🧠 **Smart Diffing** - Uses metadata timestamps to detect changes efficiently
- 📊 **Progress Tracking** - Detailed state reporting for UI feedback
- 🧩 **Modular Design** - Adapter-based or function injection approaches
- ⏱️ **Auto-Sync** - Configurable periodic synchronization
- 🛠️ **Concurrent Operation** - Optional parallel sync processing

## Installation

```yaml
dependencies:
  cloud_sync: ^<latest_version>
```

Then run:

```bash
flutter pub get
```

## Quick Start

### Basic Usage

```dart
import 'package:cloud_sync/cloud_sync.dart';

// Create your CloudSync instance
final cloudSync = CloudSync<FileMetadata, FileData>.fromAdapters(
  LocalStorageAdapter(), // Just an example
  GoogleDriveAppdataAdapter(), // Just an example
);

// Run a sync operation
await cloudSync.sync(
  progressCallback: (state) {
    if (state is SyncCompleted) {
      print('Sync completed successfully!');
    } else if (state is SyncError) {
      print('Error: ${state.error}');
    }
  },
);

// Start automatic syncing every 5 minutes
cloudSync.autoSync(
  interval: Duration(minutes: 5),
  progressCallback: handleSyncState,
);
```

## Core Concepts

### Metadata-Based Sync

CloudSync uses metadata (like modification timestamps) to determine which items need synchronization. This approach is:

- **Efficient** - Only transfers changed data
- **Reliable** - Handles conflicts based on "latest wins" strategy
- **Flexible** - Works with any data type that can be tracked with metadata

### Sync Process Flow

1. **Metadata Collection** - Gather metadata from both sources
2. **Difference Detection** - Compare timestamps to find outdated/missing items
3. **Data Transfer** - Move data in both directions as needed
4. **State Reporting** - Report progress through callback events

## Implementation Options

### 1. Using Adapters (Recommended)

Create adapters by implementing the `SyncAdapter` interface:

```dart
// Define your metadata and data models
class NoteMetadata extends SyncMetadata {
  final String title;
  
  NoteMetadata({
    required super.id,
    required super.modifiedAt,
    required this.title,
  });
}

class Note {
  final String content;
  final List<String> tags;
  
  Note({required this.content, this.tags = const []});
}

// Create local adapter
class LocalAdapter implements SyncAdapter<NoteMetadata, Note> {
  final Map<String, Note> _notes = {};
  final Map<String, NoteMetadata> _metadata = {};
  
  @override
  Future<List<NoteMetadata>> fetchMetadataList() async {
    return _metadata.values.toList();
  }

  @override
  Future<Note> fetchDetail(NoteMetadata metadata) async {
    return _notes[metadata.id] ?? 
        throw Exception('Note not found: ${metadata.id}');
  }

  @override
  Future<void> save(NoteMetadata metadata, Note detail) async {
    _metadata[metadata.id] = metadata;
    _notes[metadata.id] = detail;
  }
}

// Create cloud adapter
class CloudAdapter implements SyncAdapter<NoteMetadata, Note> {
  // Similar implementation for cloud storage
  // ...
}

// Then create your sync instance
final cloudSync = CloudSync.fromAdapters(
  LocalAdapter(),
  CloudAdapter(),
);
```

### 2. Using Function Injection

Provide individual functions for each operation:

```dart
final cloudSync = CloudSync<NoteMetadata, Note>(
  fetchLocalMetadataList: () async => await localDb.getAllMetadata(),
  fetchCloudMetadataList: () async => await api.fetchAllMetadata(),
  fetchLocalDetail: (meta) async => await localDb.getNote(meta.id),
  fetchCloudDetail: (meta) async => await api.fetchNote(meta.id),
  saveToLocal: (meta, note) async => await localDb.saveNote(meta.id, note),
  saveToCloud: (meta, note) async => await api.uploadNote(meta.id, note),
);
```

## Advanced Features

### Synchronization States

Track sync progress with the sealed `SyncState` class hierarchy:

```dart
cloudSync.sync(
  progressCallback: (state) {
    switch (state) {
      case FetchingLocalMetadata():
        showProgressIndicator('Reading local data...');
      case SavingToCloud(var metadata):
        showProgressIndicator('Uploading ${metadata.name}...');
      case SyncCompleted():
        showSuccess('Sync completed!');
      case SyncError(var error, var stack):
        showError('Sync failed: $error');
      // Handle other states...
    }
  },
);
```

### Concurrent Synchronization

Scanning and updating local and cloud parallelly via `Future.wait`:

```dart
await cloudSync.sync(
  useConcurrentSync: true,
  progressCallback: handleSyncProgress,
);
```

### Auto-Sync with Customization

```dart
// Start auto-sync
cloudSync.autoSync(
  interval: Duration(minutes: 10),
  progressCallback: (state) {
    // Handle sync states
  },
);

// Stop auto-sync (e.g., when app goes to background)
cloudSync.stopAutoSync();
```

## Creating Custom Models

### 1. Extend SyncMetadata

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
    bool? isDeleted,
    String? title,
    int? version,
  }) {
    return DocumentMetadata(
      id: id ?? this.id,
      modifiedAt: modifiedAt ?? this.modifiedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      title: title ?? this.title,
      version: version ?? this.version,
    );
  }

  // Implement toMap, fromMap, etc.
}
```

### 2. Define Your Data Model

```dart
class Document {
  final String content;
  final List<String> tags;

  Document({
    required this.content,
    this.tags = const [],
  });
  
  // Your serialization methods
}
```

## API Reference

### CloudSync Class

| Method | Description |
|--------|-------------|
| `sync()` | Performs full synchronization between local and cloud |
| `autoSync()` | Starts periodic automatic synchronization |
| `stopAutoSync()` | Stops automatic synchronization |

### SyncState Events

| State | Description |
|-------|-------------|
| `InProgress` | A sync operation is already running |
| `FetchingLocalMetadata` | Retrieving metadata from local storage |
| `FetchingCloudMetadata` | Retrieving metadata from cloud storage |
| `ScanningLocal` | Analyzing cloud data for local updates |
| `ScanningCloud` | Analyzing local data for cloud updates |
| `SavingToLocal` | Writing data to local storage |
| `SavedToLocal` | Successfully saved data locally |
| `SavingToCloud` | Uploading data to cloud storage |
| `SavedToCloud` | Successfully uploaded data to cloud |
| `SyncCompleted` | Synchronization process completed |
| `SyncError` | Error occurred during synchronization |

## Compatibility

- Works with any Flutter or Dart application
- Storage agnostic - use with any local database and cloud service
- Null safety compliant

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
