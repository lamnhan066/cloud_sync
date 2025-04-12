## 0.4.0

- Refactor CloudSync factory method documentation for clarity and consistency
  
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

- Add `SerializableSyncAdapter` with required metadata functions for improved serialization support
- Add `SerializableSyncMetadata` class for improved serialization and deserialization
- `cancelSync`, `stopAutoSync` and `dispose` methods are now return `Future<void>` to wait for the operations to finish

## 0.3.0

- Remove [de]serialization and copyWith in the SyncMetadata
- Remove custom toString method from SyncCancelledException

## 0.2.1

- Add getter for `isDisposed` property in CloudSync class
- Update README

## 0.2.0

- Initial release (Remove `Unlisted` flag on `pub.dev`)
