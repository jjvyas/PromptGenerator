import 'dart:developer' as developer;

class FileSaver {
  static void saveBytes({
    required List<int> bytes,
    required String fileName,
    required String mimeType,
  }) {
    developer.log('FileSaver: Download initiated for $fileName (binary, length: ${bytes.length})');
  }
}
