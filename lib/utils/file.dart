// Conditional import for File class
// Uses dart:io File on mobile/desktop, stub on web
export 'file_stub.dart' if (dart.library.io) 'file_io.dart';
