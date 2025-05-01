## 0.4.0

- **BREADKING CHANGE:** Refactor CloudSync factory documentation for clarity and consistency
  
  From:
  
  ```dart
  final cloudSync = CloudSync.formAdapters(localAdapter, cloudAdapter);
  ```
  
  To
  
  ```dart
  final cloudSync = CloudSync.formAdapters(
      local: localAdapter, 
      cloud: cloudAdapter,
    );
  ```

- **BREAKING CHANGE:** Remove `CloudSync` constructor
- **BREAKING CHANGE:** Refactor `CloudSync` and `CloudSyncAdapter` to make generic type parameters don't depend on `SyncMetadata`
- **BREAKING CHANGE:** Replace `useConcurrentSync` with `syncStrategy`
- **BREAKING CHANGE:** Refactor `SyncState` to remove generic type parameters
- **BREAKING CHANGE:** Rename from `progressCallback` to `progress`
- **BREAKING CHANGE:** `cancelSync`, `stopAutoSync` and `dispose` methods are now return `Future<void>` to wait for the operations to finish
- Add `SerializableSyncAdapter` with required metadata functions for improved serialization support
- Add `SerializableSyncMetadata` class for improved serialization and deserialization
- Add `shouldThrowOnError` to `CloudSync`

## 0.3.0

- Remove [de]serialization and copyWith in the SyncMetadata
- Remove custom toString method from SyncCancelledException

## 0.2.1

- Add getter for `isDisposed` property in CloudSync class
- Update README

## 0.2.0

- Initial release (Remove `Unlisted` flag on `pub.dev`)
