# CloudSync

[![Pub Version](https://img.shields.io/pub/v/cloud_sync.svg)](https://pub.dev/packages/cloud_sync) 
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![style: very good analysis](https://img.shields.io/badge/style-very_good_analysis-B22C89.svg)](https://pub.dev/packages/very_good_analysis)

Effortlessly synchronize your app's data between local storage and the cloud! `cloud_sync` provides a flexible and robust framework to manage data synchronization in your Flutter applications.

## What is `cloud_sync`?

Imagine you want your users to be able to use your app offline and have their changes automatically saved to the cloud when they're back online. Or perhaps you want to share data seamlessly across multiple devices. That's where `cloud_sync` comes in!

This package provides the foundational building blocks to implement your own synchronization logic. It's designed to be adaptable to various local storage solutions (like SQLite, Hive, shared preferences) and cloud services (like Firebase, AWS, custom APIs).

**Key Features:**

* **Abstract Adapters:** Define how your local and cloud data sources interact with the synchronization process.
* **Metadata Management:** Track changes and deletions efficiently using built-in metadata models.
* **Synchronization States:** Observe the progress of the sync process with clear and informative states.
* **Error Handling:** Gracefully manage errors during synchronization.
* **Auto-Sync:** Set up automatic background synchronization at specified intervals.
* **Cancellation:** Easily cancel ongoing synchronization operations.
* **Concurrency:** Option to run local and cloud synchronization processes concurrently for faster syncing.
* **Extensible:** Designed to be adaptable to your specific data structures and storage mechanisms.

## Getting Started

### 1. Installation

Add `cloud_sync` to your `pubspec.yaml` file:

```yaml
dependencies:
  cloud_sync: ^<latest_version>
````

Replace `<latest_version>` with the current version of the package (you can find this on the [pub.dev](https://pub.dev/packages/cloud_sync)).

Then, run:

```bash
flutter pub get
```

### 2\. Understanding the Core Concepts

`cloud_sync` revolves around the idea of **Adapters** and **Metadata**.

* **Adapters (`SyncAdapter`)**: These are the workhorses of the package. You'll need to create concrete implementations of `SyncAdapter` (or its serializable version `SerializableSyncAdapter`) for both your local and cloud data sources. These adapters define how to:

  * Fetch lists of items (`fetchMetadataList`).
  * Retrieve the details of a specific item (`fetchDetail`).
  * Save an item (`save`).
  * Get a unique ID for an item (`getMetadataId`).
  * Compare the modification times of items (`isCurrentMetadataBeforeOther`).

* **Metadata (`SyncMetadata`)**: This lightweight class keeps track of essential information about your data, such as its unique ID, the last time it was modified, and whether it has been marked as deleted. The `SerializableSyncMetadata` provides built-in JSON serialization.

* **`CloudSync`**: This is the main class that orchestrates the synchronization process using your local and cloud adapters.

* **`SyncState`**: Represents the current status of the synchronization, allowing you to provide feedback to your users (e.g., "Syncing...", "Sync Complete", "Error\!").

### 3\. Basic Usage

Here's a simplified example of how you might set up `cloud_sync` (you'll need to implement your own `LocalDataAdapter` and `CloudDataAdapter`):

```dart
import 'package:cloud_sync/cloud_sync.dart';
import 'package:cloud_sync/src/models/sync_metadata.dart'; // Assuming sync_metadata.dart is in src/models

// Assume you have implemented these adapters
class LocalDataAdapter extends SerializableSyncAdapter<SerializableSyncMetadata, MyData> {
  // ... your implementation
}

class CloudDataAdapter extends SerializableSyncAdapter<SerializableSyncMetadata, MyData> {
  // ... your implementation
}

class MyData {
  final String id;
  final String content;
  MyData({required this.id, required this.content});
}

void main() async {
  final localAdapter = LocalDataAdapter();
  final cloudAdapter = CloudDataAdapter();

  final cloudSync = CloudSync.fromAdapters(
    local: localAdapter,
    cloud: cloudAdapter,
    shouldThrowOnError: false, // Set to true to rethrow errors
  );

  // Trigger a manual synchronization
  await cloudSync.sync(
    progress: (state) {
      print("Sync State: $state");
      if (state is SyncError) {
        print("Sync Error: ${state.error}");
        print("Stack Trace: ${state.stackTrace}");
      } else if (state is SyncCompleted) {
        print("Synchronization complete!");
      }
    },
  );

  // Start automatic synchronization every 5 minutes
  cloudSync.autoSync(
    interval: const Duration(minutes: 5),
    progress: (state) {
      print("Auto Sync State: $state");
      // Handle auto-sync progress
    },
  );

  // To stop auto-sync later:
  // await cloudSync.stopAutoSync();

  // When you're done with CloudSync:
  // await cloudSync.dispose();
}
```

**Important:** You will need to implement the concrete logic within your `LocalDataAdapter` and `CloudDataAdapter` to interact with your chosen local storage and cloud service. This will involve tasks like reading and writing to databases, making API calls, etc.

## Implementing Your Adapters

The key to using `cloud_sync` effectively is implementing your own `SyncAdapter` for your specific needs. Here's a reminder of the methods you'll need to implement:

**For `SyncAdapter<M, D>`:**

* `getMetadataId(M metadata)`: Returns the unique ID of the metadata.
* `isCurrentMetadataBeforeOther(M current, M other)`: Determines if `current` was modified before `other`.
* `fetchMetadataList()`: Fetches a list of metadata items.
* `fetchDetail(M metadata)`: Fetches the detailed data for a given metadata item.
* `save(M metadata, D detail)`: Saves the metadata and its associated detail.

**For `SerializableSyncAdapter<M extends SyncMetadata, D>`:**

If your metadata extends `SyncMetadata` and you want built-in JSON serialization, you can use `SerializableSyncAdapter`. In addition to the methods above, you'll also need to provide:

* `metadataToJson(M metadata)`: Converts your metadata object to a JSON string.
* `metadataFromJson(String json)`: Creates a metadata object from a JSON string.

**Need Some Inspiration? Check Out Existing Adapters:**

* **cloud_sync_shared_preferences_adapter:** [Pub](https://pub.dev/packages/cloud_sync_shared_preferences_adapter) | [Github](https://github.com/lamnhan066/cloud_sync_adapters/tree/main/packages/cloud_sync_shared_preferences_adapter)
* **cloud_sync_hive_adapter:** [Pub](https://pub.dev/packages/cloud_sync_hive_adapter) | [Github](https://github.com/lamnhan066/cloud_sync_adapters/tree/main/packages/cloud_sync_hive_adapter)
* **cloud_sync_google_drive_adapter:** [Pub](https://pub.dev/packages/cloud_sync_google_drive_adapter) | [Github](https://github.com/lamnhan066/cloud_sync_adapters/tree/main/packages/cloud_sync_google_drive_adapter)

## Advanced Features

* **Error Handling (`shouldThrowOnError`)**: Control whether errors during synchronization are thrown or reported via the `progress`.
* **Cancellation (`cancelSync`)**: Stop a long-running synchronization process if needed.
* **Concurrency (`useConcurrentSync`)**: Potentially speed up synchronization by performing local and cloud operations in parallel.
* **Custom Metadata**: While `SyncMetadata` is provided, you can create your own metadata class that extends it to include additional information relevant to your data.

## Contributing

Contributions to the `cloud_sync` package are welcome\! Please feel free to submit issues and pull requests on the [GitHub](https://github.com/lamnhan066/cloud_sync).

If you'd like to add more adapters, you can contribute to the [cloud_sync_adapters](https://github.com/lamnhan066/cloud_sync_adapters) collections.

## License

`cloud_sync` is released under the [MIT License](https://github.com/lamnhan066/cloud_sync/blob/main/LICENSE).
