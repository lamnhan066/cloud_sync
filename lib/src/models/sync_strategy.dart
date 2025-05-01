/// An enumeration that defines the different types of synchronization strategies.
enum SyncStrategy {
  /// Prioritizes uploading data before downloading.
  uploadFirst,

  /// Prioritizes downloading data before uploading.
  downloadFirst,

  /// Only uploads data without downloading.
  uploadOnly,

  /// Only downloads data without uploading.
  downloadOnly,

  /// Performs upload and download operations concurrently.
  concurrently,
}
