/// A model class representing a file to be synchronized.
///
/// The [SyncFile] class contains the file's data in the form of a list of bytes.
class SyncFile {
  /// The raw byte data of the file.
  ///
  /// This property holds the file's content as a list of integers, where each
  /// integer represents a byte.
  final List<int> bytes;

  /// Creates a new instance of [SyncFile].
  ///
  /// The [bytes] parameter is required and must not be null.
  SyncFile({required this.bytes});
}
