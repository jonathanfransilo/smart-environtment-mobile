// Export dart:io File and SocketException for mobile/desktop platforms
import 'dart:io' as io;
import 'dart:typed_data';

export 'dart:io' show File, SocketException;

// Helper function untuk create File dari bytes (untuk mobile)
// Di mobile, kita tidak perlu bytes karena File sudah langsung dari path
io.File createFileFromBytes(String path, Uint8List bytes) {
  return io.File(path);
}
