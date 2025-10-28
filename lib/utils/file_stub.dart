// Stub for web platform
import 'dart:typed_data';

class File {
  final String path;
  final Uint8List? _bytes;

  File(this.path, [this._bytes]);

  Future<Uint8List> readAsBytes() async {
    if (_bytes != null) {
      return _bytes;
    }
    throw UnsupportedError(
      'File operations without bytes are not supported on web',
    );
  }

  // Factory untuk create dari bytes (untuk web)
  static File fromBytes(String path, Uint8List bytes) {
    return File(path, bytes);
  }
}

// Stub for SocketException (untuk web compatibility)
class SocketException implements Exception {
  final String message;
  SocketException(this.message);

  @override
  String toString() => 'SocketException: $message';
}
